import runpod
import json
import base64
import os
import time
import uuid
import urllib.request
import urllib.parse
import websocket

COMFYUI_URL = "http://127.0.0.1:8188"
COMFYUI_WS  = "ws://127.0.0.1:8188"


def upload_image(b64_data: str, filename: str) -> str:
    """Upload base64 image to ComfyUI and return filename."""
    if b64_data.startswith("data:"):
        b64_data = b64_data.split(",", 1)[1]
    img_bytes = base64.b64decode(b64_data)

    import urllib.request
    boundary = "----FormBoundary"
    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="image"; filename="{filename}"\r\n'
        f"Content-Type: image/png\r\n\r\n"
    ).encode() + img_bytes + f"\r\n--{boundary}--\r\n".encode()

    req = urllib.request.Request(
        f"{COMFYUI_URL}/upload/image",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    with urllib.request.urlopen(req) as r:
        result = json.loads(r.read())
    return result["name"]


def queue_prompt(workflow: dict, client_id: str) -> str:
    """Queue workflow and return prompt_id."""
    payload = json.dumps({"prompt": workflow, "client_id": client_id}).encode()
    req = urllib.request.Request(
        f"{COMFYUI_URL}/prompt",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())["prompt_id"]


def wait_for_completion(prompt_id: str, client_id: str) -> dict:
    """Wait via WebSocket until prompt completes, return output filenames."""
    ws = websocket.WebSocket()
    ws.connect(f"{COMFYUI_WS}/ws?clientId={client_id}")
    outputs = {}
    try:
        while True:
            msg = json.loads(ws.recv())
            t = msg.get("type")
            data = msg.get("data", {})
            if t == "executing":
                if data.get("node") is None and data.get("prompt_id") == prompt_id:
                    break
            elif t == "executed":
                if data.get("prompt_id") == prompt_id:
                    outputs.update(data.get("output", {}))
            elif t == "execution_error":
                if data.get("prompt_id") == prompt_id:
                    raise RuntimeError(
                        f"ComfyUI node {data.get('node_id')} error: "
                        f"{data.get('exception_type')}: {data.get('exception_message')}\n"
                        f"Traceback: {''.join(data.get('traceback', []))}"
                    )
    finally:
        ws.close()
    return outputs


def get_file_b64(filename: str, subfolder: str = "", file_type: str = "output") -> str:
    """Fetch output file from ComfyUI and return as base64."""
    params = urllib.parse.urlencode({
        "filename": filename,
        "subfolder": subfolder,
        "type": file_type,
    })
    with urllib.request.urlopen(f"{COMFYUI_URL}/view?{params}") as r:
        return base64.b64encode(r.read()).decode()


def handler(job):
    job_input = job["input"]
    workflow   = job_input.get("workflow")
    images     = job_input.get("images", [])

    if not workflow:
        return {"error": "No workflow provided"}

    client_id = str(uuid.uuid4())

    # Загружаем входные изображения
    for img in images:
        name = img.get("name", "input_image.png")
        data = img.get("image", "")
        try:
            upload_image(data, name)
        except Exception as e:
            return {"error": f"Failed to upload image {name}: {e}"}

    # Ставим в очередь
    try:
        prompt_id = queue_prompt(workflow, client_id)
    except Exception as e:
        return {"error": f"Failed to queue prompt: {e}"}

    # Ждём завершения
    try:
        outputs = wait_for_completion(prompt_id, client_id)
    except Exception as e:
        return {"error": f"Execution failed: {e}"}

    # Собираем результаты
    results = {"images": [], "videos": []}
    for node_id, node_output in outputs.items():
        for img in node_output.get("images", []):
            b64 = get_file_b64(img["filename"], img.get("subfolder", ""), img.get("type", "output"))
            results["images"].append({"filename": img["filename"], "data": b64, "type": "base64"})
        for vid in node_output.get("gifs", []):
            b64 = get_file_b64(vid["filename"], vid.get("subfolder", ""), vid.get("type", "output"))
            results["videos"].append({"filename": vid["filename"], "data": b64, "type": "base64"})

    return results


runpod.serverless.start({"handler": handler})

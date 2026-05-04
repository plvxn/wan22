#!/bin/bash
# Запускать ОДИН РАЗ на RunPod Pod с подключённым Network Volume
# Использование: CIVITAI_TOKEN=your_token bash download_models.sh
set -e

VOLUME="/runpod-volume/models"
HF_BASE="https://huggingface.co"
mkdir -p $VOLUME/{diffusion_models,text_encoders,vae,loras}

dl() {
    local url=$1
    local out=$2
    local token=$3
    if [ -f "$out" ]; then
        echo "  [skip] $(basename $out) already exists"
        return
    fi
    echo "  Downloading $(basename $out)..."
    if [ -n "$token" ]; then
        wget -q --show-progress -c --header="Authorization: Bearer $token" "$url" -O "$out"
    else
        wget -q --show-progress -c "$url" -O "$out"
    fi
}

echo "=== [1/4] Wan2.2 I2V diffusion models (Kijai fp8_scaled) ==="
dl "$HF_BASE/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/Wan2_2-I2V-A14B-HIGH_fp8_e4m3fn_scaled_KJ.safetensors" \
   "$VOLUME/diffusion_models/Wan2_2-I2V-A14B-HIGH_fp8_e4m3fn_scaled_KJ.safetensors"

dl "$HF_BASE/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/Wan2_2-I2V-A14B-LOW_fp8_e4m3fn_scaled_KJ.safetensors" \
   "$VOLUME/diffusion_models/Wan2_2-I2V-A14B-LOW_fp8_e4m3fn_scaled_KJ.safetensors"

echo "=== [2/4] Text encoder + VAE ==="
dl "$HF_BASE/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors" \
   "$VOLUME/text_encoders/umt5-xxl-enc-bf16.safetensors"

dl "$HF_BASE/Comfy-Org/Wan_2.2_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
   "$VOLUME/vae/wan_2.1_vae.safetensors"

echo "=== [3/4] NSFW LoRAs ==="

# f4c3spl4sh HIGH + LOW (HuggingFace, без авторизации)
dl "$HF_BASE/wiikoo/WAN-LORA/resolve/main/wan2.2/wan22-f4c3spl4sh-100epoc-high-k3nk.safetensors" \
   "$VOLUME/loras/wan22-f4c3spl4sh-high-k3nk.safetensors"

dl "$HF_BASE/wiikoo/WAN-LORA/resolve/main/wan2.2/wan22-f4c3spl4sh-154epoc-low-k3nk.safetensors" \
   "$VOLUME/loras/wan22-f4c3spl4sh-low-k3nk.safetensors"

echo "=== [4/4] Mouthfull Cumshot LoRAs (Civitai) ==="

if [ -z "$CIVITAI_TOKEN" ]; then
    echo "  [SKIP] Mouthfull Cumshot: set CIVITAI_TOKEN to download"
    echo "  Get token: https://civitai.com/user/account -> API Keys"
else
    # HIGH noise version (version 2430424)
    dl "https://civitai.com/api/download/models/2430424" \
       "$VOLUME/loras/wan22-mouthfull-cumshot-high-k3nk.safetensors" \
       "$CIVITAI_TOKEN"
    # LOW noise version (version 2430183)
    dl "https://civitai.com/api/download/models/2430183" \
       "$VOLUME/loras/wan22-mouthfull-cumshot-low-k3nk.safetensors" \
       "$CIVITAI_TOKEN"
fi

echo ""
echo "=== Done ==="
du -sh $VOLUME/*

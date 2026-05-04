#!/bin/bash
set -e

COMFYUI_PATH=/comfyui
VOLUME_PATH=/runpod-volume

echo "[start] Checking GPU..."
python3 -c "import torch; assert torch.cuda.is_available(), 'No GPU!'; print(f'GPU: {torch.cuda.get_device_name(0)}')"

# Если смонтирован Network Volume — симлинкуем модели
if [ -d "$VOLUME_PATH/models" ]; then
    echo "[start] Linking models from Network Volume..."
    for dir in checkpoints clip text_encoders vae loras unet diffusion_models; do
        src="$VOLUME_PATH/models/$dir"
        dst="$COMFYUI_PATH/models/$dir"
        if [ -d "$src" ]; then
            rm -rf "$dst"
            ln -sfn "$src" "$dst"
            echo "  linked $dir"
        fi
    done
else
    echo "[start] No Network Volume found, using local models dir"
fi

# Загрузка tcmalloc для экономии памяти
TCMALLOC=$(ldconfig -p | grep libtcmalloc_minimal | head -1 | awk '{print $NF}')
if [ -n "$TCMALLOC" ]; then
    export LD_PRELOAD="$TCMALLOC"
    echo "[start] tcmalloc loaded"
fi

# Запуск ComfyUI
echo "[start] Starting ComfyUI..."
if [ "$SERVE_API_LOCALLY" = "true" ]; then
    python3 $COMFYUI_PATH/main.py \
        --disable-auto-launch \
        --disable-metadata \
        --listen 0.0.0.0 \
        --port 8188 &
else
    python3 $COMFYUI_PATH/main.py \
        --disable-auto-launch \
        --disable-metadata &
fi

COMFYUI_PID=$!
echo $COMFYUI_PID > /tmp/comfyui.pid

# Ждём пока ComfyUI поднимется
echo "[start] Waiting for ComfyUI..."
for i in $(seq 1 60); do
    if curl -s http://127.0.0.1:8188/system_stats > /dev/null 2>&1; then
        echo "[start] ComfyUI ready!"
        break
    fi
    sleep 2
done

# Запуск RunPod handler
echo "[start] Starting handler..."
python3 -u /handler.py

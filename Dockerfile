FROM nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    COMFYUI_PATH=/comfyui \
    MODELS_PATH=/runpod-volume/models \
    VENV_PATH=/opt/venv

# System deps
RUN apt-get update && apt-get install -y \
    python3.12 python3.12-venv python3-pip \
    git wget curl ffmpeg libgl1 libglib2.0-0 \
    libgomp1 libtcmalloc-minimal4 \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/python3.12 /usr/bin/python3 && \
    ln -sf /usr/bin/python3.12 /usr/bin/python

# Virtualenv
RUN python3 -m venv $VENV_PATH
ENV PATH="$VENV_PATH/bin:$PATH"

# PyTorch + ComfyUI deps
RUN pip install --upgrade pip && \
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124 && \
    pip install runpod requests websocket-client Pillow numpy einops transformers accelerate \
                diffusers safetensors kornia scipy imageio

# ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git $COMFYUI_PATH && \
    pip install -r $COMFYUI_PATH/requirements.txt

# Custom nodes
WORKDIR $COMFYUI_PATH/custom_nodes

# WanVideoWrapper (Kijai) — SVI, I2V, video extend
RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git && \
    pip install -r ComfyUI-WanVideoWrapper/requirements.txt

# K3NK nodes — frame grabbing, video continuation
RUN git clone https://github.com/K3NK3/ComfyUI-K3NK-ComfyUI-Nodes.git && \
    pip install -r ComfyUI-K3NK-ComfyUI-Nodes/requirements.txt

# ComfyUI-VideoHelperSuite — video load/save utils
RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    pip install -r ComfyUI-VideoHelperSuite/requirements.txt

# ComfyUI-KJNodes — misc utils used by K3NK workflow
RUN git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
    pip install -r ComfyUI-KJNodes/requirements.txt

# Symlink Network Volume models → ComfyUI models dir
# При старте start.sh создаёт симлинки если Volume смонтирован
WORKDIR /

# Handler + startup
COPY handler.py /handler.py
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]

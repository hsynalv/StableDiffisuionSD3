FROM nvidia/cuda:12.6.3-cudnn-runtime-ubuntu22.04 AS base

# Set build arguments
ARG PYTHON_VERSION=3.11
ARG PYTORCH_VERSION=2.6.0
ARG TORCHVISION_VERSION=0.21.0

# Set environment variables with optimizations for serverless
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=$(nproc) \
    # NVIDIA high-end GPU optimizations
    CUDA_DEVICE_MAX_CONNECTIONS=1 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    # Enable TF32 for faster compute on A100/H100
    NVIDIA_TF32_OVERRIDE=1 \
    # Optimize cuDNN for Ampere/Hopper architecture
    CUDNN_FRONTEND_MEMORY_OPTM_MODE=1 \
    MALLOC_CONF="background_thread:true,metadata_thp:auto" \
    TCMALLOC_SAMPLE_PARAMETER=4194304 \
    # More comprehensive preload that handles both lib paths
    LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libtcmalloc.so.4:/usr/lib/libtcmalloc.so.4" \
    TCMALLOC_LARGE_ALLOC_REPORT_THRESHOLD=8589934592 \
    TCMALLOC_RELEASE_RATE=1.0 \
    TCMALLOC_PAGE_FENCE=0

# Create and set working directory
WORKDIR /app

# Install system dependencies and clean up in the same layer to reduce image size
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3-pip \
    git \
    wget \
    libgl1 \
    google-perftools \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install Python packages with optimization tools
RUN pip install --upgrade pip && \
    pip install --no-cache-dir torch==${PYTORCH_VERSION}+cu126 torchvision==${TORCHVISION_VERSION}+cu126 --extra-index-url https://download.pytorch.org/whl/cu126 && \
    pip install --no-cache-dir accelerate safetensors bitsandbytes comfy-cli

RUN /usr/bin/yes | comfy --workspace /comfyui install --cuda-version 12.6 --nvidia --version 0.3.24

WORKDIR /comfyui

# Copy requirements file first to leverage Docker cache
COPY requirements.txt .
RUN pip install -r requirements.txt

ADD src/extra_model_paths.yaml ./

WORKDIR /

# Restore snapshot if it exists
ADD *snapshot*.json /

# Add scripts that for custom node restoration and start.sh
ADD src/start.sh src/restore_snapshot.sh src/rp_handler.py ./
RUN chmod +x /start.sh /restore_snapshot.sh

RUN /restore_snapshot.sh

# Start container
CMD ["/start.sh"]

FROM base as model-downloader

# Set HuggingFace token
ARG HUGGINGFACE_ACCESS_TOKEN

WORKDIR /comfyui

RUN mkdir -p models/diffusion_models models/vae models/controlnet models/text_encoders

RUN if [ -n "${HUGGINGFACE_ACCESS_TOKEN}" ]; then \
    wget --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/diffusion_models/sd3.5_large.safetensors https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/sd3.5_large.safetensors && \
    wget --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/vae/sdvae.safetensors https://huggingface.co/stabilityai/stable-diffusion-3.5-large/resolve/main/vae/diffusion_pytorch_model.safetensors && \
    wget --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/controlnet/sd3.5_large_controlnet_blur.safetensors https://huggingface.co/stabilityai/stable-diffusion-3.5-controlnets/resolve/main/sd3.5_large_controlnet_blur.safetensors && \
    wget --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/controlnet/sd3.5_large_controlnet_canny.safetensors https://huggingface.co/stabilityai/stable-diffusion-3.5-controlnets/resolve/main/sd3.5_large_controlnet_canny.safetensors && \
    wget --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/controlnet/sd3.5_large_controlnet_depth.safetensors https://huggingface.co/stabilityai/stable-diffusion-3.5-controlnets/resolve/main/sd3.5_large_controlnet_depth.safetensors && \
    wget -O models/text_encoders/clip_l.safetensors https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/text_encoders/clip_l.safetensors && \
    wget -O models/text_encoders/clip_g.safetensors https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/text_encoders/clip_g.safetensors && \
    wget -O models/text_encoders/t5xxl_fp16.safetensors https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/text_encoders/t5xxl_fp16.safetensors; \
fi

# Stage 3: Final image
FROM base as final

# Copy models from model-downloader stage to the final image
COPY --from=model-downloader /comfyui/models /comfyui/models

# Start container
CMD ["/start.sh"]
 

# ComfyUI RunPod Worker

A high-performance Docker container for running ComfyUI on RunPod serverless GPUs.

## Features

- Optimized for high-end NVIDIA GPUs (A100, H100)
- TF32 precision for faster image generation without quality loss
- RunPod serverless compatibility
- Pre-installed ComfyUI with latest version
- Optional SD3.5 model loading with HuggingFace token

## Usage

### Running on RunPod

1. Deploy the container on [RunPod serverless](https://www.runpod.io/serverless)
2. Use the RunPod API to submit jobs to your endpoint

### Building Locally

```bash
docker build -t comfyui-runpod-worker .
```

### Building with Models

To include SD3.5 models in the build, provide your HuggingFace token:

```bash
docker build --build-arg HUGGINGFACE_ACCESS_TOKEN=your_token_here -t comfyui-runpod-worker .
```

## Environment Variables

- `NVIDIA_TF32_OVERRIDE=1`: Enables TF32 precision (for A100/H100)

## Performance Optimizations

- TF32 precision on Ampere/Hopper GPUs for 30-50% faster image generation
- Optimized memory allocation with tcmalloc
- CUDA memory settings for high-performance GPU operations

## License

[MIT License](LICENSE) 

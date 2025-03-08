# ComfyUI RunPod Worker Usage Guide

This guide explains how to use the ComfyUI RunPod Worker in various scenarios.

## Deploying on RunPod

### 1. Build and Push the Docker Image

First, build your container and push it to a registry like Docker Hub:

```bash
# Build the image
docker build -t yourusername/comfyui-runpod-worker:latest .

# Push to Docker Hub
docker push yourusername/comfyui-runpod-worker:latest
```

### 2. Create a RunPod Serverless Template

1. Go to RunPod.io and log in
2. Navigate to Serverless → Templates
3. Click "New Template"
4. Fill in the details:
   - Name: `ComfyUI Worker`
   - Container Image: `yourusername/comfyui-runpod-worker:latest`
   - Container Disk: `10 GB` (or more if needed)
   - Select the appropriate GPU (A100, H100 recommended for TF32 benefits)
   - Environment Variables: (leave default)
   - Exposed Port: `8188`

### 3. Deploy an Endpoint

1. Go to Serverless → Endpoints
2. Click "New Endpoint"
3. Select your ComfyUI Worker template
4. Choose the GPU type and worker count
5. Create the endpoint

### 4. Using the Endpoint

You can interact with your endpoint using the RunPod API:

```python
import runpod
import base64
import json

# Initialize RunPod
runpod.api_key = "YOUR_RUNPOD_API_KEY"

# Prepare your ComfyUI workflow
workflow = {
    "prompt": {
        # Your ComfyUI workflow JSON here
    }
}

# Send to the endpoint
response = runpod.run_sync(
    endpoint_id="YOUR_ENDPOINT_ID",
    input=workflow
)

# Process the results
print(response)
```

## Performance Optimization

### High-End GPU Optimization

This container is optimized for high-end GPUs like the A100 and H100 with:

- TF32 precision for faster matrix operations (30-50% speed improvement)
- Optimized CUDA memory management
- Advanced cuDNN settings

### Memory Management

The container uses tcmalloc for better memory management, which improves performance especially in serverless environments where efficient memory usage is critical.

## Troubleshooting

### Common Issues

1. **Container fails to start**: Check that the RunPod template has sufficient disk space (10GB+)
2. **Models not loading**: If using your own HuggingFace token, verify it has the correct permissions
3. **Poor performance**: Make sure you're using A100/H100 GPUs to benefit from TF32 optimizations

### Logs

You can view logs for your endpoint in the RunPod dashboard under Serverless → Endpoints → Your Endpoint → Logs.

## Advanced Configuration

### Environment Variables

You can customize the behavior by adding these environment variables to your RunPod template:

- `CUDA_VISIBLE_DEVICES`: Control which GPUs are used
- `PYTORCH_CUDA_ALLOC_CONF`: Fine-tune CUDA memory allocation
- `RUNPOD_WORKER_TIMEOUT`: Adjust the worker timeout (default: 30s)

### Custom Models

To use custom models, build the container with your HuggingFace token:

```bash
docker build --build-arg HUGGINGFACE_ACCESS_TOKEN=your_token_here -t yourusername/comfyui-runpod-worker:custom .
``` 
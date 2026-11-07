#!/bin/bash
set -e

exec > /var/log/vllm-setup.log 2>&1

echo "=== vLLM Setup Starting ==="

# Wait for any existing apt/dpkg processes to finish (DLAMI runs setup on boot)
echo "Waiting for dpkg lock to be released..."
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "dpkg lock held by another process, waiting 10s..."
    sleep 10
done

echo "Lock released, proceeding..."

# Login to AWS ECR to pull the DLC image
aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin 763104351884.dkr.ecr.${region}.amazonaws.com

# Pull the vLLM DLC image
docker pull 763104351884.dkr.ecr.${region}.amazonaws.com/vllm:0.8.5-gpu-py312-ec2

# Run vLLM as a Docker container with restart policy
# Override the DLC entrypoint and run vLLM directly
docker run -d \
  --name vllm-server \
  --gpus all \
  --restart always \
  -p 8000:8000 \
  --entrypoint python \
  763104351884.dkr.ecr.${region}.amazonaws.com/vllm:0.8.5-gpu-py312-ec2 \
  -m vllm.entrypoints.openai.api_server \
    --model ${model_name} \
    --host 0.0.0.0 \
    --port 8000 \
    --tensor-parallel-size 1 \
    --max-model-len ${max_model_len} \
    --gpu-memory-utilization ${gpu_memory_utilization} \
    --enable-prefix-caching

echo "=== vLLM Setup Complete ==="

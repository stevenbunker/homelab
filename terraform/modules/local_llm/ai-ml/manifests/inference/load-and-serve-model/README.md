## Load and serve a model

Manifests for the [Load and serve a model](https://docs.aws.amazon.com/eks/latest/userguide/ml-inference-load-serve-model.html) walkthrough. Apply them against the cluster from [`set-up-cluster/terraform/`](../../../set-up-cluster/terraform/).

- `model-download-job.yaml` - Job that downloads the model into the S3 model bucket.
- `vllm-deployment.yaml` - vLLM deployment that serves the model on GPU nodes.
- `vllm-servicemonitor.yaml` - ServiceMonitor that exposes vLLM metrics to Prometheus.
- `open-webui.yaml` - Open WebUI front end for chatting with the model.

### Apply

Files that reference `${MODEL_BUCKET}` need the variable substituted at apply time:

```bash
export MODEL_BUCKET=$(terraform -chdir=../../../set-up-cluster/terraform/auto-mode output -raw model_bucket)

envsubst < model-download-job.yaml | kubectl apply -f -
```

Files without variables apply directly:

```bash
kubectl apply -f vllm-deployment.yaml
```

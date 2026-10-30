#!/bin/bash
#
# Usage: ./cleanup.sh [--auto-approve]
# Run from terraform/auto-mode/ or terraform/karpenter/.

set -euo pipefail

log() { printf '\n==> %s\n' "$*"; }

[[ -f main.tf && -f eks.tf ]] || {
  echo "Run this from terraform/auto-mode/ or terraform/karpenter/" >&2
  exit 1
}

destroy_args=()
[[ "${1:-}" == "--auto-approve" ]] && destroy_args=(-input=false -auto-approve)

REGION="$(terraform output -raw region 2>/dev/null || true)"
CLUSTER_NAME="$(terraform output -raw cluster_name 2>/dev/null || true)"

log "Draining cluster (PDBs, NodeClaims, NodePools, NodeClasses)"
kubectl delete pdb -A --all 2>/dev/null || true
kubectl delete nodeclaim --all --wait=true --timeout=900s 2>/dev/null || true
kubectl delete nodepool --all --wait=true --timeout=120s 2>/dev/null || true
kubectl delete ec2nodeclass --all --wait=true --timeout=120s 2>/dev/null || true
kubectl delete nodeclass --all --wait=true --timeout=120s 2>/dev/null || true

# The load balancer controller creates the ALB and its security groups in
# response to the Ingress, so Terraform does not track them. Left behind, their
# network interfaces hold the public subnets and the VPC destroy never finishes.
log "Deleting Ingresses so the load balancer controller removes their ALBs"
kubectl delete ingress -A --all 2>/dev/null || true

if [[ -n "$REGION" && -n "$CLUSTER_NAME" ]]; then
  log "Waiting for controller-managed load balancers to go away"
  for _ in $(seq 1 60); do
    remaining="$(aws resourcegroupstaggingapi get-resources \
      --region "$REGION" \
      --resource-type-filters elasticloadbalancing:loadbalancer \
      --tag-filters "Key=elbv2.k8s.aws/cluster,Values=${CLUSTER_NAME}" \
      --query 'length(ResourceTagMappingList)' \
      --output text 2>/dev/null || echo 0)"
    [[ "$remaining" == "0" ]] && break
    sleep 10
  done
  [[ "${remaining:-0}" == "0" ]] || log "WARNING: load balancers still present; destroy may stall on the VPC"

  log "Deleting leftover controller-managed security groups"
  for sg in $(aws ec2 describe-security-groups \
    --region "$REGION" \
    --filters "Name=tag:elbv2.k8s.aws/cluster,Values=${CLUSTER_NAME}" \
    --query 'SecurityGroups[].GroupId' \
    --output text 2>/dev/null || true); do
    aws ec2 delete-security-group --region "$REGION" --group-id "$sg" 2>/dev/null \
      && log "deleted $sg" || log "could not delete $sg yet"
  done
fi

log "Running terraform destroy"
# A Helm uninstall can exceed its timeout and leave the cluster and VPC in
# place. A second destroy picks up where the first one stopped.
terraform destroy "${destroy_args[@]+"${destroy_args[@]}"}" || {
  log "First destroy failed; retrying once"
  terraform destroy "${destroy_args[@]+"${destroy_args[@]}"}"
}

log "Cleanup complete"

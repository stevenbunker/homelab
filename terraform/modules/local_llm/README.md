## Attribution

This was created and modified based on the [Machine Learning on EKS](https://docs.aws.amazon.com/eks/latest/userguide/ml-on-eks.html) section of the AWS EKS User Guide.

The original repo can be found [in aws-samples](https://github.com/aws-samples/sample-eks-docs).

## EKS User Guide Samples

This repository contains code samples used in the [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/ml-on-eks.html).

## Changes from Source

- The source creates a new VPC. I will instead feed an existing VPC ID as a variable
- I would prefer to set up monitoring independently, so that was removed from the module
- I will use Karpenter, allowing me to delete the alternate path, and flatten the module

# ML on EKS - cluster setup (Terraform)

Builds an EKS cluster. The compute is self-managed with [Karpenter](https://karpenter.sh/). Full control over node configuration.

This gives you a running cluster with ingress. You can customize the defaults by overriding them using `-var <property=value>`.

> **Run `terraform apply` directly - don't apply a saved plan file.** The `kubernetes`, `helm`, and `kubectl` providers authenticate with a token from the `aws_eks_cluster_auth` data source. `terraform plan -out` freezes that token, and it has expired by the time you apply the saved plan, so every Helm release and Kubernetes object fails with `Unauthorized` / `the server has asked for the client to provide credentials` after the cluster itself is already created.

## Access EKS Cluster

Verify the cluster is up. The stack emits a ready-to-run `update-kubeconfig` command with the values provided during deployment.

```bash
eval "$(terraform output -raw configure_kubectl)"
kubectl get nodes
```

Other useful outputs: `cluster_name`, `region`, `node_iam_role_name`, and `model_bucket` (the model S3 bucket).

## GPU NodePools

Pick a strategy from the table, then follow the linked steps. The first two are driven by `var.nodepools` (Terraform provisions everything); the static pools are applied manually with `kubectl` because Terraform can't create a Capacity Block for a specific instance type/date. The `var.nodepools` strategies are mutually exclusive - enable at most one.

| Strategy                     | Use when…                                                          | How it's applied      | Steps                                                             |
| ---------------------------- | ------------------------------------------------------------------ | --------------------- | ----------------------------------------------------------------- |
| _(none, default)_            | You only want the cluster + monitoring, no GPU capacity or billing | `terraform apply`     | Nothing extra - this is the default                               |
| `spot-ondemand`              | On-demand GPU inference, no reservation; spot-first with overflow  | `terraform -var`      | [On-demand / spot pool](#on-demand--spot-pool)                    |
| `reserved-spot-ondemand`     | You want Terraform to create + manage an ODCR for you              | `terraform -var`      | [Reserved capacity](#reserved-capacity)                           |
| `b-200s-static`              | You already hold reservation / Capacity Block | `kubectl`      | [automode](auto-mode/nodepools/b-200s-static/README.md) / [karpenter](karpenter/nodepools/b-200s-static/README.md) |
| `b-200s-static-fsx` (karpenter only) | The above, plus an EFA-accelerated FSx for Lustre mount    | `kubectl`      | [karpenter](karpenter/nodepools/b-200s-static-fsx/README.md) |

> Some GPU pools can't be wired into `var.nodepools` - Terraform can't create a Capacity Block for a specific instance type/date - so they're applied manually with `kubectl` against a reservation or Capacity Block you already have.

### On-demand / spot pool

Enable the on-demand/spot pool with no reservation:

```bash
terraform apply -var 'nodepools={"spot-ondemand"={}}'
```

### Reserved capacity

The reserved strategies need a `reservation`. Terraform creates the On-Demand Capacity Reservation (ODCR) for you - you do not supply a reservation ID. The ODCR is tagged `nodepool=<strategy>` and the NodeClass selects it by that tag.

Use defaults (`g6e.4xlarge`, 1 instance, first cluster AZ):

```bash
terraform apply -var 'nodepools={"reserved-spot-ondemand"={reservation={}}}'
```

Pick the instance type, count, and AZ:

```bash
terraform apply -var 'nodepools={"reserved-spot-ondemand"={reservation={instance_type="g6e.4xlarge",instance_count=3,az="us-east-2a"}}}'
```

Notes:

- An ODCR **bills as soon as it is created** and keeps billing until destroyed, whether or not nodes are running on it.
- The reservation is a single block in **one AZ**. EC2 reserves all of `instance_count` in that AZ or fails with `InsufficientInstanceCapacity` - there is no automatic AZ fallback. If creation fails, set `reservation.az` to another AZ and re-apply.

## Elastic Fabric Adapter(EFA)

[Elastic Fabric Adapter](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html) gives EFA-capable instances (`p*` family, `g*.8xlarge`/`.16xlarge` and larger) a high-bandwidth RDMA path for multi-node training/inference and for FSx for Lustre. `var.enable_efa` (default `false`) installs the EFA device plugin and the self-referencing security-group rule EFA requires. On `auto-mode/` it's the only way to get the plugin, since Auto Mode doesn't bundle it.

Enable it when a NodePool actually uses EFA - either a NodeClass requesting `efa-only` interfaces (static capacity-block pools), or a pod requesting the `vpc.amazonaws.com/efa` resource:

```bash
terraform apply -var 'enable_efa=true'
```

It's an independent flag - combine it with any GPU strategy from the table above (e.g. `-var 'nodepools={"spot-ondemand"={}}'`). For the reserved strategy, override the default `reservation.instance_type` (`g6e.4xlarge` isn't EFA-capable) to `.8xlarge` or larger.

Enabling EFA also installs the [MPI Operator](https://github.com/kubeflow/mpi-operator) for distributed `MPIJob` resources (multi-node NCCL/EFA tests).

## Shared storage (FSx for Lustre)

For a high-throughput, `ReadWriteMany` filesystem that many GPU pods mount at once — training datasets, checkpoints, shared scratch — enable [FSx for Lustre](https://docs.aws.amazon.com/fsx/latest/LustreGuide/what-is.html). Terraform provisions the file system, the CSI driver, and a static PV/PVC behind `enable_fsx`; **both variants** mount it over TCP.

```bash
terraform apply -var 'enable_fsx=true' -var "subnet_id=<private subnet in your GPU AZ>"
```

See [`../../manifests/fsx-lustre/README.md`](../../manifests/fsx-lustre/README.md) for the full provision-and-test walkthrough (works on either variant). On Karpenter you can additionally mount Lustre over the **EFA (RDMA)** transport — see the [`b-200s-static-fsx`](karpenter/nodepools/b-200s-static-fsx/README.md) nodepool guide.

## Ingress (ALB)

Both variants ship a default `alb` `IngressClass`, so any `Ingress` with no `ingressClassName` gets an internet-facing Application Load Balancer automatically - always on, no flag. They differ only in plumbing: `auto-mode/` uses Auto Mode's built-in ALB controller (just an `IngressClass` + `IngressClassParams`), while `karpenter/` installs the full [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/) (IAM role/policy, pod identity, Helm release) since it has none built in.

### Grafana

Both variants expose Grafana through an ALB `Ingress`. Access is gated by `var.my_cidr`, which defaults to `0.0.0.0/0` - **open to the world**. Restrict it to your own IP (re-apply any time to change it):

```bash
export MY_CIDR="$(curl -s https://checkip.amazonaws.com)/32"
echo "$MY_CIDR"    # expect x.x.x.x/32

terraform apply -var "my_cidr=${MY_CIDR}"
```

Get the ALB hostname (created asynchronously - allow a minute or two) and open it in a browser:

```bash
echo "http://$(kubectl get ingress kube-prometheus-stack-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```

Log in as `admin` with the password from:

```bash
kubectl --namespace monitoring get secrets kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

## Clean up

Use the helper script, which drains the Karpenter-managed nodes, removes the Ingresses so the load balancer controller deletes their ALBs and security groups, and then runs `terraform destroy` (retrying once if a Helm uninstall times out):

```bash
../../scripts/cleanup.sh            # add --auto-approve to skip the prompt
```

To delete everything by hand instead (cluster, VPC, monitoring, any ODCR):

```bash
kubectl delete ingress -A --all     # let the controller remove the ALBs first
terraform destroy
```

Pass `terraform destroy` the same `-var` overrides you passed to `terraform apply`, including `region` and `nodepools`; Terraform does not persist variables between commands.

The ALB and the security groups that the load balancer controller creates for an `Ingress` are not in Terraform state. If you skip deleting the Ingresses, their network interfaces hold the public subnets and the destroy stalls on `aws_subnet.public[*]`, the internet gateway, and `aws_vpc`. Delete the leftovers and the destroy continues:

```bash
aws elbv2 describe-load-balancers --region "$REGION" \
  --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text
aws ec2 describe-security-groups --region "$REGION" \
  --filters "Name=tag:elbv2.k8s.aws/cluster,Values=$CLUSTER_NAME" \
  --query 'SecurityGroups[].GroupId' --output text
```

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This project is licensed under the Apache-2.0 License.


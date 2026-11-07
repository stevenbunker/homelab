# Security Best Practices

The following are recommended security hardening measures to consider when
deploying this solution in production. This is **sample/demo code**: the vLLM
instance runs in a private subnet with no public endpoint and is reached through
an SSM port-forwarding tunnel, but several things still need hardening before any
real use.

1. **Amazon EBS Encryption with a Customer-Managed KMS Key** — Enable EBS
   encryption on the instance root/data volumes using a customer-managed KMS CMK
   rather than leaving volumes unencrypted, for stricter key rotation and access
   control.

2. **vLLM API Authentication and Authorization** — The vLLM OpenAI-compatible
   server has no authentication by default. Put an API gateway or reverse proxy
   in front, or set vLLM's `--api-key`, and add rate limiting. This solution
   avoids exposure by keeping the instance private and reachable only via SSM.

3. **TLS for Any Public Endpoint** — If you must expose the API, front it with an
   Application Load Balancer using an HTTPS listener backed by an ACM certificate
   (TLS 1.2+) and redirect HTTP→HTTPS. Do not serve plain HTTP.

4. **Least-Privilege IAM** — The instance role uses AWS managed policies
   (`AmazonSSMManagedInstanceCore`, `AmazonEC2ContainerRegistryReadOnly`). In
   production, replace these with scoped custom policies granting only the
   actions and resources the instance actually needs.

5. **Restrict Security Group Ingress and Egress** — The instance security group
   has no inbound rules, and egress is limited to TCP 443 (HTTPS) for ECR, SSM,
   and model pulls. For further hardening, scope egress to the specific
   endpoints you need (ECR, S3, your model source), using VPC endpoints where
   possible to avoid the NAT path.

6. **Pin the AMI and Container Image** — This solution uses a `most_recent` DLAMI
   lookup and a floating container tag (`vllm:0.8.5-gpu-py312-ec2`). In
   production, pin the AMI ID and the container image digest so deploys are
   reproducible and reviewable, and keep them patched.

7. **Enforce IMDSv2** — Already enforced on the launch template
   (`http_tokens = required`). Keep this setting to prevent SSRF-style access to
   the instance metadata service.

8. **Amazon CloudWatch Logs and CloudTrail** — Enable CloudWatch logs/metrics
   and CloudTrail, and add alarms for instance and health failures. Create
   explicit log groups with KMS encryption and a retention policy.

9. **Enable VPC Flow Logs** — Enable VPC Flow Logs in production to get network
   visibility. Capturing accepted and rejected traffic across the VPC helps with
   security monitoring, anomaly detection, and troubleshooting.

10. **Protect Terraform State and Secrets** — Never commit `terraform.tfvars`,
   state files, or keys (they are excluded via `.gitignore` — keep it that way).
   Store state in a remote backend (for example, S3 with a DynamoDB lock) with
   encryption for team use.

## Reporting a Vulnerability

If you discover a potential security issue in this project, we ask that you
notify AWS Security via our
[vulnerability reporting page](https://aws.amazon.com/security/vulnerability-reporting/).
Please do **not** create a public GitHub issue.

# output "vllm_access" {
#   description = "How to reach vLLM via SSM port forwarding (no public endpoint)"
#   value       = <<-EOT
#     1. Find the instance ID:
#        aws autoscaling describe-auto-scaling-instances --region ${var.region} \
#          --query "AutoScalingInstances[?AutoScalingGroupName=='vllm-asg'].InstanceId" --output text

#     2. Start a port-forwarding session (maps local 8000 -> instance 8000):
#        aws ssm start-session --target <instance-id> --region ${var.region} \
#          --document-name AWS-StartPortForwardingSession \
#          --parameters '{"portNumber":["8000"],"localPortNumber":["8000"]}'

#     3. In another terminal, call the local tunnel:
#        curl http://localhost:8000/v1/chat/completions \
#          -H "Content-Type: application/json" \
#          -d '{"model": "${var.model_name}", "messages": [{"role": "user", "content": "Hello"}], "max_tokens": 100}'
#   EOT
# }
output "local-inference" {
  description = "Outputs from making an local-inference server"
  type        = map(string)
  value = {
    local_infrence_network_interface_id = aws_instance.this.primary_network_interface_id  
  }
}


output "ami_used" {
  description = "AMI ID used for the instance"
  value       = data.aws_ami.dlami.id
}


locals {
  Project = "local-infrence"
}

# Find the Deep Learning OSS Nvidia Driver AMI (Ubuntu 24.04)
data "aws_ami" "this" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Deep Learning AMI Neuron (Ubuntu 24.04)"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  tags = {
    OS_version = "Ubuntu 24.04"
  }
}

# Launch Template
resource "aws_instance" "this" {
  ami      = data.aws_ami.dlami.id
  instance_type = var.instance_type
  subnet_id = var.private_subnet_id

  # iam_instance_profile {
  #   arn = aws_iam_instance_profile.vllm.arnq
  # }

  vpc_security_group_ids = concat([aws_security_group.instance.id], var.additiona_security_group_ids)

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size           = 100
    volume_type           = "gp3"
    delete_on_termination = true
    }

  private_dns_name_options {
    hostname_type = "resource-name"
  }

  # user_data = base64encode(templatefile("${path.module}/userdata.sh", {
  #   region                 = var.region
  #   model_name             = var.model_name
  #   max_model_len          = var.max_model_len
  #   gpu_memory_utilization = var.gpu_memory_utilization
  # }))

  tags = {
    resource_type = "instance"
    Name = "vllm-inference-server"
    Project             = local.Project
    Environment         = var.environment
    OS_version          = data.aws_ami.this.tags.OS_version
    is_public           = data.aws_subnet.this.tags.is_public
    }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}

# Instance Security Group - no inbound; access via SSM Session Manager only
resource "aws_security_group" "this" {
  name        = "vllm-instance-sg"
  description = "Security group for vLLM instance"
  vpc_id      = var.vpc_id

  tags = {
    Name = "vllm-instance-sg"
  }
}

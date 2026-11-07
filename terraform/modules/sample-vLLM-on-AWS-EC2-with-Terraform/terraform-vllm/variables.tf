variable "instance_type" {
  description = "EC2 instance type (must be a GPU instance)"
  type        = string
  default     = "inf2.xlarge"
}

variable "environment" {
  description = "Environment for tagging"
  type = string
  default = "test"
}

# variable "model_name" {
#   description = "HuggingFace model to serve"
#   type        = string
#   default     = "Qwen/Qwen2.5-0.5B-Instruct"
# }

# variable "max_model_len" {
#   description = "Maximum sequence length for the model"
#   type        = number
#   default     = 8192
# }

variable "gpu_memory_utilization" {
  description = "Fraction of GPU memory to use for KV cache"
  type        = string
  default     = "0.85"
}

# Networking - if provided, use existing; if empty, create new
variable "vpc_id" {
  description = "Existing VPC ID."
  type        = string
}

# variable "public_subnet_ids" {
#   description = "Existing public subnet IDs (used only for the NAT gateway when creating new networking). Leave empty to create new."
#   type        = list(string)
# }

variable "subnet_id" {
  description = "The subnet id the LLM inference server will be assigned to"
  type        = string
}

variable "additiona_security_group_ids" {
  description = "Existing security groups to assign to the instance"
  type        = list(string)
  default = []
}


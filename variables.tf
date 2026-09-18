variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type (must be a GPU instance)"
  type        = string
  default     = "t3.nano"
}

variable "project_tags" {
  description = "Tags to set for all resources"
  type        = map(string)
}

variable "aws_vpc_cidr" {
  description = "IP range for VPC in cidr notation"
  type        = string
}

variable "ssh_ip_allowed" {
  description = "CIDR notation for allowed SSH"
  type = string  
}
variable "region" {
  description = "AWS region"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (must be a GPU instance)"
  type        = string
  default     = "t3.micro"
}

variable "required_tags" {
  description = "Tags to set for all resources"
  type = list(string)
}

variable "aws_vpc_cidr" {
  description = "IP range for VPC in cidr notation"
  type        = string
}

variable "ssh_ip_allowed" {
  description = "CIDR notation for allowed SSH"
  type        = string
}

variable "hosted_zone" {
  type = string
  description = "Necessary tags to maintain Route53 record on EC2 Instance"
}

variable "record_name" {
  type = string
  description = "Necessary tags to maintain Route53 record on EC2 Instance"
}
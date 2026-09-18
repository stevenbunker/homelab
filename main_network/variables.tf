variable "aws_vpc_cidr" {
  description = "IP range for VPC in cidr notation"
  type        = string
  default = "172.31.0.0/16"
}

variable "project_tags" {
  description = "Tags to set for all resources"
  type        = map(string)
  default = {
    "project" = "main_network"
  }
}
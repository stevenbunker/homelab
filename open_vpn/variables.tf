variable "project_tags" {
  default     = {
    project = "open_vpn"
  }
  description = "Additional resource tags"
  type        = map(string)
}

variable "ssh_ip_allowed" {
  description = "CIDR notation for allowed SSH"
  type = string  
}

variable "main_public_subnet_id" {
  description = "ID for the public subnet range made by another module"
  type = string
}

variable "main_vpc_id" {
  description = "ID for the VPC made by another module"
  type = string
}

variable "hosted_Zone" {
  type = string
  description = "Necessary tags to maintain Route53 record on EC2 Instance"
}

variable "record_name" {
  type = string
  description = "Necessary tags to maintain Route53 record on EC2 Instance"
}

variable "ami_id" {
  type = string
  description = "AMI ID to start instance"
  default = "ami-06c77cb49ac92a541"
}
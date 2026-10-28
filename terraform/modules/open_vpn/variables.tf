variable "instance_type" {
  description = "EC2 instance type (must be a GPU instance)"
  type        = string
  default     = "t3.micro"
}

variable "hosted_zone_name" {
  description = "The name of a hosted zone domain you own in route53"
  type        = string
}

variable "ovpn_cidr" { # All the OVPN stuff needs to get moved to a module
  description = "The local network on the OVPN"
  type        = string
  default     = "10.8.0.0/24"
}

variable "vpc_id" {
  description = "The VPC id the Open VPN instance will be assigned to"
  type        = string
}

variable "subnet_id" {
  description = "The subnet id the Open VPN instance will be assigned to"
  type        = string
}

variable "Environment" {
  description = "What to set as the Environment tag in aws"
  type        = string
  default     = "test"
}
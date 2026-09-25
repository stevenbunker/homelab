variable "region" {
  description = "AWS region"
  type        = string
}

variable "aws_regions" {
  description = "Allowed AWS regions"
  type        = map(string)
  default = {
    us-east-1 : "east"
    us-west-1 : "west"
  }
}

variable "environments" {
  description = "Allowed environment options"
  type        = set(string)
  default = [
    "prod",
    "shared",
    "test"]
}

variable "instance_type" {
  description = "EC2 instance type (must be a GPU instance)"
  type        = string
  default     = "t3.micro"
}

variable "required_tags" {
  description = "Tags to set for all resources"
  type        = list(string)
  default     = ["Project", "Environment"]
}

variable "aws_vpc_cidr" {
  description = "IP range for VPC in cidr notation"
  type        = string
}

variable "ssh_ip_allowed" {
  description = "CIDR notation for allowed SSH"
  type        = string
}

# Ingress rules map:
# Use either cidr_ipv4 OR source_sg_id
variable "ingress_rules" {
  type = map(object({
    from_port    = number
    to_port      = number
    ip_protocol  = optional(string, "tcp")
    cidr_ipv4    = optional(string)
    source_sg_id = optional(string)
    description  = optional(string)
  }))
}
# Egress rules map (default allow all outbound):
# Use either cidr_ipv4 OR dest_sg_id
variable "egress_rules" {
  type = map(object({
    ip_protocol = optional(string, "-1")
    from_port   = optional(number, 0)
    to_port     = optional(number, 0)
    cidr_ipv4   = optional(string)
    dest_sg_id  = optional(string)
    description = optional(string)
  }))
  default = {
    allow_all_outbound = {
      ip_protocol = "-1"
      from_port   = 0
      to_port     = 0
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow all outbound"
    }
  }
}
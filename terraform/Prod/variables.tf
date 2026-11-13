variable "region" {
  description = "AWS region"
  type        = string
}

variable "environments" {
  description = "Allowed environment options"
  type        = set(string)
  default = [
    "prod",
    "shared",
    "test"
  ]
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

variable "allowed_ec2_os" {
  description = "Tags to set for all resources"
  type        = list(string)
}

variable "vpcs" {
  description = "VPCs in the organization"
  type = map(object({
    region             = string
    vpc_netmask_length = optional(number, 16)
    subnets = list(object({
      public                = optional(bool, false)
      subnet_netmask_length = optional(number, 24)
    }))
  }))
  validation {
    error_message = "VPC name must start with it's region"
    condition = alltrue([
      for vpc_name, vpc_values in var.vpcs :
      strcontains(
        vpc_name,
        vpc_values.region
      )
    ])
  }
}

variable "private_ipv4_cidr" {
  description = "ipv4 cidr to be subdivided across VPCs and subnets"
  type        = string
  default     = "172.16.0.0/12"

  validation {
    error_message = "CIDR must have a netmask length less than 20"
    condition     = can(cidrhost(var.private_ipv4_cidr, 4096))
  }
}

variable "hosted_zone_name" {
  description = "The name of a hosted zone domain you own in route53"
  type        = string
  default     = null
}
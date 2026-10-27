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
    region           = string
    default          = bool
    internet_gateway = bool
    vpc_cidr         = string
    subnets = map(object({
      public     = bool
      default    = bool
      cidr_block = string
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
  validation {
    error_message = "Only one default VPC allowed per region"
    condition = alltrue([
      for region, vpcs in {
        for vpc_name, vpc_values in var.vpcs :
        vpc_values.region => vpc_name... if vpc_values.default
      } :
    length(vpcs) < 2])
  }
  validation {
    error_message = "Only one default subnet allowed per public or private vpc"
    condition = alltrue([
      for defaults, subnets in merge([
        for vpc_name, vpc_values in var.vpcs : {
          for subnet_key, subnet_values in vpc_values.subnets :
          "${vpc_name}.${subnet_values.public ? "public" : "private"}_default" => subnet_key... if subnet_values.default
        }
      ]...) :
      length(subnets) < 2
    ])
  }
  validation {
    error_message = "vpc_cidr must be a valid cidr block"
    condition = alltrue([
      for vpc_name, vpc_values in var.vpcs :
      can(cidrhost(vpc_values.vpc_cidr, 0))
    ])
  }
  validation {
    error_message = "All subnets must be a valid cidr block"
    condition = alltrue(flatten([
      for vpc_name, vpc_values in var.vpcs :
      [
        for subnet_name, subnet_values in vpc_values.subnets :
        can(cidrhost(subnet_values.cidr_block, 0))
      ]
    ]))
  }
}

variable "hosted_zone_name" {
  description = "The name of a hosted zone domain you own in route53"
  default     = null
}
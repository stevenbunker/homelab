variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
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
    "management",
  "test"]
}

variable "organizational_units" {
  description = "(Optional) organizational units to place organizational accounts in."
  type        = map(list(string))
  default = {
    security = [
      "security_tooling",
      "security_logs",
    ]
    infrastructure = [
      "network",
      "shared-services",
    ]
  }
}

variable "organizational_accounts" {
  type = map(string)
  default = {
    network         = null,
    shared-services = null,
    # security_tooling = null,
    # security_logs = null,
    # workloads
  }
  validation {
    condition = alltrue([
      for account_name, email in var.organizational_accounts :
      # If the email is null, the account admin email must be a gmail address.
      # If the provided email is not of a valid structure, AWS will handle the error
      email == null ? can(regex("[^@]+@gmail\\.com", var.admin_email)) : true
    ])
    error_message = "Either the account admin ${var.admin_email} must be a gmail, or the map of accounts must contain a valid email."
  }
  description = <<EOT
  Organizational unit account 'friendly names' for this management account

  These names will be appended to the end of the root account name, with a hypthen.
  If no account email is specified the default admin user email will be appended if "+this name", if the admin email is a gmail account.
  EOT
}

variable "admin_email" {
  type        = string
  description = "The email account for the root admin"
}

variable "admin_name" {
  type        = string
  description = "Admin prefered first and last name"
  validation {
    condition = can(regex(
      "[a-zA-Z\\.]+[[:space:]]{1}[a-zA-Z\\.]+", var.admin_name
    ))
    error_message = "admin_name must be 'First name' 'space' 'Last Name'. It can only contain letters or a period"
  }
}

variable "organization_name" {
  description = "Name of the organization to use as the root account alias"
  type        = string
}
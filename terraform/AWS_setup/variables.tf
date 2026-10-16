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
    organization    = null,
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

variable "service_access_principals" {
  type        = set(string)
  description = "AWS service access principals that will be enabled for the organization"
  default     = null
}

variable "delegated_administration" {
  type        = map(string)
  description = <<EOT
  A map of services to delegate, and the friendly account name defined in var.organizational_accounts.
  Example:
  {
    "sso.amazonaws.com" = "shared-services"
  }
  EOT
  default     = null
  validation {
    condition = var.delegated_administration == null ? true : alltrue([
      for service in keys(var.delegated_administration) :
      contains(var.service_access_principals, service)
    ])
    error_message = "For the service to be delegated, it must be enabled via the 'service_access_principals' variable"
  }
  validation {
    condition = var.delegated_administration == null ? true : alltrue([
      for account in values(var.delegated_administration) :
      contains(keys(var.organizational_accounts), account)
    ])
    error_message = "The account is not an organization account."
  }
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

variable "required_child_sets_and_managed_policies" {
  description = <<EOT
  A map of permission sets for all accounts in org account. The default is to make administrator access and Terraform execute in each account.
  
  Set values must be the name of managed policies in the org account
  EOT
  type        = map(set(string))
  default = {
    AdministratorAccess = [
      "AdministratorAccess"
    ]
    TerraformExecute = [
      "ReadOnlyAccess",
      "AWSBudgetsActionsWithAWSResourceControlAccess"
    ]
    ReadOnly = [
      "ReadOnlyAccess"
    ]
  }
  validation {
    condition     = contains(keys(var.required_child_sets_and_managed_policies), "AdministratorAccess")
    error_message = "Although you can customize the required policy sets, you will need one called 'AdministratorAccess'"
  }
}

variable "sso_start_url" {
  description = "Your SSO start URL"
}
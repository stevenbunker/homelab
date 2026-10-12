provider "aws" {
  tag_policy_compliance = "error"
  default_tags {
    tags = {
      managedBy   = "terraform"
      Environment = local.environment
    }
  }
}

provider "aws" {
  alias = "stackset_delegate"
  profile = can(
    var.delegated_administration["member.org.stacksets.cloudformation.amazonaws.com"]
  ) ? "AdministratorAccess-${var.delegated_administration["member.org.stacksets.cloudformation.amazonaws.com"]}" : "default"
  tag_policy_compliance = "error"
  default_tags {
    tags = {
      managedBy   = "terraform"
      Environment = local.environment
    }
  }
}
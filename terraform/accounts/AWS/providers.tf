provider "aws" {
  tag_policy_compliance = "error"
  region                = var.region
  default_tags {
    tags = {
      managedBy   = "terraform"
      Environment = local.environment
    }
  }
}
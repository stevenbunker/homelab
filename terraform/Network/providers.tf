provider "aws" {
  tag_policy_compliance = "error"
  profile               = "terraform"
  region                = var.region
  default_tags {
    tags = {
      managedBy = "terraform"
    region = var.region }
  }
}
provider "aws" {
  tag_policy_compliance = "error"
  profile               = "TerraformExecute.network"
  region                = var.region
  default_tags {
    tags = {
      managedBy = "terraform"
    region = var.region }
  }
}

provider "aws" {
  alias   = "org_readonly"
  profile = "ReadOnly.organization"
  region  = var.region
}

provider "aws" {
  alias                 = "shared-services"
  tag_policy_compliance = "error"
  profile               = "TerraformExecute.shared-services"
  region                = var.region
  default_tags {
    tags = {
      managedBy = "terraform"
    region = var.region }
  }
}

provider "aws" {
  alias                 = "network"
  tag_policy_compliance = "error"
  profile               = "TerraformExecute.network"
  region                = var.region
  default_tags {
    tags = {
      managedBy = "terraform"
    region = var.region }
  }
}
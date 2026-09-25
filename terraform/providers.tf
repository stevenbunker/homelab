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

provider "aws" {
  tag_policy_compliance = "error"
  alias                 = "west"
  profile               = "terraform"
  region                = "us-west-1"
  default_tags {
    tags = {
      managedBy = "terraform"
    region = "us-west-1" }
  }
}

provider "aws" {
  tag_policy_compliance = "error"
  alias                 = "east"
  profile               = "terraform"
  region                = "us-east-1"
  default_tags {
    tags = {
      managedBy = "terraform"
    region = "us-east-1" }
  }
}
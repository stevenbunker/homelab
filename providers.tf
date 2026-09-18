provider "aws" {
  profile = "terraform"
  region  = var.region
  default_tags {
    tags = merge(
      var.project_tags,
      { managedBy = "terraform" }
    )
  }
}

provider "aws" {
  alias   = "west"
  profile = "terraform"
  region  = "us-west-1"
  default_tags {
    tags = merge(
      var.project_tags,
      { managedBy = "terraform" }
    )
  }
}
terraform {
  required_version = ">= v1.16.2"
  required_providers {
    aws = {
      version = "~> 6.0"
      source  = "hashicorp/aws"
    }
    local = {
      source = "hashicorp/local"
      # Setting the provider version is a strongly recommended practice
      # version = "..."
    }
  }
}

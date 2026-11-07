terraform {
  required_version = ">= v1.16.2"
  required_providers {
    aws = {
      version = "~> 6.0"
      source  = "hashicorp/aws"
    }
  }
}
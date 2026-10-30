data "aws_subnet" "public" {
  id = var.public_subnet_id

  lifecycle {
    postcondition {
      condition     = self.vpc_id == data.aws_vpc.this.id
      error_message = "The provided subnet id is not in the provided VPC id"
    }
  }
}

data "aws_subnet" "private" {
  id = var.private_subnet_id

  lifecycle {
    postcondition {
      condition     = self.vpc_id == data.aws_vpc.this.id
      error_message = "The provided subnet id is not in the provided VPC id"
    }
  }
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

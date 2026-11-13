data "aws_subnet" "this" {
  id = var.subnet_id

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
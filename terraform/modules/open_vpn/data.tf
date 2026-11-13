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

data "aws_route_table" "this" {
  subnet_id = var.subnet_id
}

# Get the current record from  Route53
data "aws_route53_records" "this" {
  zone_id    = data.aws_route53_zone.this.zone_id
  name_regex = local.Route53RecordName
}
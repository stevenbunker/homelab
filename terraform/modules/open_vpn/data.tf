data "aws_ami" "this" { /*
This relies on a snapshot of a valid VPN
TODO: use a generic ubuntu AMI and do the setup with ansible
*/
  filter {
    name   = "name"
    values = ["ovpn-copy-ami"]
  }
}

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
  subnet_id = data.aws_subnet.this.id
}

# Get the current record from  Route53
data "aws_route53_records" "this" {
  zone_id    = aws_route53_zone.this.zone_id
  name_regex = "${replace(data.aws_ami.this.region, "-", "")}.${aws_route53_zone.this.name}"
}
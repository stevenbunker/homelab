module "ovpn" {
  source = "${local.modules_path}/open_vpn"
  providers = {
    aws = aws.network
  }

  hosted_zone_name = var.hosted_zone_name
  vpc_id           = aws_vpc.main[local.default_vpc.name].id
  subnet_id        = aws_subnet.main[local.default_public_subnet.name].id
}
locals {
  modules_path           = "${path.root}/../modules"
  environment            = "prod"
  default_vpc_key        = "${var.region}_default_${local.environment}"
  default_vpc            = aws_vpc.main[local.default_vpc_key]
  default_public_subnet  = [for subnet in aws_subnet.main : subnet if subnet.vpc_id == local.default_vpc.id && subnet.tags.is_public][0]
  default_private_subnet = [for subnet in aws_subnet.main : subnet if subnet.vpc_id == local.default_vpc.id && !subnet.tags.is_public][0]
}

module "ovpn" {
  source = "../modules/open_vpn"
  providers = {
    aws = aws.network
  }

  hosted_zone_name = var.hosted_zone_name
  vpc_id           = local.default_vpc.id
  subnet_id        = local.default_public_subnet.id
  environment      = local.environment

  depends_on = [aws_subnet.main, aws_route_table.public, aws_vpc.main]
  region     = var.region
}

resource "aws_network_interface_sg_attachment" "ovpn_intravpc" {
  network_interface_id = module.ovpn.open_vpn.open_vpn_network_interface_id
  security_group_id    = aws_security_group.intra_vpc[local.default_vpc_key].id
}
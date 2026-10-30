locals {
  modules_path = "${path.root}/../modules"
  environment  = "prod"
}

module "ovpn" {
  source = "../modules/open_vpn"
  providers = {
    aws = aws.network
  }

  hosted_zone_name = var.hosted_zone_name
  vpc_id           = aws_vpc.main[local.default_vpc.name].id
  subnet_id        = aws_subnet.main[local.default_public_subnet.name].id

  depends_on = [aws_subnet.main, aws_route_table.public]
}

resource "aws_network_interface_sg_attachment" "ovpn_intravpc" {
  network_interface_id = module.ovpn.open_vpn.open_vpn_network_interface_id
  security_group_id    = aws_security_group.intra_vpc.id
}

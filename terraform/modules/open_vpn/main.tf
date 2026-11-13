locals {
  Project           = "ovpn"
  Route53RecordName = "${replace(var.region, "-", "")}.${var.hosted_zone_name}"
}

data "aws_ami" "vpn" {

  filter {
    name   = "name"
    values = ["open-vpn"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_route53_zone" "this" {
  name         = var.hosted_zone_name
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.vpn.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  source_dest_check           = false
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required"
  }

  lifecycle {
    ignore_changes = [
      associate_public_ip_address,
      vpc_security_group_ids
    ]
  }

  tags = {
    Route53HostedZoneId = data.aws_route53_zone.this.zone_id,
    Route53RecordName   = local.Route53RecordName
    Project             = local.Project
    Environment         = var.environment
    OS_version          = "ubuntu-24.04"
    is_public           = data.aws_subnet.this.tags.is_public
  }
}


resource "aws_security_group" "this" {
  name        = "Open_VPN_SG"
  vpc_id      = var.vpc_id
  description = "Security group for Open VPN instance"
  tags = {
    Project     = local.Project
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_anywhere" {
  security_group_id = aws_security_group.this.id
  description       = "Allow HTTPS from anywhere"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "allow_udp_1194" {
  security_group_id = aws_security_group.this.id
  description       = "Allow OVPN on UDP 1194"
  ip_protocol       = "udp"
  from_port         = 1194
  to_port           = 1194
  cidr_ipv4         = "136.32.0.0/11"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.this.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_route" "this" {
  route_table_id         = data.aws_route_table.this.id
  destination_cidr_block = var.ovpn_cidr
  network_interface_id   = aws_instance.this.primary_network_interface_id

  lifecycle {
    ignore_changes = [route_table_id]
  }
}

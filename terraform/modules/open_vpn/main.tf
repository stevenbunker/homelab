locals {
  Project = "ovpn"
}

resource "aws_route53_zone" "this" {
  name = var.hosted_zone_name
  tags = {
    Project     = local.Project
    Environment = var.Environment
  }
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.this.id
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
    Route53HostedZoneId = aws_route53_zone.this.zone_id,
    Route53RecordName   = "${replace(data.aws_ami.this.region, "-", "")}.${aws_route53_zone.this.name}"
    Project             = local.Project
    Environment         = var.Environment
    OS_version          = data.aws_ami.this.tags.OS_version
    is_public           = data.aws_subnet.this.tags.is_public
  }
}


resource "aws_security_group" "this" {
  name        = "Open_VPN_SG"
  vpc_id      = var.vpc_id
  description = "Security group for Open VPN instance"
  tags = {
    Project     = local.Project
    Environment = var.Environment
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

resource "aws_route53_record" "this" {

  zone_id = aws_instance.this.tags.Route53HostedZoneId
  name    = aws_instance.this.tags.Route53RecordName
  type    = "A"
  ttl     = "300"
  records = (aws_instance.this.public_ip != "" ?
    [aws_instance.this.public_ip, ] :
    # if the instance is stopped, it will not have a public IP, instead we'll keep the existing A record value
    # TODO: update the lambda that tracks state to remove the A record when the state becomes stopped
  [for record in data.aws_route53_records.this.resource_record_sets[0].resource_records : record.value])
}

resource "aws_route" "this" {
  route_table_id         = data.aws_route_table.this.id
  destination_cidr_block = var.ovpn_cidr
  network_interface_id   = aws_instance.this.primary_network_interface_id
}

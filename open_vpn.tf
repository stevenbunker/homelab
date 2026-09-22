data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-20260421"]
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

resource "aws_instance" "ovpn" {
  ami               = data.aws_ami.ubuntu.id
  instance_type     = var.instance_type
  source_dest_check = false
  vpc_security_group_ids = [aws_security_group.ovpn.id]
  tags = {
    Route53HostedZoneId = var.hosted_zone,
    Route53RecordName   = var.record_name
    Project             = "ovpn"
    Environment         = "prod"
  }
}

resource "aws_network_interface" "ovpn" {
  subnet_id         = aws_subnet.public1.id
  description       = "Open VPN network interface"
  security_groups   = [aws_security_group.ovpn.id]
  source_dest_check = false
  tags = {
    Project     = "ovpn"
    Environment = "prod"
  }

  attachment {
    instance     = aws_instance.ovpn.id
    device_index = 0
  }
}

resource "aws_security_group" "ovpn" {
  vpc_id      = aws_vpc.main.id
  description = "Security group for Open VPN instance"
  tags = {
    Project     = "ovpn"
    Environment = "prod"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ingress_rules" {
  for_each                     = local.ingress_rules
  security_group_id            = aws_security_group.ovpn.id
  description                  = try(each.value.description, null)
  ip_protocol                  = try(each.value.ip_protocol, "tcp")
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  cidr_ipv4                    = try(each.value.cidr_ipv4, null)
  referenced_security_group_id = try(each.value.source_sg_id, null)
}

resource "aws_vpc_security_group_egress_rule" "egress_rules" {
  for_each = {
    for k, v in local.egress_rules : k => v
    if contains(["allow_all_outbound", ], k)
  }
  security_group_id            = aws_security_group.ovpn.id
  description                  = try(each.value.description, null)
  ip_protocol                  = try(each.value.ip_protocol, "tcp")
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  cidr_ipv4                    = try(each.value.cidr_ipv4, null)
  referenced_security_group_id = try(each.value.dest_sg_id, null)
}
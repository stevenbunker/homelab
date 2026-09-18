resource "aws_security_group" "ovpn_security_group" {
  vpc_id   = var.main_vpc_id
  description = "launch-wizard-2 created 2026-06-07T17:52:11.223Z"
  tags = var.project_tags
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  description = "Allow HTTPS"
  security_group_id = aws_security_group.ovpn_security_group.id
  ip_protocol = "tcp"
  from_port = 443
  to_port = 443
  cidr_ipv4 = "0.0.0.0/0"
  tags = var.project_tags
}

resource "aws_vpc_security_group_ingress_rule" "allow_udp_1194" {
  description = "Allow OVPN on UDP 1194"
  security_group_id = aws_security_group.ovpn_security_group.id
  ip_protocol = "udp"
  from_port = 1194
  to_port = 1194
  cidr_ipv4 = "0.0.0.0/0"
  tags = var.project_tags
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  description = "Allow limited SSH"
  security_group_id = aws_security_group.ovpn_security_group.id
  ip_protocol = "tcp"
  from_port = 22
  to_port = 22
  cidr_ipv4 = var.ssh_ip_allowed
  tags = var.project_tags
}

resource "aws_network_interface" "ovpn_eni" {
  subnet_id       = var.main_public_subnet_id
  description     = "Open VPN network interface"
  security_groups = [aws_security_group.ovpn_security_group.id]
  source_dest_check = false
  tags = var.project_tags

  attachment {
    instance     = aws_instance.ovpn_instance.id
    device_index = 0
  }
}
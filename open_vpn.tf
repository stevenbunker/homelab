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

resource "aws_instance" "ovpn_instance" {
  ami = data.aws_ami.ubuntu.id
  instance_type     = var.instance_type
  source_dest_check = false
  tags = {
      Route53HostedZoneId = var.hosted_zone,
      Route53RecordName = var.record_name
      Project = "ovpn"
      Environment = "prod"
    }
}

resource "aws_network_interface" "ovpn_eni" {
  subnet_id       = aws_subnet.public1.id
  description     = "Open VPN network interface"
  security_groups = [aws_security_group.ovpn_security_group.id]
  source_dest_check = false
  tags = {
    Project = "ovpn"
    Environment = "prod"
  }

  attachment {
    instance     = aws_instance.ovpn_instance.id
    device_index = 0
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  description = "Allow HTTPS"
  security_group_id = aws_security_group.ovpn_security_group.id
  ip_protocol = "tcp"
  from_port = 443
  to_port = 443
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "allow_udp_1194" {
  description = "Allow OVPN on UDP 1194"
  security_group_id = aws_security_group.ovpn_security_group.id
  ip_protocol = "udp"
  from_port = 1194
  to_port = 1194
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  description = "Allow limited SSH"
  security_group_id = aws_security_group.ovpn_security_group.id
  ip_protocol = "tcp"
  from_port = 22
  to_port = 22
  cidr_ipv4 = var.ssh_ip_allowed
}

resource "aws_security_group" "ovpn_security_group" {
  vpc_id   = aws_vpc.main.id
  description = "launch-wizard-2 created 2026-06-07T17:52:11.223Z"
  tags = {
    Project = "ovpn"
    Environment = "prod"
  }
}
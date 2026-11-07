data "aws_availability_zones" "available" {
  for_each = toset([
    for vpc_key, vpc in var.vpcs : vpc.region
  ])
  region = each.key
  state  = "available"
}

locals {
  default_vpc = one([
    for vpc_key, vpc in var.vpcs : {
      name       = vpc_key
      vpc_config = vpc
    } if vpc.default
    && vpc.region == var.region
  ])
  subnets = tomap({
    for subnet in flatten([
      for vpc_key, vpc in var.vpcs : [
        for az in data.aws_availability_zones.available[vpc.region].names : [
          for index, subnet_config in vpc.subnets : {
            vpc_key       = vpc_key
            vpc_region    = vpc.region
            index         = index
            vpc_id        = aws_vpc.main[vpc_key].id
            subnet_config = subnet_config
            cidr = cidrsubnet(
              cidrsubnet(
                vpc.vpc_cidr,
                8,
                index
              ),
              ceil(
                pow(
                  length(data.aws_availability_zones.available[vpc.region].names) - 1,
                  0.5
              )),
              index(data.aws_availability_zones.available[vpc.region].names, az)
            )
            az = az
          }
        ]
      ]
    ]) : "${subnet.vpc_key}.${subnet.index}.${subnet.az}" => subnet
  })
  default_public_subnet = one([
    for subnet_key, subnet in local.default_vpc.vpc_config.subnets : {
      name          = "${local.default_vpc.name}.${subnet_key}.${data.aws_availability_zones.available[var.region].names[0]}"
      subnet_config = subnet
    } if subnet.default
    && subnet.public
  ])
  default_private_subnet = one([
    for subnet_key, subnet in local.default_vpc.vpc_config.subnets : {
      name          = "${local.default_vpc.name}.${subnet_key}.${data.aws_availability_zones.available[var.region].names[0]}"
      subnet_config = subnet
    } if subnet.default
    && !subnet.public
  ])
}

resource "aws_vpc" "main" {
  for_each   = var.vpcs
  cidr_block = each.value.vpc_cidr
  region     = each.value.region
  tags = {
    Name        = each.key
    Project     = "network"
    Environment = local.environment
    region      = each.value.region
  }
}

resource "aws_internet_gateway" "main" {
  for_each = {
    for vpc_key, vpc in var.vpcs : vpc_key => vpc
    if anytrue([
      for subnet in vpc.subnets : subnet.public
    ])
  }
  vpc_id = aws_vpc.main[each.key].id
  region = each.value.region
  tags = {
    Project     = "network"
    Environment = local.environment
    region      = each.value.region
    Name        = "${each.key}_igw"
  }
}

resource "aws_egress_only_internet_gateway" "main" {
  for_each = var.vpcs
  vpc_id   = aws_vpc.main[each.key].id
  region   = each.value.region
  tags = {
    Project     = "network"
    Environment = local.environment
    region      = each.value.region
    Name        = "${each.key}_egress-only-igw"
  }
}

resource "aws_subnet" "main" {
  for_each                = local.subnets
  vpc_id                  = each.value.vpc_id
  region                  = each.value.vpc_region
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = each.value.subnet_config.public
  availability_zone       = each.value.az
  tags = {
    Name        = "${each.value.subnet_config.public ? "public" : "private"}.${each.value.az}"
    Project     = "network"
    Environment = local.environment
    is_public   = each.value.subnet_config.public
    region      = each.value.vpc_region
  }
}

# ----
# Resources for public subnet
# ----

resource "aws_network_acl" "public" {
  for_each = var.vpcs
  region   = each.value.region
  vpc_id   = aws_vpc.main[each.key].id

  tags = {
    Name = "${each.key}_public"
  }
}

resource "aws_network_acl_rule" "egress_all" {
  for_each        = aws_network_acl.public
  region          = each.value.region
  network_acl_id  = each.value.id
  rule_number     = 100
  egress          = true
  protocol        = -1
  rule_action     = "allow"
  cidr_block = "0.0.0.0/0"
}

resource "aws_network_acl_rule" "udp_1194" {
  for_each        = aws_network_acl.public
  region          = each.value.region
  network_acl_id  = each.value.id
  rule_number     = 100
  egress          = false
  protocol        = "udp"
  rule_action     = "allow"
  cidr_block = "0.0.0.0/0"
  from_port       = 1194
  to_port         = 1194
}

resource "aws_network_acl_rule" "tcp_443" {
  for_each        = aws_network_acl.public
  region          = each.value.region
  network_acl_id  = each.value.id
  rule_number     = 150
  egress          = false
  protocol        = "tcp"
  rule_action     = "allow"
  cidr_block = "0.0.0.0/0"
  from_port       = 443
  to_port         = 443
}

resource "aws_network_acl_rule" "tcp_ephemeral" {
  for_each        = aws_network_acl.public
  region          = each.value.region
  network_acl_id  = each.value.id
  rule_number     = 200
  egress          = false
  protocol        = "tcp"
  rule_action     = "allow"
  cidr_block = "0.0.0.0/0"
  from_port       = 1024
  to_port         = 65535
}

resource "aws_network_acl_rule" "udp_ephemeral" {
  for_each        = aws_network_acl.public
  region          = each.value.region
  network_acl_id  = each.value.id
  rule_number     = 250
  egress          = false
  protocol        = "udp"
  rule_action     = "allow"
  cidr_block = "0.0.0.0/0"
  from_port       = 1024
  to_port         = 65535
}

resource "aws_network_acl_association" "public" {
  for_each       = { for subnet_key, subnet in local.subnets : subnet_key => subnet if subnet.subnet_config.public }
  region         = each.value.vpc_region
  network_acl_id = aws_network_acl.public[each.value.vpc_key].id
  subnet_id      = aws_subnet.main[each.key].id
}

resource "aws_route_table" "public" {
  for_each = {
    for subnet in flatten([
      for vpc_key, vpc in var.vpcs : [
        for subnet_config in vpc.subnets : {
          vpc_key       = vpc_key
          vpc_region    = vpc.region
          subnet_config = subnet_config
        }
      ]
    ]) : subnet.vpc_key => subnet if subnet.subnet_config.public
  }
  vpc_id = aws_vpc.main[each.value.vpc_key].id
  region = each.value.vpc_region
  tags = {
    Project     = "network"
    Environment = local.environment
    region      = each.value.vpc_region
    Name        = "${each.value.vpc_region}_public_routes"
  }
}

resource "aws_main_route_table_association" "main" {
  for_each         = aws_vpc.main
  region = each.value.region
  vpc_id         = each.value.id
  route_table_id = lookup(aws_route_table.public, each.key, null) != null ? aws_route_table.public[each.key].id : aws_route_table.private[each.key].id
}

resource "aws_route_table_association" "public" {
  for_each       = { for subnet_key, subnet in local.subnets : subnet_key => subnet if subnet.subnet_config.public }
  region         = each.value.vpc_region
  subnet_id      = aws_subnet.main[each.key].id
  route_table_id = aws_route_table.public[each.value.vpc_key].id
}

resource "aws_route" "igw" {
  for_each               = aws_route_table.public
  region                 = each.value.region
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[each.key].id
}

# ----
# Resources for default private subnet
# ----

resource "aws_network_acl" "private" {
  for_each = var.vpcs
  region   = each.value.region
  vpc_id   = aws_vpc.main[each.key].id

  tags = {
    Name = "${each.key}_private"
  }
}

resource "aws_network_acl_rule" "ipv6_egress_all" {
  for_each        = aws_network_acl.private
  region          = each.value.region
  network_acl_id  = each.value.id
  rule_number     = 100
  egress          = true
  protocol        = -1
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
}

resource "aws_network_acl_rule" "ipv6_ingress_tcp_ephemeral" {
  for_each        = aws_network_acl.private
  region          = each.value.region
  network_acl_id  = each.value.id
  rule_number     = 200
  egress          = false
  protocol        = "tcp"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 1024
  to_port         = 65535
}

resource "aws_network_acl_rule" "ipv6_ingress_udp_ephemeral" {
  for_each        = aws_network_acl.private
  region          = each.value.region
  network_acl_id  = each.value.id
  rule_number     = 300
  egress          = false
  protocol        = "udp"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 1024
  to_port         = 65535
}

resource "aws_network_acl_association" "private" {
  for_each       = { for subnet_key, subnet in local.subnets : subnet_key => subnet if !subnet.subnet_config.public }
  region         = each.value.vpc_region
  network_acl_id = aws_network_acl.private[each.value.vpc_key].id
  subnet_id      = aws_subnet.main[each.key].id
}

resource "aws_route_table" "private" {
  for_each = {
    for subnet in flatten([
      for vpc_key, vpc in var.vpcs : [
        for subnet_config in vpc.subnets : {
          vpc_key       = vpc_key
          vpc_region    = vpc.region
          subnet_config = subnet_config
        }
      ]
    ]) : subnet.vpc_key => subnet if !subnet.subnet_config.public
  }
  vpc_id = aws_vpc.main[each.value.vpc_key].id
  region = each.value.vpc_region
  tags = {
    Project     = "network"
    Environment = local.environment
    region      = each.value.vpc_region
    Name        = "${each.value.vpc_region}_private_routes"
  }
}

resource "aws_route_table_association" "private" {
  for_each       = { for subnet_key, subnet in local.subnets : subnet_key => subnet if !subnet.subnet_config.public }
  region         = each.value.vpc_region
  subnet_id      = aws_subnet.main[each.key].id
  route_table_id = aws_route_table.private[each.value.vpc_key].id

  depends_on = [aws_subnet.main]
}

resource "aws_route" "egress_only_igw" {
  for_each                    = aws_route_table.private
  region                      = each.value.region
  route_table_id              = each.value.id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.main[each.key].id
}


# ----
# Share default resources with the organizaiton
# ----

resource "aws_security_group" "intra_vpc" {
  for_each    = var.vpcs
  region      = each.value.region
  name        = "intra-vpc"
  description = "Allow intra-VPC ingress and egress"
  vpc_id      = aws_vpc.main[each.key].id

  tags = {
    Project     = "network"
    Environment = local.environment
    region      = each.value.region
  }
}

resource "aws_vpc_security_group_ingress_rule" "intra_vpc_self" {
  for_each                     = aws_security_group.intra_vpc
  region                       = each.value.region
  description                  = "Self-ingress, all protocols"
  security_group_id            = each.value.id
  referenced_security_group_id = each.value.id
  ip_protocol                  = "-1"
  tags = {
    Project     = "network"
    Environment = local.environment
    region      = each.value.region
    Name        = "IntraVPC_ingress"
  }
}

resource "aws_vpc_security_group_egress_rule" "intra_vpc_self" {
  for_each                     = aws_security_group.intra_vpc
  region                       = each.value.region
  description                  = "Allow self egress"
  security_group_id            = each.value.id
  referenced_security_group_id = each.value.id
  ip_protocol                  = "-1"
  tags = {
    Project     = "network"
    Environment = local.environment
    region      = each.value.region
    Name        = "IntraVPC_egress"
  }
}

resource "aws_security_group" "all_egress" {
  for_each    = var.vpcs
  region      = each.value.region
  name        = "all_egress"
  description = "Allow intra-VPC ingress and egress"
  vpc_id      = aws_vpc.main[each.key].id

  tags = {
    Project     = "network"
    Environment = local.environment
    region      = each.value.region
    Name        = "IntraVPC_egress"
  }
}

resource "aws_vpc_security_group_egress_rule" "all_egress" {
  for_each          = aws_security_group.all_egress
  region            = each.value.region
  description       = "Allow all egress"
  security_group_id = each.value.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = {
    Project     = "network"
    Environment = local.environment
    region      = each.value.region
    Name        = "all_egress"
  }
}

resource "aws_ram_resource_share" "subnets" {
  for_each = toset([
    for vpc_key, vpc in var.vpcs : vpc.region
  ])
  region                    = each.key
  name                      = "subnets_org_share_${each.key}"
  allow_external_principals = false
  tags = {
    Project     = "network"
    Environment = local.environment
  }
}

resource "aws_ram_resource_association" "subnets" {
  for_each           = aws_subnet.main
  resource_arn       = each.value.arn
  resource_share_arn = aws_ram_resource_share.subnets[each.value.region].arn
  region             = each.value.region
}


resource "aws_ram_principal_association" "subnets" {
  for_each           = aws_ram_resource_share.subnets
  principal          = data.aws_organizations_organization.current.arn
  resource_share_arn = each.value.arn
  region             = each.value.region
}

data "aws_availability_zones" "available" {
  state = "available"
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
        for az in data.aws_availability_zones.available.names : [
          for subnet_key, subnet_config in vpc.subnets : {
            vpc_key       = vpc_key
            subnet_key    = subnet_key
            vpc_id        = aws_vpc.main[vpc_key].id
            subnet_config = subnet_config
            cidr = cidrsubnet(
              subnet_config.cidr_block,
              ceil(
                pow(
                  length(data.aws_availability_zones.available.names) - 1,
                  0.5
              )),
              index(data.aws_availability_zones.available.names, az)
            )
            az = az
          }
        ]
      ]
    ]) : "${subnet.vpc_key}.${subnet.subnet_key}.${subnet.az}" => subnet
  })
  default_public_subnet = one([
    for subnet_key, subnet in local.default_vpc.vpc_config.subnets : {
      name          = "${local.default_vpc.name}.${subnet_key}.${data.aws_availability_zones.available.names[0]}"
      subnet_config = subnet
    } if subnet.default
    && subnet.public
  ])
  default_private_subnet = one([
    for subnet_key, subnet in local.default_vpc.vpc_config.subnets : {
      name          = "${local.default_vpc.name}.${subnet_key}.${data.aws_availability_zones.available.names[0]}"
      subnet_config = subnet
    } if subnet.default
    && !subnet.public
  ])
}

resource "aws_vpc" "main" {
  for_each   = var.vpcs
  cidr_block = each.value.vpc_cidr
  tags = {
    Project     = "network"
    Environment = local.environment
  }
}

resource "aws_internet_gateway" "main" {
  for_each = { for vpc_key, vpc in var.vpcs : vpc_key => vpc if vpc.internet_gateway }
  vpc_id   = lookup(aws_vpc.main, each.key).id
  tags = {
    Project     = "network"
    Environment = local.environment
  }
}

resource "aws_subnet" "main" {
  for_each                = local.subnets
  vpc_id                  = each.value.vpc_id
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = each.value.subnet_config.public
  availability_zone       = each.value.az
  tags = {
    Project     = "network"
    Environment = local.environment
    is_public   = each.value.subnet_config.public
  }
}

# ----
# Resources for public subnet
# ----

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main[local.default_vpc.name].id
  tags = {
    Project     = "network"
    Environment = local.environment
  }
}

resource "aws_route_table_association" "public" {
  for_each       = { for subnet_key, subnet in local.subnets : subnet_key => subnet if subnet.subnet_config.public }
  subnet_id      = aws_subnet.main[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route" "igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[local.default_vpc.name].id
}

# ----
# Resources for default private subnet
# ----

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main[local.default_vpc.name].id
  tags = {
    Project     = "network"
    Environment = local.environment
  }
}

resource "aws_route_table_association" "private" {
  for_each       = { for subnet_key, subnet in local.subnets : subnet_key => subnet if !subnet.subnet_config.public }
  subnet_id      = aws_subnet.main[each.key].id
  route_table_id = aws_route_table.private.id
}


# ----
# Share default resources with the organizaiton
# ----

resource "aws_security_group" "intra_vpc" {
  name        = "intra-vpc"
  description = "Allow intra-VPC ingress and egress"
  vpc_id      = aws_vpc.main[local.default_vpc.name].id

  tags = {
    Project     = "network"
    Environment = local.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "intra_vpc_self" {
  description                  = "Self-ingress, all protocols"
  security_group_id            = aws_security_group.intra_vpc.id
  referenced_security_group_id = aws_security_group.intra_vpc.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "intra_vpc_self" {
  description                  = "Allow self egress"
  security_group_id            = aws_security_group.intra_vpc.id
  referenced_security_group_id = aws_security_group.intra_vpc.id
  ip_protocol                  = "-1"
}

resource "aws_security_group" "all_egress" {
  name        = "intra-vpc"
  description = "Allow intra-VPC ingress and egress"
  vpc_id      = aws_vpc.main[local.default_vpc.name].id

  tags = {
    Project     = "network"
    Environment = local.environment
  }
}

resource "aws_vpc_security_group_egress_rule" "all_egress" {
  description       = "Allow all egress"
  security_group_id = aws_security_group.all_egress.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_ram_resource_share" "subnets" {
  name                      = "subnets_org_chare_share"
  allow_external_principals = false
  tags = {
    Project     = "network"
    Environment = local.environment
  }
}

resource "aws_ram_resource_association" "subnets" {
  for_each           = aws_subnet.main
  resource_arn       = each.value.arn
  resource_share_arn = aws_ram_resource_share.subnets.arn
}


resource "aws_ram_principal_association" "subnets" {
  principal          = data.aws_organizations_organization.current.arn
  resource_share_arn = aws_ram_resource_share.subnets.arn
}

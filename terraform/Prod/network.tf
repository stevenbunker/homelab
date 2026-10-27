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
  for_each = tomap({
    for subnet in flatten([
      for vpc_key, vpc in var.vpcs : [
        for subnet_key, subnet in vpc.subnets : {
          vpc_key    = vpc_key
          subnet_key = subnet_key
          vpc_id     = aws_vpc.main[vpc_key].id
          subnet     = subnet
        }
      ]
    ]) : "${subnet.vpc_key}.${subnet.subnet_key}" => subnet
  })

  vpc_id                  = each.value.vpc_id
  cidr_block              = each.value.subnet.cidr_block
  map_public_ip_on_launch = each.value.subnet.public
  tags = {
    Project     = "network"
    Environment = local.environment
    is_public   = each.value.subnet.public
  }
}

resource "aws_route_table" "default_public" {
  vpc_id = aws_vpc.main[local.default_vpc.name].id
  tags = {
    Project     = "network"
    Environment = local.environment
  }
}

resource "aws_route_table_association" "default_public" {
  subnet_id      = aws_subnet.main[local.default_public_subnet.name].id
  route_table_id = aws_route_table.default_public.id
}

resource "aws_route" "igw" {
  route_table_id         = aws_route_table.default_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[local.default_vpc.name].id
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

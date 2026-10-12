resource "aws_vpc" "main" {
  cidr_block = var.aws_vpc_cidr
  tags = {
    Project     = "network"
    Environment = "shared"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Project     = "network"
    Environment = "shared"
  }
}

resource "aws_subnet" "public1" {
  vpc_id = aws_vpc.main.id
  tags = {
    Project     = "network"
    Environment = "shared"
  }
}

resource "aws_route53_zone" "main" {
  name = local.hosted_zone_name
  tags = {
    Project     = "network"
    Environment = "shared"
  }
}
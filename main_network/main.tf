resource "aws_vpc" "main" {
  cidr_block = var.aws_vpc_cidr
  tags = var.project_tags
}

resource "aws_internet_gateway" "main" {
  vpc_id   = aws_vpc.main.id
  tags = var.project_tags
}

resource "aws_subnet" "public1" {
  vpc_id   = aws_vpc.main.id
  tags = var.project_tags
}
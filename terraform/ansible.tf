resource "ansible_group" "aws_regions" {
  for_each = var.aws_regions
  name     = "aws_${each.value}"
}

resource "ansible_group" "aws" {
  name     = "aws"
  children = flatten(
      [for region in ansible_group.aws_regions :
      coalesce(region.children, [])]
  )
}

resource "ansible_group" "environments" {
  for_each = var.environments
  name     = each.value
}

resource "ansible_host" "ovpn" {
  name = aws_instance.ovpn.public_ip
  groups = ["aws_${var.aws_regions[aws_instance.ovpn.region]}",
  aws_instance.ovpn.tags.Environment]
} 
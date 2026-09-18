output "main_vpc_id" {
  description = "The ID of the main VPC"
  value       = aws_vpc.main.id
}

output "main_cidr" {
  description = "The CIDR for the main VPC"
  value = aws_vpc.main.cidr_block
}

output "main_public_subnet" {
  description = "The ID of the public subnet"
  value       = aws_subnet.public1.id
}
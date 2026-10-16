# Output any profile or session congigs that should be added to ~/.aws/config

output "aws_profile" {
  description = "Add the following session and profile to your .aws config:"
  value       = terraform_data.account_permission_set_product.output
}
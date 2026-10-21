data "aws_organizations_organization" "current" {
  provider = aws.org_readonly
}

data "aws_organizations_delegated_administrators" "current" {
  provider          = aws.org_readonly
  for_each          = data.aws_organizations_organization.current.aws_service_access_principals
  service_principal = each.key
}

output "test" {
  value = {
    for service, delegated_account in data.aws_organizations_delegated_administrators.current :
    service => coalesce(delegated_account.delegated_administrators[*].id...)
    if length(delegated_account.delegated_administrators) > 0
  }
}
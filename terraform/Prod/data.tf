data "aws_organizations_organization" "current" {
  provider = aws.org_readonly
}

data "aws_organizations_delegated_administrators" "current" {
  provider = aws.org_readonly
}

data "aws_organizations_delegated_services" "current" {
  provider = aws.org_readonly
  for_each = toset([
    for delegated_administrator in data.aws_organizations_delegated_administrators.current.delegated_administrators :
    delegated_administrator.id
  ])
  account_id = each.key
}

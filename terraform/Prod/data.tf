locals {
  master_account_name = data.aws_organizations_organization.current.master_account_name
  accountId_to_friendlyName = {
    for account in data.aws_organizations_organization.current.accounts :
    account.id => account.name == local.master_account_name ?
    "organization" :
    replace(account.name, "${local.master_account_name}-", "")
    if account.state == "ACTIVE"
  }
  friendlyName_to_accountId = { for k, v in local.accountId_to_friendlyName : v => k }
  delegated_service_to_delegated_adminId = merge([
    for delegated_account, values in data.aws_organizations_delegated_services.current :
    {
      for service in values.delegated_services :
      service.service_principal => delegated_account
    }
  ]...)
}

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

data "aws_organizations_organizational_units" "current" {
  parent_id = data.aws_organizations_organization.current.roots[0].id
}

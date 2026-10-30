locals {
  master_account_name = data.aws_organizations_organization.current.master_account_name
  friendlyName_to_accountId = {
    for account in data.aws_organizations_organization.current.accounts :
    account.id => account.name == local.master_account_name ?
    "organization" :
    replace(account.name, "${local.master_account_name}-", "")
    if account.state == "ACTIVE"
  }
  accountId_to_friendlyName = { for k, v in local.friendlyName_to_accountId : v => k }
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

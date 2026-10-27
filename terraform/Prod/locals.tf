locals {
  modules_path = "${path.root}/../modules"
  default_vpc = one([
    for vpc_key, vpc in var.vpcs : {
      name       = vpc_key
      vpc_config = vpc
    } if vpc.default
    && vpc.region == var.region
  ])
  default_public_subnet = one([
    for subnet_key, subnet in local.default_vpc.vpc_config.subnets : {
      name          = "${local.default_vpc.name}.${subnet_key}"
      subnet_config = subnet
    } if subnet.default
    && subnet.public
  ])
  environment         = "prod"
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

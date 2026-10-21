locals {
  ingress_rules = merge(
    var.ingress_rules,
    {
      allow_ssh_limited = {
        description = "Allow limited SSH"
        ip_protocol = "tcp"
        from_port   = 22
        to_port     = 22
        cidr_ipv4   = var.ssh_ip_allowed
      },
    }
  )
  egress_rules = merge(
    var.egress_rules,
    {
      from_vpn = {
        description = "Allow all traffice from VPN"
        ip_protocol = -1
        from_port   = -1
        to_port     = -1
        dest_sg_id  = aws_security_group.ovpn.id
      },
    }
  )
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
  service_principal_to_delegated_adminId = {
    for service, delegated_account in data.aws_organizations_delegated_administrators.current :
    service => coalesce(delegated_account.delegated_administrators[*].id...)
    if length(delegated_account.delegated_administrators) > 0
  }
}

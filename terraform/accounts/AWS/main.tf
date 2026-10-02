locals {
  gmail_regex            = "(?P<user>[^@]+)(?P<domain>@gmail\\.com)"
  admin_account_is_gmail = can(regex(local.gmail_regex, var.admin_email))
  split_admin_email      = local.admin_account_is_gmail ? regex("(?P<user>[^@]+)(?P<domain>@.*\\.com)", var.admin_email) : {}
  accounts_to_make = {
    for account, email in var.organizational_accounts :
    account => coalesce(email, "${local.split_admin_email.user}+${account}${local.split_admin_email.domain}")
  }
}

resource "aws_organizations_organization" "my" {
  enabled_policy_types = [
    "TAG_POLICY",
    "SERVICE_CONTROL_POLICY",
    "RESOURCE_CONTROL_POLICY"
  ]
  aws_service_access_principals = [
    "account-access.amazonaws.com",
    "account.amazonaws.com",
    "compute-optimizer.amazonaws.com",
    "cost-optimization-hub.bcm.amazonaws.com",
    "iam.amazonaws.com",
    "notifications.amazonaws.com",
    "sso.amazonaws.com",
  ]
}

resource "aws_organizations_organizational_unit" "units" {
  for_each = { for org, accounts in var.organizational_units :
    org => accounts if length(
      [for account in accounts : account if contains(keys(var.organizational_accounts), account)]
  ) > 0 }
  name      = each.key
  parent_id = aws_organizations_organization.my.roots[0].id
}

resource "aws_organizations_account" "accounts" {
  for_each  = local.accounts_to_make
  name      = "${aws_organizations_organization.my.master_account_name}-${each.key}"
  email     = each.value
  role_name = "${var.organization_name}_OrgRole"
  lifecycle {
    ignore_changes = [role_name]
  }
  parent_id = lookup(
    aws_organizations_organizational_unit.units,
    coalesce([for k, v in var.organizational_units : k if contains(v, each.key)]...),
    aws_organizations_organization.my.roots[0]
  ).id
}

resource "aws_organizations_delegated_administrator" "sso" {
  count             = can(var.organizational_accounts["shared-services"]) ? 1 : 0
  account_id        = aws_organizations_account.accounts["shared-services"].id
  service_principal = "sso.amazonaws.com"
}

resource "aws_organizations_delegated_administrator" "account-access" {
  count             = can(var.organizational_accounts["shared-services"]) ? 1 : 0
  account_id        = aws_organizations_account.accounts["shared-services"].id
  service_principal = "account-access.amazonaws.com"
}
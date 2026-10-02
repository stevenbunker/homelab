data "aws_ssoadmin_instances" "admin" {}

locals {
  identity_store_id = data.aws_ssoadmin_instances.admin.identity_store_ids[0]
  instance_arn      = data.aws_ssoadmin_instances.admin.arns[0]
}

resource "aws_identitystore_user" "admin" {
  identity_store_id = local.identity_store_id

  display_name = "${replace(var.admin_name, " ","")}-SSO"
  user_name    = var.admin_email

  name {
    given_name  = split(" ", var.admin_name)[0]
    family_name = split(" ", var.admin_name)[1]
  }

  emails {
    value = var.admin_email
    primary = true
  }
}

resource "aws_identitystore_group" "admin" {
  display_name      = "administrator-management"
  description       = "The root group for administering child accounts"
  identity_store_id = local.identity_store_id
}

resource "aws_ssoadmin_permission_set" "admin" {
  name         = "AdministratorAccess"
  description  = "The root permission set for administering child accounts"
  instance_arn = local.instance_arn
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  instance_arn       = local.instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
}

resource "aws_ssoadmin_account_assignment" "admin" {
    for_each = toset([for account in aws_organizations_organization.my.accounts : account.id if account.status == "ACTIVE"])
    instance_arn       = local.instance_arn
    permission_set_arn = aws_ssoadmin_permission_set.admin.arn

    principal_id   = aws_identitystore_group.admin.group_id
    principal_type = "GROUP"

    target_id   = each.key
    target_type = "AWS_ACCOUNT"
}
locals {
  templates         = "${path.module}/templates"
  modules_path      = "${path.root}/modules"
  aws_config        = "${pathexpand("~/.aws")}/config"
  environment       = "management"
  identity_store_id = data.aws_ssoadmin_instances.admin.identity_store_ids[0]
  instance_arn      = data.aws_ssoadmin_instances.admin.arns[0]
  split_admin_email_if_gmail = /*
  If the admin email is a gmail account, split the user and domain to later append the user with the friendly name of the account
  */ can(
    regex("(?P<user>[^@]+)(?P<domain>@gmail\\.com)", var.admin_email)
  ) ? regex("(?P<user>[^@]+)(?P<domain>@.*\\.com)", var.admin_email) : {}
}
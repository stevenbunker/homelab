locals {
  identity_store_id = data.aws_ssoadmin_instances.admin.identity_store_ids[0]
  instance_arn      = data.aws_ssoadmin_instances.admin.arns[0]
  accounts          = toset([for account in aws_organizations_organization.my.accounts : account.id if account.status == "ACTIVE"])
  permission_set_policy_assignments = flatten([
    for set_name, policies in var.required_child_sets_and_managed_policies : [
      for policy in policies : {
        set_name    = set_name
        policy_name = policy
      }
    ]
  ])
}


data "aws_ssoadmin_instances" "admin" {}

data "aws_iam_policy" "managed" {
  for_each = toset(flatten(
    [for permission_set, policies in var.required_child_sets_and_managed_policies : policies]
  ))
  name = each.key
}


resource "aws_identitystore_user" "me" {
  identity_store_id = local.identity_store_id

  display_name = "${replace(var.admin_name, " ", "")}-SSO"
  user_name    = var.admin_email

  name {
    given_name  = split(" ", var.admin_name)[0]
    family_name = split(" ", var.admin_name)[1]
  }

  emails {
    value   = var.admin_email
    primary = true
  }
}

resource "aws_identitystore_group" "all" {
  for_each          = var.required_child_sets_and_managed_policies
  display_name      = each.key
  description       = "The group for ${each.key} in child accounts"
  identity_store_id = local.identity_store_id
}

resource "aws_ssoadmin_permission_set" "all" {
  for_each     = var.required_child_sets_and_managed_policies
  name         = each.key
  description  = "The permission set for ${each.key} in child accounts"
  instance_arn = local.instance_arn
}

resource "aws_ssoadmin_managed_policy_attachment" "all" {
  for_each = tomap({
    for assigned_policy in local.permission_set_policy_assignments : "${assigned_policy.set_name}.${assigned_policy.policy_name}" => assigned_policy
  })

  instance_arn       = local.instance_arn
  managed_policy_arn = lookup(data.aws_iam_policy.managed, each.value.policy_name).arn
  permission_set_arn = lookup(aws_ssoadmin_permission_set.all, each.value.set_name).arn
}

resource "aws_iam_policy" "terraform_execute" {
  name = aws_cloudformation_stack_set.automation_execution.parameters["PolicyName"]
  description = "Customer managed Terraform Execute policy. This policy was created by a CloudFormation stack in the management account"
  policy = data.aws_iam_policy_document.automation_execution.json
}

resource "aws_ssoadmin_customer_managed_policy_attachment" "terraform_execute" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.all["TerraformExecute"].arn
  customer_managed_policy_reference {
    name = aws_iam_policy.terraform_execute.name
    path = "/"
  }
}


resource "aws_ssoadmin_account_assignment" "all" {
  for_each = {
    for pair in setproduct(local.accounts, keys(var.required_child_sets_and_managed_policies)) :
    "${pair[0]}.${pair[1]}" => {
      account_key    = pair[0]
      permission_set = pair[1]
    }
  }
  instance_arn       = local.instance_arn
  permission_set_arn = lookup(aws_ssoadmin_permission_set.all, each.value.permission_set).arn

  principal_id   = lookup(aws_identitystore_group.all, each.value.permission_set).group_id
  principal_type = "GROUP"

  target_id   = each.value.account_key
  target_type = "AWS_ACCOUNT"
}

resource "aws_identitystore_group_membership" "all" {
  for_each          = aws_identitystore_group.all
  identity_store_id = each.value.identity_store_id
  group_id          = each.value.group_id
  member_id         = aws_identitystore_user.me.user_id
}

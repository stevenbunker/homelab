locals {
  templates         = "${path.module}/templates"
  aws_config        = "${pathexpand("~/.aws")}/config"
  environment       = "management"
  identity_store_id = data.aws_ssoadmin_instances.admin.identity_store_ids[0]
  instance_arn      = data.aws_ssoadmin_instances.admin.arns[0]
  split_admin_email_if_gmail = /* If the admin email is a gmail account, split the user and domain to later append the user with the friendly name of the account
    */ can(
    regex("(?P<user>[^@]+)(?P<domain>@gmail\\.com)", var.admin_email)
  ) ? regex("(?P<user>[^@]+)(?P<domain>@.*\\.com)", var.admin_email) : {}
}

# Manage AWS Org
## Enable AWS organizations, policies, and service principales
resource "aws_organizations_organization" "current" {
  enabled_policy_types = [
    "TAG_POLICY",
    "SERVICE_CONTROL_POLICY",
    "RESOURCE_CONTROL_POLICY"
  ]
  aws_service_access_principals = var.service_access_principals
}

## Define org policies
resource "aws_organizations_policy" "tag_policy" {
  name = "tag-policy"
  type = "TAG_POLICY"
  content = templatefile(
  "${local.templates}/policies.json.tftpl", {})
  tags = {
    Project     = "compliance"
    Environment = local.environment
  }
}

resource "aws_organizations_policy_attachment" "tagging_policy" {
  policy_id = aws_organizations_policy.tag_policy.id
  target_id = aws_organizations_organization.current.master_account_id
}

resource "aws_organizations_organizational_unit" "current" {
  for_each = { for org, accounts in var.organizational_units :
    org => accounts if length(
      [for account in accounts : account if contains(keys(var.organizational_accounts), account)]
  ) > 0 }
  name      = each.key
  parent_id = aws_organizations_organization.current.roots[0].id
}


## Create organization accounts
resource "aws_organizations_account" "current" {
  for_each = {
    for account, email in var.organizational_accounts :
    account => coalesce(
      email,
      account == "organization" ? var.admin_email :
    "${local.split_admin_email_if_gmail.user}+${account}${local.split_admin_email_if_gmail.domain}")
  }
  name = (
    each.key == "organization" ?
    "${aws_organizations_organization.current.master_account_name}" :
    "${aws_organizations_organization.current.master_account_name}-${each.key}"
  )
  email     = each.value
  role_name = "${var.organization_name}_OrgRole"
  lifecycle {
    ignore_changes = [role_name]
  }
  parent_id = (each.key == "organization" ?
    aws_organizations_organization.current.roots[0].id :
    lookup(
      aws_organizations_organizational_unit.current,
      coalesce([for k, v in var.organizational_units : k if contains(v, each.key)]...),
      aws_organizations_organization.current.roots[0]
    ).id
  )
}


## Delegate administration
resource "aws_organizations_delegated_administrator" "current" {
  for_each = {
    for service, account in var.delegated_administration :
    service => account
    if var.delegated_administration != null
  }
  account_id        = aws_organizations_account.current[each.value].id
  service_principal = each.key
}


# Create Admin and Terrafrom idenitities in each account
data "aws_ssoadmin_instances" "admin" {}

resource "aws_identitystore_user" "admin" {
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


## Create identity store groups, and permission sets in each account
resource "aws_identitystore_group" "all" {
  for_each          = var.required_child_sets_and_managed_policies
  display_name      = each.key
  description       = "The group for ${each.key} in child accounts"
  identity_store_id = local.identity_store_id
}

## Create permission sets
resource "aws_ssoadmin_permission_set" "all" {
  for_each     = var.required_child_sets_and_managed_policies
  name         = each.key
  description  = "The permission set for ${each.key} in child accounts"
  instance_arn = local.instance_arn
}

## Get AWS managed policies and attach them to the permission sets
data "aws_iam_policy" "managed" {
  for_each = toset(flatten(
    [for permission_set, policies in var.required_child_sets_and_managed_policies : policies]
  ))
  name = each.key
}

resource "aws_ssoadmin_managed_policy_attachment" "all" {
  /*
  Expand the policies for each permission set into one flat object.
  This also requires creating a unique ephemeral key.
  The for_each here feels kind of awkward and perhaps would be better abstracted into a module
  */
  for_each = merge([
    for set_name, policies in var.required_child_sets_and_managed_policies : {
      for policy in policies : "${set_name}.${policy}" => {
        set_name    = set_name
        policy_name = policy
      }
    }
  ]...)

  instance_arn       = local.instance_arn
  managed_policy_arn = lookup(data.aws_iam_policy.managed, each.value.policy_name).arn
  permission_set_arn = lookup(aws_ssoadmin_permission_set.all, each.value.set_name).arn
}

resource "terraform_data" "account_permission_set_product" {
  depends_on = [aws_organizations_account.current, aws_ssoadmin_permission_set.all, aws_identitystore_group.all]
  input = templatefile(
    "${local.templates}/aws_config.cfg.tftpl",
    {
      configs = [
        for pair in setproduct(keys(aws_ssoadmin_permission_set.all), keys(aws_organizations_account.current)) :
        {
          permissionKey_account_product = "${pair[0]}.${pair[1]}"
          role_name                     = pair[0]
          account_id                    = lookup(aws_organizations_account.current, pair[1]).id
        }
      ],
      region         = var.region
      start_url      = var.sso_start_url
      current_config = data.local_file.config.content
    }
  )
}

data "local_file" "config" {
  filename = local.aws_config
}

resource "aws_ssoadmin_account_assignment" "all" {
  /*
 For the cartessian product of each child account and permission set, assigne the permission set to a group, and the group to the accounts
  */
  for_each = { for pair in setproduct(keys(var.required_child_sets_and_managed_policies), keys(var.organizational_accounts)) :
    "${pair[0]}.${pair[1]}" => {
      permission_set = pair[0]
      account        = pair[1]
    }
  }
  instance_arn       = aws_ssoadmin_permission_set.all[each.value.permission_set].instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.all[each.value.permission_set].arn

  principal_id   = aws_identitystore_group.all[each.value.permission_set].group_id
  principal_type = "GROUP"

  target_id   = aws_organizations_account.current[each.value.account].id
  target_type = "AWS_ACCOUNT"
}


resource "aws_identitystore_group_membership" "all" {
  for_each          = aws_identitystore_group.all
  identity_store_id = each.value.identity_store_id
  group_id          = each.value.group_id
  member_id         = aws_identitystore_user.admin.user_id
}

/*
A custom terraform execute policy must be created in each child account before
it can be attached to the terraform permissions set. Cloudformation will create
and disseminate that permission set, as well as somne helper roles.
*/

resource "aws_cloudformation_stack_set" "automation_execution" {
  provider         = aws.stackset_delegate
  capabilities     = ["CAPABILITY_NAMED_IAM"]
  permission_model = "SERVICE_MANAGED"
  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }
  parameters = {
    AdministratorAccountId    = aws_organizations_organization.current.master_account_id
    ExecutionRoleName         = "AWSCloudFormationStackSetExecutionRole"
    AutomationExecutionPolicy = file("${local.templates}/automation_execution_policy.json")
    PolicyName                = "AutomationExecution"
  }
  region        = "us-east-1"
  name          = "iam-policies-and-roles-for-automation-execution"
  description   = "Terraform and cloudformation execution roles and policies created by the org account."
  call_as       = "DELEGATED_ADMIN"
  template_body = file("${local.templates}/automation_execution_stackset.json")
}

resource "aws_cloudformation_stack_set_instance" "automation_execution" {
  deployment_targets {
    organizational_unit_ids = [aws_organizations_organization.current.roots[0].id]
  }
  stack_set_instance_region = var.region
  stack_set_name            = aws_cloudformation_stack_set.automation_execution.name

}

resource "aws_iam_policy" "terraform_execute" {
  name        = aws_cloudformation_stack_set.automation_execution.parameters["PolicyName"]
  description = "Customer managed Terraform Execute policy. This policy was created by a CloudFormation stack in the management account"
  policy      = file("${local.templates}/automation_execution_policy.json")
}

resource "aws_ssoadmin_customer_managed_policy_attachment" "terraform_execute" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.all["TerraformExecute"].arn
  customer_managed_policy_reference {
    name = aws_iam_policy.terraform_execute.name
    path = "/"
  }
}

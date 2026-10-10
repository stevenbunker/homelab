data "aws_iam_policy_document" "automation_execution" {
  statement {
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:UpdateHostedZoneComment",
      "route53:ListTagsForResource",
      "route53:ListTagsForResources",
      "route53:ChangeTagsForResource",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:DeleteTags",
      "ec2:CreateVpc",
      "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:GetSecurityGroupsForVpc",
      "ec2:DisassociateSecurityGroupVpc",
      "ec2:CreateSecurityGroup",
      "ec2:CreateVpnGateway",
      "ec2:ModifyInstanceAttribute",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
      "ec2:TerminateInstances",
      "ec2:ImportKeyPair",
      "ec2:CreateTags",
      "ec2:CreateRouteTable",
      "ec2:RunInstances",
      "ec2:ModifySecurityGroupRules",
      "ec2:CreateVolume",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:Describe*",
      "ec2:AssociateSecurityGroupVpc",
      "ec2:DeleteSecurityGroup",
      "ec2:ApplySecurityGroupsToClientVpnTargetNetwork",
      "ec2:CreateSubnet",
      "ec2:DeleteKeyPair",
      "ec2:DeleteTags",
      "ec2:DescribeTags",
      "ec2:CreateTags",
      "organizations:ListPoliciesForTarget",
      "organizations:DescribeEffectivePolicy",
      "organizations:ListTargetsForPolicy",
      "organizations:ListTagsForResource",
      "organizations:DetachPolicy",
      "organizations:ListDelegatedServicesForAccount",
      "organizations:DeletePolicy",
      "organizations:UntagResource",
      "organizations:ListEffectivePolicyValidationErrors",
      "organizations:DisablePolicyType",
      "organizations:DescribePolicy",
      "organizations:ListChildren",
      "organizations:ListAccountsForParent",
      "organizations:TagResource",
      "organizations:UpdatePolicy",
      "organizations:EnablePolicyType",
      "organizations:AttachPolicy",
      "organizations:PutResourcePolicy",
      "organizations:ListParents",
      "organizations:ListOrganizationalUnitsForParent",
      "organizations:ListRoots",
      "organizations:CreatePolicy",
      "organizations:ListInboundResponsibilityTransfers",
      "organizations:DeleteResourcePolicy",
      "organizations:ListCreateAccountStatus",
      "organizations:DescribeResourcePolicy",
      "organizations:DescribeOrganization",
      "organizations:ListOutboundResponsibilityTransfers",
      "organizations:ListAWSServiceAccessForOrganization",
      "organizations:ListPolicies",
      "organizations:ListHandshakesForOrganization",
      "organizations:ListDelegatedAdministrators",
      "organizations:ListHandshakesForAccount",
      "organizations:ListAccounts",
      "organizations:ListAccountsWithInvalidEffectivePolicy",
      "resource-explorer:*",
      "tag:ListRequiredTags",
      "tag:UntagResources",
      "tag:TagResources",
      "tag:GetComplianceSummary",
      "s3:*",
      "sns:*",
      "cloudformation:*"
    ]
    resources = ["*"]
  }
}

resource "aws_cloudformation_stack_set" "automation_execution" {
  capabilities = ["CAPABILITY_NAMED_IAM"]
  permission_model = "SERVICE_MANAGED"
  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }
  parameters = {
    AdministratorAccountId = aws_organizations_organization.my.master_account_id
    ExecutionRoleName = "AWSCloudFormationStackSetExecutionRole"
    AutomationExecutionPolicy = data.aws_iam_policy_document.automation_execution.json
    PolicyName = "AutomationExecution"
  }
  region = "us-east-1"
  name                    = "iam-policies-and-roles-for-automation-execution"
  description             = "Terraform and cloudformation execution roles and policies created by the org account."

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Parameters = {
      AdministratorAccountId = {
        Type = "String",
        Description = "AWS Account Id of the administrator account (the account in which StackSets will be created).",
        MaxLength = 12,
        MinLength = 12
      }
      ExecutionRoleName = {
        Type = "String",
        Default = "AWSCloudFormationStackSetExecutionRole",
        Description = "The name of the execution role. Defaults to 'AWSCloudFormationStackSetExecutionRole'."
      }
      AutomationExecutionPolicy = {
        Type = "String"
        Description = "The Policy document for automation"
      }
      PolicyName = {
        Type = "String"
        Description = "The name of the policy to be made in child accounts"
      }
    }
    Resources = {
      CustomTerraformPolicy = {
        Type = "AWS::IAM::ManagedPolicy"
        Properties = {
          Description       = "Customer managed Terraform Execute policy. This policy was created by a CloudFormation stack in the management account"
          ManagedPolicyName = {"Ref": "PolicyName"}
          Path              = "/"
          PolicyDocument    = {"Ref": "AutomationExecutionPolicy"}
        }
      }
      cloudformationExecutionRole = {
        Type = "AWS::IAM::Role"
        Properties = {
          RoleName = {"Ref": "ExecutionRoleName"}
          AssumeRolePolicyDocument = {
            Version = "2012-10-17"
            Statement = [{
              Effect = "Allow"
              Principal = {
                AWS : [{"Ref": "AdministratorAccountId"}]
              }
              Action = ["sts:AssumeRole"]
            }]
          }
          Path = "/"
          ManagedPolicyArns = [
            { "Ref" : "CustomTerraformPolicy" }
          ]
        }
      }
    }
  })
}

resource "aws_cloudformation_stack_set_instance" "automation_execution" {
  deployment_targets {
    organizational_unit_ids = [aws_organizations_organization.my.roots[0].id]
  }
  stack_set_instance_region = var.region
  stack_set_name = aws_cloudformation_stack_set.automation_execution.name
  
}
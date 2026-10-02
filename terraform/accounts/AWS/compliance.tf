locals {
  policies_string = templatefile(
  "${path.module}/policies.json.tpl", {})
  policies_json = jsondecode(local.policies_string)
  tag_policy    = local.policies_json.tag_policy
}

resource "aws_organizations_policy" "tag_policy" {
  name    = "tag-policy"
  type    = "TAG_POLICY"
  content = jsonencode(local.tag_policy)
  tags = {
    Project     = "compliance"
    Environment = local.environment
  }
}

resource "aws_organizations_policy_attachment" "tagging_policy" {
  policy_id = aws_organizations_policy.tag_policy.id
  target_id = aws_organizations_organization.my.master_account_id
}
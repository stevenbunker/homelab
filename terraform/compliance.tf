data "aws_caller_identity" "current" {}

resource "aws_organizations_policy" "tag_policy" {
  name    = "tag-policy"
  type    = "TAG_POLICY"
  content = jsonencode({ "tags" : { for tag in var.required_tags : tag => {} } })
  tags = {
    Project     = "compliance"
    Environment = "prod"
  }
}

resource "aws_organizations_policy_attachment" "tagging_policy" {
  policy_id = aws_organizations_policy.tag_policy.id
  target_id = data.aws_caller_identity.current.account_id
}
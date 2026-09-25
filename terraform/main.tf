resource "aws_budgets_budget" "aws_budget" {
  name         = "monthly-budget"
  budget_type  = "COST"
  limit_amount = "15.0"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
}
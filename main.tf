module "main_network" {
  source = "./main_network"
  providers = {
    aws = aws.west
  }
}

resource "aws_budgets_budget" "aws_budget" {
  name         = "monthly-budget"
  budget_type  = "COST"
  limit_amount = "15.0"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
}

module "open_vpn" {
  source = "./open_vpn"
  providers = {
    aws = aws.west
  }
  ssh_ip_allowed = var.ssh_ip_allowed
  main_public_subnet_id = module.main_network.main_public_subnet
  main_vpc_id = module.main_network.main_vpc_id
  hosted_Zone = local.hosted_Zone
  record_name = local.record_name
}
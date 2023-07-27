data "aws_availability_zones" "current" {
  state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.server_name}-vpc"
  cidr = "10.0.0.0/16"

  azs = [
    data.aws_availability_zones.current.names[0],
    data.aws_availability_zones.current.names[1],
    data.aws_availability_zones.current.names[2]
  ]
  public_subnets      = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  private_subnets     = ["10.0.64.0/20", "10.0.80.0/20", "10.0.96.0/20"]
  elasticache_subnets = ["10.0.112.0/20", "10.0.128.0/20", "10.0.144.0/20"]
  database_subnets    = ["10.0.208.0/20", "10.0.224.0/20", "10.0.240.0/20"]

  default_security_group_egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  enable_flow_log                                 = true
  create_flow_log_cloudwatch_iam_role             = true
  create_flow_log_cloudwatch_log_group            = true
  flow_log_traffic_type                           = "REJECT"
  flow_log_cloudwatch_log_group_retention_in_days = 14

  create_elasticache_subnet_group = true
  create_database_subnet_group    = true
}

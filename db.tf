data "aws_kms_key" "secretsmanager" {
  key_id = "alias/aws/secretsmanager"
}

data "aws_kms_key" "rds" {
  key_id = "alias/aws/rds"
}

resource "aws_security_group" "db" {
  name   = "${var.server_name}-db-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "main" {
  engine                                = "postgres"
  engine_version                        = "14.7"
  identifier                            = "${var.server_name}-db"
  username                              = "mastodon"
  manage_master_user_password           = true
  master_user_secret_kms_key_id         = data.aws_kms_key.secretsmanager.arn
  instance_class                        = "db.t4g.micro"
  storage_type                          = "gp2"
  allocated_storage                     = 20
  max_allocated_storage                 = 0
  db_subnet_group_name                  = module.vpc.database_subnet_group_name
  publicly_accessible                   = false
  vpc_security_group_ids                = [aws_security_group.db.id]
  port                                  = 5432
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id       = data.aws_kms_key.rds.arn
  db_name                               = "mastodon"
  parameter_group_name                  = "default.postgres14"
  backup_retention_period               = 35
  copy_tags_to_snapshot                 = true
  storage_encrypted                     = true
  kms_key_id                            = data.aws_kms_key.rds.arn
  auto_minor_version_upgrade            = true
  final_snapshot_identifier             = "${var.server_name}-db-final-snapshot"
  deletion_protection                   = true
}

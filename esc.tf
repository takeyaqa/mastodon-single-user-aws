locals {
  mastodon_version = "v4.1.6"
}

resource "aws_security_group" "web" {
  name   = "${var.server_name}-web-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 3000
    to_port     = 3000
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

resource "aws_security_group" "streaming" {
  name   = "${var.server_name}-streaming-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 4000
    to_port     = 4000
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

resource "aws_iam_role" "ecs_task_execution" {
  name                = "mastodonEcsTaskExecutionRole"
  assume_role_policy  = data.aws_iam_policy_document.ecs_task_execution.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
  inline_policy {
    name   = "SecretsReadForECSPolicy"
    policy = data.aws_iam_policy_document.ecs_task_read_secrets.json
  }
  inline_policy {
    name   = "RunCommandForECSPolicy"
    policy = data.aws_iam_policy_document.ecs_task_run_command.json
  }
}

data "aws_iam_policy_document" "ecs_task_execution" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "ecs_task_read_secrets" {
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.main.arn,
      aws_db_instance.main.master_user_secret.0.secret_arn
    ]
  }
}

data "aws_iam_policy_document" "ecs_task_run_command" {
  statement {
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }
}

locals {
  environment = [
    {
      name  = "LOCAL_DOMAIN"
      value = var.local_domain
    },
    {
      name  = "WEB_DOMAIN"
      value = var.web_domain
    },
    {
      name  = "SINGLE_USER_MODE"
      value = "true"
    },
    {
      name  = "DB_HOST"
      value = aws_db_instance.main.address
    },
    {
      name  = "DB_PORT"
      value = tostring(aws_db_instance.main.port)
    },
    {
      name  = "DB_NAME"
      value = aws_db_instance.main.db_name
    },
    {
      name  = "REDIS_HOST"
      value = aws_elasticache_cluster.main.cache_nodes.0.address
    },
    {
      name  = "REDIS_PORT"
      value = tostring(aws_elasticache_cluster.main.cache_nodes.0.port)
    },
    {
      name  = "S3_ENABLED"
      value = "true"
    },
    {
      name  = "S3_BUCKET"
      value = aws_s3_bucket.files.id
    },
    {
      name  = "S3_REGION"
      value = aws_s3_bucket.files.region
    },
    {
      name  = "S3_ALIAS_HOST"
      value = var.files_domain
    },
    {
      name  = "S3_PERMISSION"
      value = "private"
    },
    {
      name  = "SMTP_SERVER"
      value = var.smtp_server
    },
    {
      name  = "SMTP_PORT"
      value = tostring(var.smtp_port)
    },
    {
      name  = "SMTP_FROM_ADDRESS"
      value = var.smtp_from_address
    }
  ]
  secrets = [
    {
      name      = "SECRET_KEY_BASE"
      valueFrom = "${aws_secretsmanager_secret.main.arn}:secret_key_base::"
    },
    {
      name      = "OTP_SECRET"
      valueFrom = "${aws_secretsmanager_secret.main.arn}:otp_secret::"
    },
    {
      name      = "VAPID_PRIVATE_KEY"
      valueFrom = "${aws_secretsmanager_secret.main.arn}:vapid_private_key::"
    },
    {
      name      = "VAPID_PUBLIC_KEY"
      valueFrom = "${aws_secretsmanager_secret.main.arn}:vapid_public_key::"
    },
    {
      name      = "DB_USER"
      valueFrom = "${aws_db_instance.main.master_user_secret.0.secret_arn}:username::"
    },
    {
      name      = "DB_PASS"
      valueFrom = "${aws_db_instance.main.master_user_secret.0.secret_arn}:password::"
    },
    {
      name      = "SMTP_LOGIN"
      valueFrom = "${aws_secretsmanager_secret.main.arn}:smtp_login::"
    },
    {
      name      = "SMTP_PASSWORD"
      valueFrom = "${aws_secretsmanager_secret.main.arn}:smtp_password::"
    }
  ]
}

resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/${var.server_name}-web"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "streaming" {
  name              = "/ecs/${var.server_name}-streaming"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "sidekiq" {
  name              = "/ecs/${var.server_name}-sidekiq"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "web" {
  family                   = "${var.server_name}-web"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  network_mode             = "awsvpc"
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.ecs_task_execution.arn
  container_definitions = jsonencode([
    {
      essential = true
      name      = "mastodon"
      image     = "ghcr.io/mastodon/mastodon:${local.mastodon_version}"
      portMappings = [
        {
          name          = "mastodon-3000-tcp"
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      command = [
        "bash",
        "-c",
        "bundle exec rails db:migrate && bundle exec rails server -p 3000"
      ]
      environment = local.environment
      secrets     = local.secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.web.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
      healthCheck = {
        command = [
          "CMD-SHELL",
          "wget -q --spider --proxy=off localhost:3000/health || exit 1"
        ],
        interval    = 300
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
  }])
}

resource "aws_ecs_task_definition" "streaming" {
  family                   = "${var.server_name}-streaming"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.ecs_task_execution.arn
  container_definitions = jsonencode([
    {
      essential = true
      name      = "mastodon"
      image     = "ghcr.io/mastodon/mastodon:${local.mastodon_version}"
      portMappings = [
        {
          name          = "mastodon-4000-tcp"
          containerPort = 4000
          hostPort      = 4000
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      command = [
        "bash",
        "-c",
        "node ./streaming"
      ]
      environment = local.environment
      secrets     = local.secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.streaming.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
      healthCheck = {
        command = [
          "CMD-SHELL",
          "wget -q --spider --proxy=off localhost:4000/api/v1/streaming/health || exit 1"
        ],
        interval    = 300
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
  }])
}

resource "aws_ecs_task_definition" "sidekiq" {
  family                   = "${var.server_name}-sidekiq"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 1024
  network_mode             = "awsvpc"
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.ecs_task_execution.arn
  container_definitions = jsonencode([
    {
      essential = true
      name      = "mastodon"
      image     = "ghcr.io/mastodon/mastodon:${local.mastodon_version}"
      command = [
        "bash",
        "-c",
        "bundle exec sidekiq"
      ]
      environment = local.environment
      secrets     = local.secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.sidekiq.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
      healthCheck = {
        command = [
          "CMD-SHELL",
          "ps aux | grep '[s]idekiq\\ 6' || false"
        ],
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
  }])
}

resource "aws_ecs_cluster" "main" {
  name = "${var.server_name}-cluster"
}

resource "aws_ecs_service" "mastodon_web" {
  cluster                = aws_ecs_cluster.main.id
  launch_type            = "FARGATE"
  platform_version       = "LATEST"
  task_definition        = aws_ecs_task_definition.web.arn
  name                   = "${var.server_name}-web-service"
  desired_count          = 1
  enable_execute_command = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.web.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "mastodon"
    container_port   = 3000
  }
}

resource "aws_ecs_service" "streaming" {
  cluster                = aws_ecs_cluster.main.id
  launch_type            = "FARGATE"
  platform_version       = "LATEST"
  task_definition        = aws_ecs_task_definition.streaming.arn
  name                   = "${var.server_name}-streaming-service"
  desired_count          = 1
  enable_execute_command = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.streaming.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.streaming.arn
    container_name   = "mastodon"
    container_port   = 4000
  }
}

resource "aws_ecs_service" "sidekiq" {
  cluster                = aws_ecs_cluster.main.id
  launch_type            = "FARGATE"
  platform_version       = "LATEST"
  task_definition        = aws_ecs_task_definition.sidekiq.arn
  name                   = "${var.server_name}-sidekiq-service"
  desired_count          = 1
  enable_execute_command = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [module.vpc.default_security_group_id]
    assign_public_ip = true
  }
}

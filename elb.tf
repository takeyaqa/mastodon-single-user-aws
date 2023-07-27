data "aws_elb_service_account" "current" {}

data "aws_acm_certificate" "web_domain" {
  domain = var.web_domain
}

resource "aws_security_group" "elb" {
  name   = "${var.server_name}-elb-sg"
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.elb.id

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.elb.id

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_lb" "main" {
  name               = "${var.server_name}-elb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb.id]
  subnets            = module.vpc.public_subnets

  access_logs {
    enabled = true
    bucket  = aws_s3_bucket.elb_log.id
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
    order = 100
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.web_domain.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
    order            = 300
  }
}

resource "aws_lb_listener_rule" "streaming" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.streaming.arn
  }

  condition {
    path_pattern {
      values = ["/api/v1/streaming/*"]
    }
  }
}

resource "aws_lb_target_group" "web" {
  name        = "${var.server_name}-web"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id
  health_check {
    enabled  = true
    protocol = "HTTP"
    path     = "/health"
    interval = 300
  }
}

resource "aws_lb_target_group" "streaming" {
  name        = "${var.server_name}-streaming"
  port        = 4000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id
  health_check {
    enabled  = true
    protocol = "HTTP"
    path     = "/api/v1/streaming/health"
    interval = 300
  }
}

resource "aws_s3_bucket" "elb_log" {
  bucket_prefix       = "${var.server_name}-elb-log-"
  object_lock_enabled = false
}

resource "aws_s3_bucket_public_access_block" "elb_log" {
  bucket = aws_s3_bucket.elb_log.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "elb_log" {
  bucket = aws_s3_bucket.elb_log.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "elb_log" {
  bucket = aws_s3_bucket.elb_log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_policy" "elb_log" {
  bucket = aws_s3_bucket.elb_log.id
  policy = data.aws_iam_policy_document.elb_log.json
}

data "aws_iam_policy_document" "elb_log" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.current.arn]
    }
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.elb_log.arn}",
      "${aws_s3_bucket.elb_log.arn}/*"
    ]
  }
}

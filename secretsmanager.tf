resource "aws_secretsmanager_secret" "main" {
  name = "${var.server_name}-secrets"
}

resource "aws_secretsmanager_secret_version" "main" {
  secret_id = aws_secretsmanager_secret.main.id
  secret_string = jsonencode(
    {
      secret_key_base   = var.secret_key_base
      otp_secret        = var.otp_secret
      vapid_private_key = var.vapid_private_key
      vapid_public_key  = var.vapid_public_key
      smtp_login        = var.smtp_login
      smtp_password     = var.smtp_password
    }
  )
}

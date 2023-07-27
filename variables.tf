variable "server_name" {
  type        = string
  description = "example: mastodon-examplecom"
}

variable "route53_zone" {
  type        = string
  description = "example: example.com"
}

variable "local_domain" {
  type        = string
  description = "example: example.com"
}

variable "web_domain" {
  type        = string
  description = "example: mastodon.example.com"
}

variable "files_domain" {
  type        = string
  description = "example: files.mastodon.example.com"
}

variable "secret_key_base" {
  type        = string
  description = "command: bundle exec rake secret"
  sensitive   = true
}

variable "otp_secret" {
  type        = string
  description = "command: bundle exec rake secret"
  sensitive   = true
}

variable "vapid_private_key" {
  type        = string
  description = "command: bundle exec rake mastodon:webpush:generate_vapid_key"
  sensitive   = true
}

variable "vapid_public_key" {
  type        = string
  description = "command: bundle exec rake mastodon:webpush:generate_vapid_key"
  sensitive   = true
}

variable "smtp_server" {
  type = string
}

variable "smtp_port" {
  type = number
}

variable "smtp_login" {
  type      = string
  sensitive = true
}

variable "smtp_password" {
  type      = string
  sensitive = true
}

variable "smtp_from_address" {
  type = string
}

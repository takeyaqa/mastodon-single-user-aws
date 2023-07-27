terraform {
  backend "s3" {}
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.9"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      Name = var.server_name
    }
  }
}

provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
}

data "aws_region" "current" {}

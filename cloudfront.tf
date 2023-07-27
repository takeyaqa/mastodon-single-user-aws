data "aws_acm_certificate" "files_domain" {
  domain   = var.files_domain
  provider = aws.us-east-1
}

resource "aws_cloudfront_distribution" "main" {
  enabled     = true
  price_class = "PriceClass_All"
  aliases     = [var.files_domain]
  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.files_domain.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
  http_version    = "http2and3"
  is_ipv6_enabled = false

  origin {
    domain_name              = aws_s3_bucket.files.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
    origin_id                = aws_s3_bucket.files.id
  }

  default_cache_behavior {
    target_origin_id           = aws_s3_bucket.files.id
    compress                   = true
    viewer_protocol_policy     = "https-only"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
    response_headers_policy_id = "60669652-455b-4ae9-85a4-c4c02393f86c" # Managed-SimpleCORS
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${var.server_name}-origin-access-control"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

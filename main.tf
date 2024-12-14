resource "aws_s3_bucket" "static_bucket" {
  bucket        = "royston.sctp-sandbox.com"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "enable_public_access" {
  bucket                  = aws_s3_bucket.static_bucket.id
  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_public_access" {
  bucket = aws_s3_bucket.static_bucket.id
  policy = data.aws_iam_policy_document.get_object.json
  depends_on = [aws_s3_bucket_public_access_block.enable_public_access]
}


data "aws_iam_policy_document" "get_object" {
  version = "2012-10-17"
  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::royston.sctp-sandbox.com/*"
    ]
  }
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.static_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

data "aws_route53_zone" "sctp_zone" {
  name = "sctp-sandbox.com"
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.sctp_zone.zone_id
  name    = "royston"
  type    = "A"

  alias {
    name                   = aws_s3_bucket_website_configuration.website.website_domain
    zone_id                = aws_s3_bucket.static_bucket.hosted_zone_id
    evaluate_target_health = true
  }
}

#Website objects
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.static_bucket.id
  key          = "index.html"
  source       = "${path.module}/website/index.html"
  content_type = "text/html"

  etag = filemd5("${path.module}/website/index.html")
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.static_bucket.id
  key          = "error.html"
  source       = "${path.module}/website/error.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/website/error.html")
}

# For other static assets
resource "aws_s3_object" "assets" {
  for_each     = fileset("${path.module}/website/assets", "**/*")
  bucket       = aws_s3_bucket.static_bucket.id
  key          = "assets/${each.value}"
  source       = "${path.module}/website/assets/${each.value}"
  etag         = filemd5("${path.module}/website/assets/${each.value}")
  content_type = lookup(local.mime_types, split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")
}

# For other images
resource "aws_s3_object" "images" {
  for_each     = fileset("${path.module}/website/images", "*")
  bucket       = aws_s3_bucket.static_bucket.id
  key          = "images/${each.value}"
  source       = "${path.module}/website/images/${each.value}"
  etag         = filemd5("${path.module}/website/images/${each.value}")
  content_type = lookup(local.mime_types, split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")
}

# Define MIME types mapping
locals {
  mime_types = {
    "css"  = "text/css"
    "html" = "text/html"
    "ico"  = "image/vnd.microsoft.icon"
    "js"   = "application/javascript"
    "json" = "application/json"
    "png"  = "image/png"
    "jpg"  = "image/jpeg"
    "jpeg" = "image/jpeg"
    "svg"  = "image/svg+xml"
  }
}


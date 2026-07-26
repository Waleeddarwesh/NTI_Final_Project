###############################################################################
# ELB Service Account
#
# ALB access log delivery requires a bucket policy that grants PUT permission
# to the REGIONAL ELB service account, NOT to "elasticloadbalancing.amazonaws.com"
# as a Service principal. Using the service principal is a common mistake that
# silently prevents log delivery with no error message from the ALB side.
#
# The `aws_elb_service_account` data source returns the correct regional
# account ID automatically. If you ever switch regions, re-apply is sufficient
# because this data source re-queries at plan time.
###############################################################################

data "aws_elb_service_account" "main" {}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

###############################################################################
# ALB Logs Bucket
###############################################################################

resource "aws_s3_bucket" "alb_logs" {
  # Bucket names must be globally unique. Using account ID + region as a
  # suffix avoids collisions without requiring the user to supply a unique
  # name manually. The name intentionally does NOT include random characters
  # so the Terraform output is predictable and readable in the console.
  bucket        = "${var.project_name}-${var.environment}-alb-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  force_destroy = var.force_destroy

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-alb-logs"
    }
  )
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  versioning_configuration {
    # Versioning on a logs bucket prevents accidental single-file deletion
    # from losing data permanently, at the cost of some storage overhead.
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.alb_logs_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

###############################################################################
# Bucket Policy — ALB Log Delivery
#
# CRITICAL: ALB (Application Load Balancer) uses the LEGACY ELB delivery
# mechanism for access logs. The correct bucket policy grants PutObject to
# the regional ELB SERVICE ACCOUNT (an AWS-managed account, not a service
# principal). Using "elasticloadbalancing.amazonaws.com" as a Service
# principal does NOT work for ALB access logs and fails silently.
#
# Reference:
# https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
###############################################################################

data "aws_iam_policy_document" "alb_logs_bucket_policy" {
  statement {
    sid    = "ALBLogDelivery"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.alb_logs.arn}/alb-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
  }

  # Second statement required to allow the ELB service to check bucket ACLs
  # (legacy requirement that persists even for policy-based access).
  statement {
    sid    = "AWSLogDeliveryAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.alb_logs.arn]
  }

  statement {
    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.alb_logs.arn}/alb-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs_bucket_policy.json

  # Public access block must be applied before the bucket policy —
  # otherwise Terraform may try to apply the policy while the bucket
  # briefly allows public access, which can cause policy validation failures.
  depends_on = [aws_s3_bucket_public_access_block.alb_logs]
}

output "alb_logs_bucket_id" {
  description = "S3 bucket name for ALB access logs — use this in the ALB's access_logs block: access_logs { bucket = <this> prefix = \"alb-logs\" }"
  value       = aws_s3_bucket.alb_logs.id
}

output "alb_logs_bucket_arn" {
  description = "ARN of the ALB logs S3 bucket"
  value       = aws_s3_bucket.alb_logs.arn
}

output "alb_logs_prefix" {
  description = "S3 key prefix used in the bucket policy and expected by ALB log delivery"
  value       = "alb-logs"
}

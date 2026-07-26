variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment identifier used in resource naming"
  type        = string
}

variable "alb_logs_retention_days" {
  description = "Number of days to retain ALB access logs in S3 before deletion. 90 days gives enough history for security review and usage analysis without runaway cost."
  type        = number
  default     = 90
}

variable "force_destroy" {
  description = "Allow Terraform to delete the S3 bucket even when it contains objects. Set to true only during dev iteration. Always false in production — accidentally deleting ALB logs or Terraform state is not recoverable."
  type        = bool
  default     = false
}

variable "extra_tags" {
  description = "Additional tags merged onto every resource in this module"
  type        = map(string)
  default     = {}
}

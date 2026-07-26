variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment identifier used in resource naming"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the RDS DB subnet group — must span at least 2 AZs (AWS requirement, even for single-AZ instances)"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "Security group ID for the RDS instance (from the security-groups module)"
  type        = string
}

variable "db_password" {
  description = "Master password for the RDS instance. Passed in from the secrets-manager module which generates it via random_password — never set this directly in tfvars."
  type        = string
  sensitive   = true
}

variable "engine_version" {
  description = "PostgreSQL major version to run on RDS. Defaults to 16, which has multi-year standard support and full Django/extension ecosystem maturity as of mid-2026."
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class. db.t3.micro is free-tier eligible but has limited RAM; bump to db.t3.small or db.t3.medium if query performance matters for your workload."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage_gb" {
  description = "Initial allocated storage in GB. RDS can autoscale above this (see max_allocated_storage_gb)."
  type        = number
  default     = 20
}

variable "max_allocated_storage_gb" {
  description = "Maximum storage RDS may autoscale to, in GB. Set to 0 to disable autoscaling."
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Name of the initial database to create on the RDS instance"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "appuser"
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for automatic failover. False by default (matching single_nat_gateway = true for dev); set to true for production."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain automated RDS backups. 0 disables backups (not recommended even in dev — silent data loss if the instance is accidentally deleted)."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Prevent accidental Terraform-driven deletion of the RDS instance. Defaults to true — set to false only when you explicitly intend to destroy, then revert after."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot when the RDS instance is destroyed. Set to false in production so a snapshot is taken before deletion."
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Enable RDS Performance Insights for query-level diagnostics. Free for 7-day retention on supported instance classes."
  type        = bool
  default     = true
}

variable "extra_tags" {
  description = "Additional tags merged onto every resource in this module"
  type        = map(string)
  default     = {}
}

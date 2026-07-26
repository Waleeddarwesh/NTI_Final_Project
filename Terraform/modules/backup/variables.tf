variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment identifier used in resource naming"
  type        = string
}

variable "rds_instance_arn" {
  description = "ARN of the RDS instance to include in backup selections. Passed in from the rds module output."
  type        = string
}

variable "eks_cluster_arn" {
  description = "ARN of the EKS cluster. Included in backup selection so EKS-attached EBS volumes (PersistentVolumes via the EBS CSI driver) are captured if the CSI driver is installed later."
  type        = string
}

variable "daily_backup_hour_utc" {
  description = "Hour (UTC, 0-23) at which the daily backup window starts. Defaults to 2 (02:00 UTC) to avoid overlap with the RDS maintenance window (Mon 04:00 UTC) and the default backup window (03:00 UTC) from the rds module."
  type        = number
  default     = 2
}

variable "backup_retention_days" {
  description = "Number of days to retain backup recovery points in the vault before automatic deletion."
  type        = number
  default     = 35
}

variable "vault_kms_key_arn" {
  description = "KMS key ARN to encrypt the backup vault. Defaults to null (AWS managed key). Provide a customer-managed key ARN for stricter key control and auditability."
  type        = string
  default     = null
}

variable "extra_tags" {
  description = "Additional tags merged onto every resource in this module"
  type        = map(string)
  default     = {}
}

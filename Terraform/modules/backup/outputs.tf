output "vault_name" {
  description = "Name of the AWS Backup vault"
  value       = aws_backup_vault.this.name
}

output "vault_arn" {
  description = "ARN of the AWS Backup vault"
  value       = aws_backup_vault.this.arn
}

output "plan_id" {
  description = "ID of the AWS Backup plan"
  value       = aws_backup_plan.this.id
}

output "plan_arn" {
  description = "ARN of the AWS Backup plan"
  value       = aws_backup_plan.this.arn
}

output "backup_role_arn" {
  description = "ARN of the IAM role used by AWS Backup service"
  value       = aws_iam_role.backup.arn
}

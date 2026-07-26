###############################################################################
# Backup IAM Role
#
# AWS Backup requires its own IAM service role to describe and back up
# resources on your behalf. This role is separate from the EKS and Jenkins
# roles from Part 2 — it is assumed by the backup.amazonaws.com service,
# not by EC2 or EKS workloads.
###############################################################################

data "aws_iam_policy_document" "backup_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.project_name}-${var.environment}-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role.json

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-backup-role"
    }
  )
}

# AWS managed policy that grants Backup the permissions it needs to create
# and restore snapshots across RDS, EBS, EFS, DynamoDB, and EKS.
resource "aws_iam_role_policy_attachment" "backup_policy" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore_policy" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

###############################################################################
# Backup Vault
#
# The vault is the logical container for recovery points. Encrypting with
# the AWS managed key by default; supply vault_kms_key_arn for a CMK.
###############################################################################

resource "aws_backup_vault" "this" {
  name        = "${var.project_name}-${var.environment}-vault"
  kms_key_arn = var.vault_kms_key_arn

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-vault"
    }
  )
}

###############################################################################
# Backup Plan
#
# Daily backup at var.daily_backup_hour_utc with a 1-hour window, retained
# for var.backup_retention_days days. The schedule is intentionally offset
# from the RDS maintenance and backup windows (03:00-04:00 UTC from the rds
# module) to avoid any conflict.
###############################################################################

resource "aws_backup_plan" "this" {
  name = "${var.project_name}-${var.environment}-daily-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.this.name

    # cron(minute hour day-of-month month day-of-week year)
    schedule = "cron(0 ${var.daily_backup_hour_utc} * * ? *)"

    start_window_minutes    = 60
    completion_window_minutes = 180

    lifecycle {
      delete_after = var.backup_retention_days
    }

    recovery_point_tags = merge(
      var.extra_tags,
      {
        BackupPlan  = "${var.project_name}-${var.environment}-daily-plan"
        Environment = var.environment
      }
    )
  }

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-daily-plan"
    }
  )
}

###############################################################################
# Backup Selection
#
# Selects resources to back up. Strategy: explicit ARN list for the
# current resources (RDS, EKS cluster) rather than tag-based selection,
# which would require every future resource to have consistent tags to
# be captured. Explicit ARNs are less dynamic but more predictable — you
# know exactly what's backed up without auditing tags.
###############################################################################

resource "aws_backup_selection" "this" {
  name         = "${var.project_name}-${var.environment}-selection"
  plan_id      = aws_backup_plan.this.id
  iam_role_arn = aws_iam_role.backup.arn

  resources = [
    var.rds_instance_arn,
    var.eks_cluster_arn,
  ]
}

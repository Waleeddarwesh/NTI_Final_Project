###############################################################################
# DB Parameter Group
#
# Explicitly managed so any future parameter changes (e.g. log_min_duration,
# pg_stat_statements for Performance Insights) can be applied via Terraform
# rather than manually in the console and then drifting from IaC state.
###############################################################################

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.project_name}-${var.environment}-pg${var.engine_version}-"
  family      = "postgres${var.engine_version}"
  description = "Custom parameter group for ${var.project_name}-${var.environment} PostgreSQL ${var.engine_version}"

  # Enable query-level execution statistics, required for Performance
  # Insights to show per-query breakdown. Needs a DB restart to take effect.
  parameter {
    name         = "pg_stat_statements.track"
    value        = "ALL"
    apply_method = "pending-reboot"
  }

  # Emit slow queries to PostgreSQL logs (and therefore CloudWatch Logs).
  # 1000ms threshold — tune down in dev if you want finer granularity.
  parameter {
    name         = "log_min_duration_statement"
    value        = "1000"
    apply_method = "immediate"
  }

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-pg${var.engine_version}-params"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

###############################################################################
# DB Subnet Group
#
# AWS requires at least 2 AZs even for single-AZ RDS instances — the subnet
# group defines the *pool* of subnets RDS may use, not that it uses all of
# them simultaneously.
###############################################################################

resource "aws_db_subnet_group" "this" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  description = "DB subnet group for ${var.project_name}-${var.environment}"
  subnet_ids  = var.private_subnet_ids

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-subnet-group"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

###############################################################################
# RDS Instance
###############################################################################

resource "aws_db_instance" "this" {
  identifier_prefix = "${var.project_name}-${var.environment}-"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.max_allocated_storage_gb > 0 ? var.max_allocated_storage_gb : null
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_security_group_id]
  parameter_group_name   = aws_db_parameter_group.this.name

  multi_az               = var.multi_az
  publicly_accessible    = false
  deletion_protection    = var.deletion_protection
  skip_final_snapshot    = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-rds-final-snapshot"

  backup_retention_period   = var.backup_retention_days
  backup_window             = "03:00-04:00"
  maintenance_window        = "Mon:04:00-Mon:05:00"
  auto_minor_version_upgrade = true

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = 7

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  copy_tags_to_snapshot = true

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds"
    }
  )

  lifecycle {
    # Prevent Terraform from resetting the password on every apply.
    # The password is managed in Secrets Manager; if rotation is needed,
    # rotate via Secrets Manager and update the secret version, then run
    # a targeted Terraform apply only if the root password also needs changing.
    ignore_changes = [password]
  }
}

###############################################################################
# RDS Endpoint Secret
#
# Stored in Secrets Manager so the application and Kubernetes pods (via
# ExternalSecrets / the Jenkins pipeline) can read the DB host without it
# being hardcoded in manifests or environment variables. Lives in the rds
# module rather than the secrets-manager module to avoid the circular
# dependency that would result from wiring module.rds.db_host back into the
# module that generates module.rds's inputs.
#
# Both secrets (this one and secrets-manager's db_credentials secret) fall
# under the ${project_name}-${environment}-* ARN pattern that the Jenkins IAM
# policy already grants GetSecretValue access to.
###############################################################################

resource "aws_secretsmanager_secret" "rds_endpoint" {
  name_prefix             = "${var.project_name}-${var.environment}-rds-endpoint-"
  description             = "RDS PostgreSQL connection endpoint for ${var.project_name} ${var.environment}"
  recovery_window_in_days = 7

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-endpoint"
    }
  )
}

resource "aws_secretsmanager_secret_version" "rds_endpoint" {
  secret_id = aws_secretsmanager_secret.rds_endpoint.id

  secret_string = jsonencode({
    host = aws_db_instance.this.address
    port = aws_db_instance.this.port
  })
}

###############################################################################
# Generated DB Password
#
# The `random_password` resource generates a cryptographically random string
# and stores it in Terraform state. This is unavoidable here — RDS needs a
# master password at creation time, and that password needs to live somewhere
# Terraform can reference. The mitigating factors are:
#   1. The state file lives in the encrypted S3 bucket configured in backend.tf
#   2. The application never reads from Terraform state — it reads from Secrets
#      Manager, so the state exposure is an infra-bootstrap concern only
#   3. `ignore_changes = [password]` in the RDS module prevents Terraform from
#      resetting the password on subsequent applies
#
# Special characters are restricted to avoid breaking standard PostgreSQL
# connection string parsing (@ and / are delimiters in postgres:// URIs;
# including them in a password requires percent-encoding everywhere).
###############################################################################

resource "random_password" "db" {
  length           = var.password_length
  special          = true
  override_special = "!#$%^&*()-_=+[]{}|;:,.?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

###############################################################################
# Secrets Manager Secret
#
# Named with the ${project_name}-${environment}-db-credentials prefix so it
# falls under the ${project_name}-${environment}-* ARN pattern that the
# Jenkins IAM policy (Part 2, iam module) already grants GetSecretValue
# access to.
###############################################################################

resource "aws_secretsmanager_secret" "db_credentials" {
  name_prefix             = "${var.project_name}-${var.environment}-db-credentials-"
  description             = "RDS PostgreSQL master credentials for ${var.project_name} ${var.environment}"
  recovery_window_in_days = var.recovery_window_days

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-db-credentials"
    }
  )
}

###############################################################################
# Secret Version — DB Credentials JSON
#
# Stored as a JSON object matching the RDS native rotation Lambda schema so
# rotation can be added later without changing the secret structure.
# db_host is intentionally NOT here — it lives in the rds module's own
# endpoint secret (see modules/rds/main.tf) to avoid a circular dependency:
#   module.rds needs module.secrets_manager.db_password (this module)
#   if this module also needed module.rds.db_host → cycle, terraform errors
###############################################################################

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    engine   = "postgres"
    port     = var.db_port
    dbname   = var.db_name
    username = var.db_username
    password = random_password.db.result
  })
}

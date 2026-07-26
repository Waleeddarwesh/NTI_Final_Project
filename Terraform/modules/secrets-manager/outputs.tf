output "db_password" {
  description = "Generated DB master password — passed into the RDS module. Sensitive: never appears in terraform plan/apply output."
  value       = random_password.db.result
  sensitive   = true
}

output "db_credentials_secret_arn" {
  description = "ARN of the DB credentials secret (engine, port, dbname, username, password — no host, to avoid circular dependency with the rds module)"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_credentials_secret_name" {
  description = "Name of the DB credentials secret — use in 'aws secretsmanager get-secret-value --secret-id <this>' to retrieve credentials"
  value       = aws_secretsmanager_secret.db_credentials.name
}

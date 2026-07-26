output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.this.arn
}

output "db_endpoint" {
  description = "RDS connection endpoint (host:port) — use this in application DATABASE_URL construction, not the raw hostname"
  value       = aws_db_instance.this.endpoint
}

output "db_host" {
  description = "RDS hostname only, without the port suffix"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "RDS port"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Name of the initial database created on the instance"
  value       = aws_db_instance.this.db_name
}

output "db_username" {
  description = "Master username for the RDS instance"
  value       = aws_db_instance.this.username
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.this.name
}

output "parameter_group_name" {
  description = "Name of the DB parameter group"
  value       = aws_db_parameter_group.this.name
}

output "rds_endpoint_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the RDS host and port"
  value       = aws_secretsmanager_secret.rds_endpoint.arn
}

output "rds_endpoint_secret_name" {
  description = "Name of the RDS endpoint secret — use in 'aws secretsmanager get-secret-value --secret-id <this>' to retrieve the host"
  value       = aws_secretsmanager_secret.rds_endpoint.name
}

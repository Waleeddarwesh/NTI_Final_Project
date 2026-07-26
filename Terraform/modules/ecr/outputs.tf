output "repository_urls" {
  description = "Map of repository name to full ECR repository URL (used in docker build/push commands and Helm values)"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of repository name to ECR repository ARN"
  value       = { for k, v in aws_ecr_repository.this : k => v.arn }
}

output "registry_id" {
  description = "ECR registry ID (AWS account ID) — used in 'aws ecr get-login-password' commands"
  value       = values(aws_ecr_repository.this)[0].registry_id
}

output "login_command" {
  description = "Command to authenticate Docker to this ECR registry (run this on the Jenkins host before docker push)"
  value       = "aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
}

data "aws_region" "current" {}

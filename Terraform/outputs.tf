###############################################################################
# Root Outputs — Part 1: VPC
###############################################################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateway(s)"
  value       = module.vpc.nat_gateway_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

###############################################################################
# Root Outputs — Part 2: Security Groups & IAM
###############################################################################

output "eks_cluster_security_group_id" {
  description = "Security group ID for the EKS control plane"
  value       = module.security_groups.eks_cluster_security_group_id
}

output "eks_nodes_security_group_id" {
  description = "Security group ID for EKS worker nodes"
  value       = module.security_groups.eks_nodes_security_group_id
}

output "jenkins_security_group_id" {
  description = "Security group ID for the Jenkins EC2 instance"
  value       = module.security_groups.jenkins_security_group_id
}

output "rds_security_group_id" {
  description = "Security group ID for the RDS instance"
  value       = module.security_groups.rds_security_group_id
}

output "eks_cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane"
  value       = module.iam.eks_cluster_role_arn
}

output "eks_node_role_arn" {
  description = "IAM role ARN for EKS worker nodes"
  value       = module.iam.eks_node_role_arn
}

output "eks_node_instance_profile_name" {
  description = "IAM instance profile name for EKS worker nodes"
  value       = module.iam.eks_node_instance_profile_name
}

output "jenkins_role_arn" {
  description = "IAM role ARN for the Jenkins EC2 instance"
  value       = module.iam.jenkins_role_arn
}

output "jenkins_instance_profile_name" {
  description = "IAM instance profile name for the Jenkins EC2 instance"
  value       = module.iam.jenkins_instance_profile_name
}

###############################################################################
# Root Outputs — Part 3: EKS
###############################################################################

output "eks_cluster_name" {
  description = "EKS cluster name — used by 'aws eks update-kubeconfig' and the Jenkinsfile Helm deploy stage"
  value       = module.eks.cluster_name
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint URL"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "Running Kubernetes minor version"
  value       = module.eks.cluster_version
}

output "eks_oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for this cluster, needed for any IRSA role added later (cluster-autoscaler, ALB controller, etc.)"
  value       = module.eks.oidc_provider_arn
}

output "eks_node_group_status" {
  description = "Current status of the managed node group — check this is ACTIVE before assuming nodes are Ready in Kubernetes"
  value       = module.eks.node_group_status
}

output "eks_kubeconfig_command" {
  description = "Run this locally after apply to configure kubectl against the new cluster"
  value       = module.eks.kubeconfig_command
}

###############################################################################
# Root Outputs — Part 4: Jenkins EC2
###############################################################################

output "jenkins_instance_id" {
  description = "EC2 instance ID of the Jenkins host"
  value       = module.ec2_jenkins.instance_id
}

output "jenkins_public_ip" {
  description = "Stable public (Elastic) IP of the Jenkins host — use for GitHub webhook URLs, since it survives instance restarts"
  value       = module.ec2_jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins web UI URL, reachable once Phase 2 (Ansible) installs and starts Jenkins on this host"
  value       = module.ec2_jenkins.jenkins_url
}

output "jenkins_ssh_command" {
  description = "SSH command for the Jenkins host, if jenkins_ssh_public_key was set. Null otherwise — use jenkins_ssm_command instead."
  value       = module.ec2_jenkins.ssh_command
}

output "jenkins_ssm_command" {
  description = "SSM Session Manager command for the Jenkins host — works regardless of whether an SSH key was configured"
  value       = module.ec2_jenkins.ssm_command
}

###############################################################################
# Root Outputs — Part 5: RDS & Secrets Manager
###############################################################################

output "db_host" {
  description = "RDS hostname — use in DATABASE_URL construction or pass to application config"
  value       = module.rds.db_host
}

output "db_endpoint" {
  description = "RDS connection endpoint including port (host:5432)"
  value       = module.rds.db_endpoint
}

output "db_name" {
  description = "Name of the application database on the RDS instance"
  value       = module.rds.db_name
}

output "db_instance_id" {
  description = "RDS instance identifier — use in AWS console or CLI for maintenance tasks"
  value       = module.rds.db_instance_id
}

output "db_credentials_secret_name" {
  description = "Secrets Manager secret name holding DB credentials — retrieve with: aws secretsmanager get-secret-value --secret-id <this>"
  value       = module.secrets_manager.db_credentials_secret_name
}

output "rds_endpoint_secret_name" {
  description = "Secrets Manager secret name holding the RDS host and port"
  value       = module.rds.rds_endpoint_secret_name
}

###############################################################################
# Root Outputs — Part 6: ECR, S3, AWS Backup
###############################################################################

output "ecr_repository_urls" {
  description = "Map of ECR repository name to full URL — use in Jenkinsfile docker build/push steps and Helm values.image.repository"
  value       = module.ecr.repository_urls
}

output "ecr_login_command" {
  description = "Run this on the Jenkins host to authenticate Docker to ECR before pushing images"
  value       = module.ecr.login_command
}

output "alb_logs_bucket_id" {
  description = "S3 bucket name for ALB access logs — reference this in the ALB access_logs block when the ALB is created in Phase 4 (Kubernetes / Helm)"
  value       = module.s3.alb_logs_bucket_id
}

output "backup_vault_name" {
  description = "AWS Backup vault name — use this when triggering manual on-demand backups"
  value       = module.backup.vault_name
}

output "backup_plan_id" {
  description = "AWS Backup plan ID"
  value       = module.backup.plan_id
}

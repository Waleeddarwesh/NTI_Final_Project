###############################################################################
# General Project Variables
###############################################################################

variable "project_name" {
  description = "Short name used as a prefix for all resource names and tags"
  type        = string
  default     = "nti-devops"
}

variable "environment" {
  description = "Deployment environment identifier (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy all resources into"
  type        = string
  default     = "us-east-1"
}

###############################################################################
# VPC / Networking Variables
###############################################################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to spread subnets across. Must have at least 2 for EKS/RDS multi-AZ requirements."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ, same order as availability_zones"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ, same order as availability_zones"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "single_nat_gateway" {
  description = "If true, creates a single NAT Gateway shared across all private subnets (cheaper, less resilient). If false, creates one NAT Gateway per AZ."
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC (required for EKS)"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC (required for EKS)"
  type        = bool
  default     = true
}

###############################################################################
# Security & IAM Variables
###############################################################################

variable "jenkins_allowed_cidrs" {
  description = "CIDR blocks allowed to reach Jenkins SSH (22) and UI (8080). SECURITY: defaults to 0.0.0.0/0 for initial bring-up only — set this to your office/VPN CIDR before any real use, especially before Part 4 stands up the actual Jenkins host."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

###############################################################################
# EKS Variables
###############################################################################

variable "eks_kubernetes_version" {
  description = "Kubernetes minor version for the EKS cluster. Defaults to 1.34 (AL2023 node AMIs, well inside standard support as of mid-2026). Check https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html before changing — EKS only allows upgrading one minor version at a time."
  type        = string
  default     = "1.34"
}

variable "eks_additional_admin_principal_arns" {
  description = "Extra IAM principal ARNs to grant cluster-admin EKS access entries, beyond the Terraform-applying identity (auto-granted) and the Jenkins role (auto-granted). Add your own IAM user/role ARN here for direct kubectl access while building this out, e.g. [\"arn:aws:iam::123456789012:user/yourname\"]."
  type        = list(string)
  default     = []
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for the EKS managed node group, in priority order"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_capacity_type" {
  description = "ON_DEMAND or SPOT for the managed node group"
  type        = string
  default     = "ON_DEMAND"
}

variable "eks_node_disk_size_gb" {
  description = "Root EBS volume size in GB for each worker node"
  type        = number
  default     = 30
}

variable "eks_node_desired_size" {
  description = "Desired number of worker nodes at cluster creation. Ignored on subsequent applies once the cluster autoscaler (Phase 4+) starts managing this."
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum number of worker nodes for autoscaling"
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Maximum number of worker nodes for autoscaling"
  type        = number
  default     = 4
}

variable "eks_endpoint_public_access" {
  description = "Whether the EKS API server endpoint is reachable from outside the VPC. True by default for ease of access during initial setup."
  type        = bool
  default     = true
}

variable "eks_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint. SECURITY: defaults to 0.0.0.0/0 for initial bring-up — restrict this before any real use, same caveat as jenkins_allowed_cidrs above."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

###############################################################################
# Jenkins EC2 Variables
###############################################################################

variable "jenkins_instance_type" {
  description = "EC2 instance type for the Jenkins host. Defaults to t3.large since this single host runs builds (Docker, SonarQube, Trivy) in addition to the Jenkins controller itself, not just the UI."
  type        = string
  default     = "t3.large"
}

variable "jenkins_root_volume_size_gb" {
  description = "Root EBS volume size in GB for the Jenkins host. Sized above typical defaults because Jenkins workspaces, Docker layers, and build caches accumulate quickly."
  type        = number
  default     = 50
}

variable "jenkins_ssh_public_key" {
  description = "SSH public key material for EC2 key pair access to Jenkins (e.g. contents of ~/.ssh/id_ed25519.pub). Generate this OUTSIDE Terraform — never paste a private key here. Leave as null (the default) to skip SSH entirely and use 'aws ssm start-session' instead, which works regardless of this setting since the SSM managed policy is always attached to the Jenkins role."
  type        = string
  default     = null
}

###############################################################################
# RDS Variables
###############################################################################

variable "db_engine_version" {
  description = "PostgreSQL major version for the RDS instance. Defaults to 16 (multi-year standard support, full Django/extension ecosystem maturity as of mid-2026). PostgreSQL 13 reached end of standard support February 2026 — don't use 13 or earlier."
  type        = string
  default     = "16"
}

variable "db_instance_class" {
  description = "RDS instance class. db.t3.micro is free-tier eligible; consider db.t3.small or db.t3.medium for better query performance."
  type        = string
  default     = "db.t3.micro"
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

variable "db_allocated_storage_gb" {
  description = "Initial allocated storage in GB for the RDS instance"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage_gb" {
  description = "Maximum storage RDS may autoscale to, in GB. Set to 0 to disable autoscaling."
  type        = number
  default     = 100
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment for RDS automatic failover. False by default for dev; set to true for production."
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Number of days to retain automated RDS backups. 0 disables backups."
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Prevent accidental deletion of the RDS instance. Defaults to true — set to false only when explicitly destroying."
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Skip the final snapshot when the RDS instance is destroyed. Set to false in production."
  type        = bool
  default     = false
}

###############################################################################
# Secrets Manager Variables
###############################################################################

variable "db_password_length" {
  description = "Length of the generated DB master password stored in Secrets Manager"
  type        = number
  default     = 32
}

variable "secrets_recovery_window_days" {
  description = "Days Secrets Manager retains a deleted secret before permanent deletion. Set to 0 in dev to avoid name-collision errors when re-creating secrets during testing."
  type        = number
  default     = 7
}

###############################################################################
# ECR Variables
###############################################################################

variable "ecr_repository_names" {
  description = "List of ECR repository names to create (the module prepends project_name). Add more for multi-service setups, e.g. [\"app\", \"worker\", \"nginx\"]."
  type        = list(string)
  default     = ["app"]
}

variable "ecr_image_tag_mutability" {
  description = "MUTABLE (default, easier for dev with latest/branch tags) or IMMUTABLE (better auditability, a tag always points to the same digest)."
  type        = string
  default     = "MUTABLE"
}

variable "ecr_scan_on_push" {
  description = "Enable ECR basic scanning on push (free, catches known OS CVEs independently of the Trivy scan in Phase 6)."
  type        = bool
  default     = true
}

variable "ecr_untagged_image_retention_days" {
  description = "Days to retain untagged images before ECR deletes them. Untagged images accumulate from every push that replaces a mutable tag."
  type        = number
  default     = 14
}

variable "ecr_tagged_image_count_limit" {
  description = "Maximum number of tagged images to retain per ECR repository before the oldest are deleted."
  type        = number
  default     = 30
}

###############################################################################
# S3 Variables
###############################################################################

variable "alb_logs_retention_days" {
  description = "Days to retain ALB access logs in S3 before automatic deletion."
  type        = number
  default     = 90
}

variable "s3_force_destroy" {
  description = "Allow Terraform to delete the ALB logs S3 bucket even when it contains objects. False by default — set to true only during dev iteration where losing ALB logs is acceptable."
  type        = bool
  default     = false
}

###############################################################################
# AWS Backup Variables
###############################################################################

variable "backup_daily_hour_utc" {
  description = "Hour (UTC, 0-23) at which the daily AWS Backup window starts. Default 2 (02:00 UTC) avoids conflict with RDS maintenance (Mon 04:00 UTC) and RDS backup window (03:00 UTC)."
  type        = number
  default     = 2
}

variable "backup_retention_days" {
  description = "Days to retain backup recovery points in the AWS Backup vault."
  type        = number
  default     = 35
}

variable "backup_vault_kms_key_arn" {
  description = "KMS key ARN to encrypt the backup vault. Null uses the AWS managed key. Supply a CMK ARN for stricter key control."
  type        = string
  default     = null
}

###############################################################################
# Tagging
###############################################################################

variable "extra_tags" {
  description = "Additional tags to apply to all taggable resources, merged on top of default_tags"
  type        = map(string)
  default     = {}
}

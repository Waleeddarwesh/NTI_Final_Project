###############################################################################
# Example variable values for Parts 1-4 (VPC, Security Groups, IAM, EKS,
# Jenkins EC2)
#
# Copy/rename this file is NOT required — terraform.tfvars is loaded
# automatically by `terraform plan`/`apply`. Edit values below to match your
# AWS account before running `terraform apply`.
###############################################################################

project_name = "nti-devops"
environment  = "dev"
aws_region   = "us-east-1"

vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

single_nat_gateway = true # set to false for production multi-AZ NAT resilience

# CHANGE THIS before applying outside of initial testing — see description
# in variables.tf. Example for restricting to a single office IP:
#   jenkins_allowed_cidrs = ["203.0.113.42/32"]
jenkins_allowed_cidrs = ["0.0.0.0/0"]

eks_kubernetes_version = "1.34"

# Add your own IAM user/role ARN here to get direct kubectl access, e.g.:
#   eks_additional_admin_principal_arns = ["arn:aws:iam::123456789012:user/yourname"]
eks_additional_admin_principal_arns = []

eks_node_instance_types = ["t3.medium"]
eks_node_capacity_type  = "ON_DEMAND"
eks_node_disk_size_gb   = 30
eks_node_desired_size   = 2
eks_node_min_size       = 2
eks_node_max_size       = 4

eks_endpoint_public_access = true
# CHANGE THIS before applying outside of initial testing, same caveat as
# jenkins_allowed_cidrs above.
eks_endpoint_public_access_cidrs = ["0.0.0.0/0"]

jenkins_instance_type       = "t3.large"
jenkins_root_volume_size_gb = 50

# Run `ssh-keygen -t ed25519 -f ~/.ssh/nti-devops-jenkins -C jenkins` locally
# first, then paste the CONTENTS of the .pub file here (never the private
# key). Leave as null to skip SSH and use SSM Session Manager instead —
# that path always works regardless of this setting.
#   jenkins_ssh_public_key = "ssh-ed25519 AAAA... jenkins"
jenkins_ssh_public_key = null

# ---------------------------------------------------------------------------
# RDS
# ---------------------------------------------------------------------------
db_engine_version           = "16"
db_instance_class           = "db.t3.micro"
db_name                     = "appdb"
db_username                 = "appuser"
db_allocated_storage_gb     = 20
db_max_allocated_storage_gb = 100
db_multi_az                 = false # true for production
db_backup_retention_days    = 7
db_deletion_protection      = true
db_skip_final_snapshot      = false

# ---------------------------------------------------------------------------
# Secrets Manager
# ---------------------------------------------------------------------------
db_password_length           = 32
# Set to 0 during dev iteration to avoid "secret still in recovery" errors
# when re-creating secrets. Set to 7–30 in production.
secrets_recovery_window_days = 7

# ---------------------------------------------------------------------------
# ECR
# ---------------------------------------------------------------------------
ecr_repository_names              = ["app"]
ecr_image_tag_mutability          = "MUTABLE"  # switch to IMMUTABLE for production
ecr_scan_on_push                  = true
ecr_untagged_image_retention_days = 14
ecr_tagged_image_count_limit      = 30

# ---------------------------------------------------------------------------
# S3 (ALB logs)
# ---------------------------------------------------------------------------
alb_logs_retention_days = 90
# Set to true only during dev iteration — never in production
s3_force_destroy = false

# ---------------------------------------------------------------------------
# AWS Backup
# ---------------------------------------------------------------------------
backup_daily_hour_utc    = 2     # 02:00 UTC — before RDS backup window (03:00)
backup_retention_days    = 35
backup_vault_kms_key_arn = null  # null = AWS managed key; supply CMK ARN for production

extra_tags = {
  Owner = "devops-team"
}

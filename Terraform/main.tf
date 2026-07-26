###############################################################################
# Root Module — Phase 1 Complete: VPC, Security Groups, IAM, EKS,
#               Jenkins EC2, RDS, Secrets Manager, ECR, S3, AWS Backup
###############################################################################

module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  environment  = var.environment

  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  single_nat_gateway    = var.single_nat_gateway
  enable_dns_hostnames  = var.enable_dns_hostnames
  enable_dns_support    = var.enable_dns_support

  extra_tags = var.extra_tags
}

module "security_groups" {
  source = "./modules/security-groups"

  project_name = var.project_name
  environment  = var.environment

  vpc_id                = module.vpc.vpc_id
  jenkins_allowed_cidrs = var.jenkins_allowed_cidrs

  extra_tags = var.extra_tags
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment

  extra_tags = var.extra_tags
}

module "eks" {
  source = "./modules/eks"

  project_name = var.project_name
  environment  = var.environment

  kubernetes_version = var.eks_kubernetes_version
  private_subnet_ids = module.vpc.private_subnet_ids

  cluster_security_group_id = module.security_groups.eks_cluster_security_group_id
  node_security_group_id    = module.security_groups.eks_nodes_security_group_id

  cluster_role_arn = module.iam.eks_cluster_role_arn
  node_role_arn    = module.iam.eks_node_role_arn
  jenkins_role_arn = module.iam.jenkins_role_arn

  additional_admin_principal_arns = var.eks_additional_admin_principal_arns

  node_instance_types = var.eks_node_instance_types
  node_capacity_type  = var.eks_node_capacity_type
  node_disk_size_gb   = var.eks_node_disk_size_gb
  node_desired_size   = var.eks_node_desired_size
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size

  endpoint_public_access       = var.eks_endpoint_public_access
  endpoint_public_access_cidrs = var.eks_endpoint_public_access_cidrs

  extra_tags = var.extra_tags
}

module "ec2_jenkins" {
  source = "./modules/ec2-jenkins"

  project_name = var.project_name
  environment  = var.environment

  # Single instance in the first public subnet — Jenkins here is one host,
  # not a multi-AZ fleet, so this deliberately doesn't spread across AZs.
  public_subnet_id = module.vpc.public_subnet_ids[0]

  jenkins_security_group_id     = module.security_groups.jenkins_security_group_id
  jenkins_instance_profile_name = module.iam.jenkins_instance_profile_name

  eks_cluster_name = module.eks.cluster_name

  instance_type        = var.jenkins_instance_type
  root_volume_size_gb = var.jenkins_root_volume_size_gb
  ssh_public_key        = var.jenkins_ssh_public_key

  extra_tags = var.extra_tags
}

module "secrets_manager" {
  source = "./modules/secrets-manager"

  project_name = var.project_name
  environment  = var.environment

  db_name     = var.db_name
  db_username = var.db_username
  db_port     = 5432

  password_length      = var.db_password_length
  recovery_window_days = var.secrets_recovery_window_days

  extra_tags = var.extra_tags
}

module "rds" {
  source = "./modules/rds"

  project_name = var.project_name
  environment  = var.environment

  private_subnet_ids    = module.vpc.private_subnet_ids
  rds_security_group_id = module.security_groups.rds_security_group_id

  # Clean one-way dependency: secrets_manager generates password → rds uses it.
  # The RDS endpoint secret (host/port) lives inside the rds module itself to
  # avoid the reverse dependency (rds host → secrets_manager → cycle error).
  db_password = module.secrets_manager.db_password

  engine_version = var.db_engine_version
  instance_class = var.db_instance_class
  db_name        = var.db_name
  db_username    = var.db_username

  allocated_storage_gb     = var.db_allocated_storage_gb
  max_allocated_storage_gb = var.db_max_allocated_storage_gb

  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
  deletion_protection   = var.db_deletion_protection
  skip_final_snapshot   = var.db_skip_final_snapshot

  extra_tags = var.extra_tags
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment

  repository_names              = var.ecr_repository_names
  image_tag_mutability          = var.ecr_image_tag_mutability
  scan_on_push                  = var.ecr_scan_on_push
  untagged_image_retention_days = var.ecr_untagged_image_retention_days
  tagged_image_count_limit      = var.ecr_tagged_image_count_limit

  extra_tags = var.extra_tags
}

module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment

  alb_logs_retention_days = var.alb_logs_retention_days
  force_destroy           = var.s3_force_destroy

  extra_tags = var.extra_tags
}

module "backup" {
  source = "./modules/backup"

  project_name = var.project_name
  environment  = var.environment

  rds_instance_arn = module.rds.db_instance_arn
  eks_cluster_arn  = module.eks.cluster_arn

  daily_backup_hour_utc = var.backup_daily_hour_utc
  backup_retention_days = var.backup_retention_days
  vault_kms_key_arn     = var.backup_vault_kms_key_arn

  extra_tags = var.extra_tags
}

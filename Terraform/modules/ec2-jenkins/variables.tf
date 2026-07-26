variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment identifier used in resource naming"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID to launch the Jenkins instance into. Public placement is intentional here — it matches the security-groups module (Part 2), which opens SSH/UI to jenkins_allowed_cidrs as an external CIDR list, not a VPC-internal source."
  type        = string
}

variable "jenkins_security_group_id" {
  description = "Security group ID for the Jenkins instance (from the security-groups module)"
  type        = string
}

variable "jenkins_instance_profile_name" {
  description = "IAM instance profile name for the Jenkins instance (from the iam module)"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name (from the eks module), baked into user-data so kubectl is pre-configured against the right cluster once installed"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the Jenkins host. Defaults to t3.large rather than t3.medium: this single host runs the Jenkins controller AND executes builds (Docker builds, SonarQube scans, Trivy scans) per the original project plan, which is heavier than a UI-only controller."
  type        = string
  default     = "t3.large"
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GB. Jenkins workspaces, Docker images/layers, and build caches accumulate fast — sized well above the EKS node default for that reason."
  type        = number
  default     = 50
}

variable "ssh_public_key" {
  description = "SSH public key material (e.g. contents of ~/.ssh/id_ed25519.pub) for EC2 key pair access. Generate this OUTSIDE Terraform (ssh-keygen) and pass only the public half in — never generate the private key inside Terraform, since it would be stored unencrypted in state. Leave as null to skip creating a key pair entirely and rely on SSM Session Manager instead (this module grants the SSM managed policy either way)."
  type        = string
  default     = null
}

variable "extra_tags" {
  description = "Additional tags merged onto every resource in this module"
  type        = map(string)
  default     = {}
}

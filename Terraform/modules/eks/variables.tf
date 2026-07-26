variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment identifier used in resource naming"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes minor version for the EKS cluster (e.g. \"1.34\"). Check current standard-support versions before changing: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html — EKS only allows upgrading one minor version at a time, so picking a version close to EOL creates near-term upgrade pressure."
  type        = string
  default     = "1.34"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs the EKS control plane ENIs and worker nodes will be placed in. Worker nodes are deliberately NOT placed in public subnets."
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "Security group ID to attach to the EKS control plane (from the security-groups module)"
  type        = string
}

variable "node_security_group_id" {
  description = "Security group ID to attach to EKS worker nodes (from the security-groups module)"
  type        = string
}

variable "cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane (from the iam module)"
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN for EKS worker nodes (from the iam module). Required for the access-entry grant; the actual node group attaches the instance profile separately."
  type        = string
}

variable "node_instance_profile_name" {
  description = "Unused directly by this module — managed node groups do not take an instance profile, they take node_role_arn and EKS creates/attaches the profile itself. Kept as a variable for interface symmetry with the iam module's outputs and to avoid breaking root wiring if a self-managed node group is added later."
  type        = string
  default     = null
}

variable "jenkins_role_arn" {
  description = "IAM role ARN for the Jenkins EC2 instance (from the iam module). Granted an EKS access entry so Jenkins can run kubectl/Helm against this cluster — without this, Jenkins can authenticate to the EKS API (DescribeCluster) but cannot deploy anything to it."
  type        = string
}

variable "additional_admin_principal_arns" {
  description = "Extra IAM principal ARNs (e.g. your own IAM user, for kubectl access while building this out) to grant cluster-admin access entries. Defaults to empty — add your own ARN here if you want kubectl access from outside Jenkins."
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group, in priority order"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_disk_size_gb" {
  description = "Root EBS volume size in GB for each worker node"
  type        = number
  default     = 30
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes for autoscaling"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes for autoscaling"
  type        = number
  default     = 4
}

variable "enable_cluster_log_types" {
  description = "EKS control plane log types to ship to CloudWatch Logs. api/audit are the most valuable for security review; the rest add volume fast."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "endpoint_public_access" {
  description = "Whether the EKS API server endpoint is reachable from outside the VPC. True by default so kubectl/Jenkins/CI can reach it without a bastion or VPN; combine with endpoint_public_access_cidrs to restrict who."
  type        = bool
  default     = true
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint, when endpoint_public_access is true. SECURITY: defaults to 0.0.0.0/0 for initial bring-up — restrict this in any real deployment, same caveat as jenkins_allowed_cidrs in the security-groups module."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "extra_tags" {
  description = "Additional tags merged onto every resource in this module"
  type        = map(string)
  default     = {}
}

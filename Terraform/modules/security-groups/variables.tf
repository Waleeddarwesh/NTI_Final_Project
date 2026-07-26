variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment identifier used in resource naming"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC these security groups belong to"
  type        = string
}

variable "jenkins_allowed_cidrs" {
  description = "CIDR blocks allowed to reach Jenkins UI (8080) and SSH (22). Restrict this to your office/VPN IP in production — do not leave as 0.0.0.0/0 outside of initial testing."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "extra_tags" {
  description = "Additional tags merged onto every resource in this module"
  type        = map(string)
  default     = {}
}

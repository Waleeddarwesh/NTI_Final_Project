variable "project_name" {
  description = "Project name used in resource naming and image repository paths"
  type        = string
}

variable "environment" {
  description = "Environment identifier used in resource naming"
  type        = string
}

variable "repository_names" {
  description = "List of ECR repository names to create (relative names; the module prepends project_name). Defaults to [\"app\"] for a single Django application image. Add more here for multi-service setups (e.g. [\"app\", \"worker\", \"nginx\"])."
  type        = list(string)
  default     = ["app"]
}

variable "image_tag_mutability" {
  description = "MUTABLE allows overwriting existing tags (convenient for latest/branch tags). IMMUTABLE prevents tag overwrites (stronger auditability — a tag always points to the same digest). IMMUTABLE is the better production default; MUTABLE is easier during initial development."
  type        = string
  default     = "MUTABLE"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE"
  }
}

variable "scan_on_push" {
  description = "Enable ECR basic scanning on image push (free). Trivy in the Jenkins pipeline (Phase 6) provides deeper scanning, but ECR's built-in scan catches known OS CVEs without needing any pipeline to run first."
  type        = bool
  default     = true
}

variable "untagged_image_retention_days" {
  description = "Number of days to retain untagged images before ECR deletes them. Untagged images accumulate from every push that replaces a tag; without this they pile up indefinitely and cost real money."
  type        = number
  default     = 14
}

variable "tagged_image_count_limit" {
  description = "Maximum number of tagged images to retain per repository, beyond which the oldest are deleted. Guards against unbounded repository growth from long-running CI systems."
  type        = number
  default     = 30
}

variable "extra_tags" {
  description = "Additional tags merged onto every resource in this module"
  type        = map(string)
  default     = {}
}

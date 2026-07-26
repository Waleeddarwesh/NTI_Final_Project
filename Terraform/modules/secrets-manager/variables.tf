variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment identifier used in resource naming"
  type        = string
}

variable "db_name" {
  description = "Database name — stored in the secret so the application can read it alongside credentials"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Database master username — stored in the secret alongside the generated password"
  type        = string
  default     = "appuser"
}

variable "db_port" {
  description = "RDS port — stored in the secret for application use"
  type        = number
  default     = 5432
}

variable "password_length" {
  description = "Length of the generated DB master password"
  type        = number
  default     = 32
}

variable "recovery_window_days" {
  description = "Number of days Secrets Manager retains a deleted secret before permanent deletion. 0 means immediate permanent deletion (useful in dev to avoid name-collision errors when re-creating). 7–30 is safer for production."
  type        = number
  default     = 7
}

variable "extra_tags" {
  description = "Additional tags merged onto every resource in this module"
  type        = map(string)
  default     = {}
}

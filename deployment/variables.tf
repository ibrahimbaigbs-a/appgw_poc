variable "environment" {
  description = "Environment folder name under env (for example: Prod)."
  type        = string
  default     = "Prod"
}

variable "appcode" {
  description = "Application code folder name under env/<environment>/ (for example: App-001)."
  type        = string
  default     = "App-001"
}

variable "instance" {
  description = "App gateway pair folder name under the app code folder (for example: appgw-01). One Terraform run = one resilient pair."
  type        = string
  default     = "appgw-01"
}

variable "role" {
  description = "Gateway role to deploy within an instance folder: p (primary), s (secondary), or both."
  type        = string
  default     = "both"

  validation {
    condition     = contains(["p", "s", "both"], lower(var.role))
    error_message = "role must be one of: p, s, both."
  }
}

variable "env_root_path" {
  description = "Path to the env directory, relative to this deployment folder."
  type        = string
  default     = "../env"
}

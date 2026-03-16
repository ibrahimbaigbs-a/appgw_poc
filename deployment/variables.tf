variable "environment" {
  description = "Environment folder name under env (for example: Prod)."
  type        = string
  default     = "Prod"
}

variable "region" {
  description = "Region folder name under env/<environment>/Region (for example: Westus-2)."
  type        = string
  default     = "Westus-2"
}

variable "instance" {
  description = "App gateway pair folder name under the region folder (for example: appgw-01). One Terraform run = one resilient pair."
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

# ===============================================================================
# User ODAA Module - Variables
# ===============================================================================

variable "user_index" {
  description = "Index of the user (0-24)"
  type        = number

  validation {
    condition     = var.user_index >= 0 && var.user_index <= 24
    error_message = "user_index must be between 0 and 24"
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ===============================================================================
# RBAC: Entra ID User Access
# ===============================================================================

variable "entra_id_user_object_id" {
  description = "Entra ID user object ID to grant Oracle Database Creator on the ODAA resource group (null = skip)"
  type        = string
  default     = null
}

variable "odaa_role_definition_id" {
  description = "Role definition resource ID for the Oracle Database Creator custom role (null = skip RBAC)"
  type        = string
  default     = null
}


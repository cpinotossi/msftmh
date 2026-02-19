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

variable "vnet_cidr" {
  description = "CIDR block for the ODAA VNet (e.g., 192.168.0.0/16)"
  type        = string
  default     = "192.168.0.0/16"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

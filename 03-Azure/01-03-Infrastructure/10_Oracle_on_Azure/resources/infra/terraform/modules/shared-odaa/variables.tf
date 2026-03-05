# ===============================================================================
# Shared ODAA Module - Variables
# ===============================================================================

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "vnet_cidr" {
  description = "CIDR block for the shared ODAA VNet (e.g., 192.168.0.0/16)"
  type        = string
  default     = "192.168.0.0/16"
}

variable "basedb_vnet_cidr" {
  description = "CIDR block for the shared BaseDB VNet (e.g., 172.16.0.0/16)"
  type        = string
  default     = "172.16.0.0/16"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

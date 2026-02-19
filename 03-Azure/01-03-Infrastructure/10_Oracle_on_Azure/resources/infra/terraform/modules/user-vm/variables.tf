# ===============================================================================
# User VM Module - Variables
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
  description = "CIDR block for the VM VNet (e.g., 10.0.0.0/16)"
  type        = string
}

variable "vm_size" {
  description = "Size of the VM"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "vm_image_id" {
  description = "ID of the VM image from Compute Gallery (null = use Ubuntu default)"
  type        = string
  default     = null
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "os_disk_type" {
  description = "OS disk type (Standard_LRS, StandardSSD_LRS, Premium_LRS)"
  type        = string
  default     = "Standard_LRS"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 128
}

variable "create_public_ip" {
  description = "Create a public IP for direct SSH access"
  type        = bool
  default     = true
}

variable "dns_zone_id" {
  description = "ID of the Private DNS Zone for ODAA (optional)"
  type        = string
  default     = null
}

variable "dns_zone_name" {
  description = "Name of the Private DNS Zone for ODAA"
  type        = string
  default     = null
}

variable "dns_zone_resource_group" {
  description = "Resource group containing the Private DNS Zone"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ===============================================================================
# Shared Module - Variables
# ===============================================================================

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "workshop"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "gallery_name" {
  description = "Name of the Azure Compute Gallery"
  type        = string
  default     = "gal_oracle_workshop"
}

variable "image_name" {
  description = "Name of the image definition"
  type        = string
  default     = "oracle-workshop-vm"
}

variable "create_ssh_key" {
  description = "Create SSH key pair (set false when SSH is managed elsewhere)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

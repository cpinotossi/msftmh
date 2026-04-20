# ===============================================================================
# Variable Definitions - Shared Infrastructure
# ===============================================================================

# ===============================================================================
# Azure Authentication
# ===============================================================================

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

# ===============================================================================
# Subscription Configuration
# ===============================================================================

variable "gallery_subscription_id" {
  description = "Azure subscription ID for the Compute Gallery (sub-mhcore)"
  type        = string
}

variable "odaa_subscription_id" {
  description = "Azure subscription ID for ODAA shared VNet, anchors (sub-mhodaa)"
  type        = string
}

# ===============================================================================
# Location
# ===============================================================================

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "francecentral"

  validation {
    condition     = contains(["francecentral", "germanywestcentral"], lower(trimspace(var.location)))
    error_message = "location must be either 'francecentral' or 'germanywestcentral'."
  }
}

# ===============================================================================
# Compute Gallery
# ===============================================================================

variable "gallery_name" {
  description = "Name of the Azure Compute Gallery"
  type        = string
  default     = "gal_oracle_workshop"
}

variable "image_name" {
  description = "Name of the VM image definition"
  type        = string
  default     = "oracle-workshop-vm"
}

# ===============================================================================
# ODAA Configuration
# ===============================================================================

variable "odaa_vnet_cidr" {
  description = "CIDR block for the shared ODAA VNet (ADB)"
  type        = string
  default     = "192.168.0.0/16"
}

variable "basedb_vnet_cidr" {
  description = "CIDR block for the shared BaseDB VNet"
  type        = string
  default     = "172.16.0.0/16"
}

variable "odaa_user_group_id" {
  description = "Object ID of the Entra ID group (mh-odaa-user-grp) for shared ODAA RBAC"
  type        = string
}

# ===============================================================================
# Tags
# ===============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "OracleWorkshop"
    ManagedBy = "Terraform"
  }
}

# ===============================================================================
# Variable Definitions - Simplified Oracle on Azure Infrastructure
# ===============================================================================

# ===============================================================================
# Azure Authentication
# ===============================================================================

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "client_id" {
  description = "Service Principal client ID"
  type        = string
}

variable "client_secret" {
  description = "Service Principal client secret"
  type        = string
  sensitive   = true
}

# ===============================================================================
# Subscription Configuration (3 Subscriptions)
# ===============================================================================

variable "gallery_subscription_id" {
  description = "Azure subscription ID for the Compute Gallery (sub-mhcore)"
  type        = string
}

variable "vm_subscription_id" {
  description = "Azure subscription ID for Workshop VMs, VNets, DNS (sub-mh0)"
  type        = string
}

variable "odaa_subscription_id" {
  description = "Azure subscription ID for ODAA shared VNet, anchors, user RGs (sub-mhodaa)"
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
# VM Configuration
# ===============================================================================

variable "vm_size" {
  description = "Size of the workshop VMs"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "vm_os_disk_type" {
  description = "OS disk type for VMs (Standard_LRS, StandardSSD_LRS, Premium_LRS)"
  type        = string
  default     = "Standard_LRS"
}

variable "vm_os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 128
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "create_public_ip" {
  description = "Create public IPs for VMs (for direct SSH access)"
  type        = bool
  default     = true
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

variable "vm_image_version" {
  description = "Version of the VM image to use (null = use Ubuntu default)"
  type        = string
  default     = null
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

variable "odaa_dns_zone_name" {
  description = "Private DNS zone name for Oracle ODAA"
  type        = string
  default     = "adb.eu-paris-1.oraclecloud.com"
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

# ===============================================================================
# Entra ID (Azure AD) Login Configuration
# ===============================================================================

variable "enable_entra_id_login" {
  description = "Enable Entra ID (Azure AD) login for VMs"
  type        = bool
  default     = true
}

variable "entra_id_admin_login" {
  description = "Grant admin (sudo) access to Entra ID users"
  type        = bool
  default     = false
}

# User Object IDs for Entra ID login (one per user)
# These are the Entra ID user object IDs who will have access to each VM

variable "user_object_ids" {
  description = "Map of user index to Entra ID user object ID"
  type        = map(string)
  default     = {}
  # Example:
  # {
  #   "00" = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  #   "01" = "ffffffff-gggg-hhhh-iiii-jjjjjjjjjjjj"
  #   ...
  # }
}

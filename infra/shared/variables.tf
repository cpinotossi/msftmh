# ===============================================================================
# Variable Definitions - Shared Infrastructure
# ===============================================================================

# ===============================================================================
# Azure Authentication
# ===============================================================================

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
  default     = "8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5"
}

# ===============================================================================
# Subscription Configuration
# ===============================================================================

variable "mhcore_subscription_id" {
  description = "Workshop subscription for the hub, DNS, gallery and all user spokes"
  type        = string
  default     = "aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483"
}

variable "mhodaa_subscription_id" {
  description = "Azure subscription ID for ODAA shared VNet, anchors (sub-mhodaa)"
  type        = string
  default     = "4ce5b5cc-e869-451f-98fc-f50448849ee0"
}

variable "use_msi" {
  description = "Use managed identity in CI; false uses the signed-in Azure CLI account"
  type        = bool
  default     = false
}

variable "tf_state_storage" {
  description = "Workshop subscription storage account containing identity.tfstate"
  type        = string
}

variable "tf_state_rg" {
  description = "Resource group containing the Terraform state storage account"
  type        = string
}

variable "tf_state_container" {
  type    = string
  default = "tfstate"
}

variable "hub_vnet_cidr" {
  type    = string
  default = "10.100.0.0/16"
}

variable "user_count" {
  type    = number
  default = 7

  validation {
    condition     = var.user_count >= 0 && var.user_count <= 25 && floor(var.user_count) == var.user_count
    error_message = "user_count must be an integer between 0 and 25."
  }
}

variable "network_anchor_zone" {
  description = "Approved Azure zone for the shared Network Anchor and all BaseDB systems"
  type        = string
  default     = "1"

  validation {
    condition     = contains(["1", "2", "3"], var.network_anchor_zone)
    error_message = "network_anchor_zone must be an approved Azure zone: 1, 2 or 3."
  }
}

variable "oci_vcn_dns_label" {
  description = "DNS label provisioned on the Network Anchor's OCI VCN"
  type        = string
  default     = "mhworkshop"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,14}$", var.oci_vcn_dns_label))
    error_message = "Use a lowercase OCI DNS label beginning with a letter, at most 15 characters."
  }
}

variable "odaa_dns_zone_name" {
  description = "Centrally managed Azure private zone; never forwarded back to Oracle"
  type        = string
  default     = "basedb.workshop.internal"
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

variable "prefix" {
  description = "Prefix for shared resource names"
  type        = string
  default     = "workshop"
}

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
  description = "CIDR block for the shared ODAA VNet (Base Database)"
  type        = string
  default     = "192.168.0.0/16"
}



variable "odaa_user_group_id" {
  description = "Optional workshop group override; normally read from the new identity state"
  type        = string
  default     = null
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

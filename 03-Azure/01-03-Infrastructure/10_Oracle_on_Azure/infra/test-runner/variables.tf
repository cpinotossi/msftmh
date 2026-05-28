# ===============================================================================
# Variable Definitions - Test Runner
# ===============================================================================

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "mhcore_subscription_id" {
  description = "Azure subscription ID for shared resources (sub-mhcore)"
  type        = string
}

variable "mh0_subscription_id" {
  description = "Azure subscription ID for user VMs (sub-mh0)"
  type        = string
}

variable "mhodaa_subscription_id" {
  description = "Azure subscription ID for ODAA resources (sub-mhodaa)"
  type        = string
}

variable "tf_state_storage" {
  description = "Storage account name for remote state"
  type        = string
}

variable "tf_state_rg" {
  description = "Resource group for state storage account"
  type        = string
}

variable "tf_state_container" {
  description = "Blob container for state files"
  type        = string
  default     = "tfstate"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "francecentral"
}

variable "user_count" {
  description = "Current user count (passed from pipeline, unused — test-runner always deploys)"
  type        = number
  default     = 0
}

variable "vm_size" {
  description = "VM size for the test runner"
  type        = string
  default     = "Standard_B2s"
}

variable "vm_image_version" {
  description = "Image version from Compute Gallery"
  type        = string
  default     = "1.0.2"
}

variable "admin_username" {
  description = "Admin username for the test runner VM"
  type        = string
  default     = "azureuser"
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default = {
    Project     = "OracleWorkshop"
    ManagedBy   = "Terraform"
    Environment = "Test"
    Purpose     = "AutomatedTesting"
  }
}

# ===============================================================================
# Variable Definitions - Test Runner
# ===============================================================================

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
  default     = "8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5"
}

variable "mhcore_subscription_id" {
  description = "Azure subscription ID for shared resources (sub-mhcore)"
  type        = string
  default     = "aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483"
}

variable "mh0_subscription_id" {
  description = "Azure subscription ID for user VMs (sub-mh0)"
  type        = string
  default     = "aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483"
}

variable "mhodaa_subscription_id" {
  description = "Azure subscription ID for ODAA resources (sub-mhodaa)"
  type        = string
  default     = "4ce5b5cc-e869-451f-98fc-f50448849ee0"
}

variable "use_msi" {
  description = "Use managed identity in CI; false uses the signed-in Azure CLI"
  type        = bool
  default     = false
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

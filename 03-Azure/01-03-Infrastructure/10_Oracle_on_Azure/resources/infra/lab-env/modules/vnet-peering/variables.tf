# ===============================================================================
# VNet Peering Module - Variables
# ===============================================================================

variable "vm_vnet_id" {
  description = "The resource ID of the VM virtual network"
  type        = string
}

variable "vm_vnet_name" {
  description = "The name of the VM virtual network"
  type        = string
}

variable "vm_resource_group" {
  description = "The name of the VM resource group"
  type        = string
}

variable "odaa_vnet_id" {
  description = "The resource ID of the ODAA virtual network"
  type        = string
}

variable "odaa_vnet_name" {
  description = "The name of the ODAA virtual network"
  type        = string
}

variable "odaa_resource_group" {
  description = "The name of the ODAA resource group"
  type        = string
}

variable "peering_suffix" {
  description = "Suffix to add to peering names for uniqueness across deployments"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A mapping of tags to assign to the resources"
  type        = map(string)
  default     = {}
}
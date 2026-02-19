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

variable "odaa_dns_zone_name" {
  description = "Private DNS zone name for Oracle ODAA"
  type        = string
  default     = "adb.eu-paris-1.oraclecloud.com"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

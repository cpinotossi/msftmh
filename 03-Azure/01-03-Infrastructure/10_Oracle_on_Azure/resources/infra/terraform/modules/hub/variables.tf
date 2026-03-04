# ===============================================================================
# Hub Module - Variables
# ===============================================================================

variable "location" {
  description = "Azure region for hub resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the hub resource group"
  type        = string
  default     = "rg-hub"
}

variable "vnet_cidr_ipv4" {
  description = "IPv4 CIDR for hub VNet"
  type        = string
  default     = "10.100.0.0/16"
}

variable "vnet_cidr_ipv6" {
  description = "IPv6 CIDR for hub VNet (dual-stack)"
  type        = string
  default     = "fd00:db8:100::/48"
}

variable "ipv6_prefix_length" {
  description = "Prefix length of the IPv6 CIDR"
  type        = number
  default     = 48
}

variable "firewall_sku" {
  description = "SKU tier for Azure Firewall (Basic, Standard, Premium)"
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.firewall_sku)
    error_message = "firewall_sku must be Basic, Standard, or Premium."
  }
}

variable "availability_zones" {
  description = "Availability zones for zonal resources (empty for no zones)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all hub resources"
  type        = map(string)
  default     = {}
}

# ===============================================================================
# ExpressRoute Gateway (optional)
# ===============================================================================

variable "enable_expressroute_gateway" {
  description = "Whether to create an ExpressRoute virtual network gateway in the hub VNet"
  type        = bool
  default     = false
}

variable "expressroute_gateway_sku" {
  description = "ExpressRoute gateway SKU (e.g. ErGw1, ErGw1AZ, ErGw2AZ, ErGw3AZ)"
  type        = string
  default     = "ErGw1AZ"

  validation {
    condition     = contains(["Standard", "HighPerformance", "UltraPerformance", "ErGw1AZ", "ErGw2AZ", "ErGw3AZ", "ErGwScale"], var.expressroute_gateway_sku)
    error_message = "expressroute_gateway_sku must be one of: Standard, HighPerformance, UltraPerformance, ErGw1AZ, ErGw2AZ, ErGw3AZ, ErGwScale."
  }
}

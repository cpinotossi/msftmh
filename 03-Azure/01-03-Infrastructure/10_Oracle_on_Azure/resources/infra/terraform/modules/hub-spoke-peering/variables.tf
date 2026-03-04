# ===============================================================================
# Hub-Spoke Peering Module - Variables
# ===============================================================================

# ===============================================================================
# Hub Configuration
# ===============================================================================

variable "hub_vnet_id" {
  description = "ID of the hub VNet"
  type        = string
}

variable "hub_vnet_name" {
  description = "Name of the hub VNet"
  type        = string
}

variable "hub_resource_group" {
  description = "Resource group name of the hub VNet"
  type        = string
}

variable "hub_firewall_private_ip" {
  description = "Private IP address of the hub firewall (for UDR)"
  type        = string
}

# ===============================================================================
# Spoke Configuration
# ===============================================================================

variable "spoke_name" {
  description = "Identifier for the spoke (used in peering and route table names)"
  type        = string
}

variable "spoke_vnet_id" {
  description = "ID of the spoke VNet"
  type        = string
}

variable "spoke_vnet_name" {
  description = "Name of the spoke VNet"
  type        = string
}

variable "spoke_resource_group" {
  description = "Resource group name of the spoke VNet"
  type        = string
}

variable "spoke_subnet_id" {
  description = "ID of the spoke subnet to associate route table with"
  type        = string
}

variable "spoke_location" {
  description = "Azure region of the spoke (for route table)"
  type        = string
}

# ===============================================================================
# Peering Options
# ===============================================================================

variable "allow_gateway_transit" {
  description = "Allow gateway transit from hub to spoke"
  type        = bool
  default     = false
}

variable "use_hub_gateway" {
  description = "Use hub's gateway from spoke (requires gateway in hub)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ===============================================================================
# Routing Options
# ===============================================================================

variable "firewall_route_prefixes" {
  description = "Destination prefixes to route to the hub firewall via UDR. Defaults to forced tunneling (0.0.0.0/0). Use RFC1918 prefixes to keep Internet traffic direct (e.g., [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16])."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

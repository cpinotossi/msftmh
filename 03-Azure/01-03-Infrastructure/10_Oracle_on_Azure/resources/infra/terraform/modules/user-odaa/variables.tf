# ===============================================================================
# User ODAA Module - Variables
# ===============================================================================

variable "user_index" {
  description = "Index of the user (0-24)"
  type        = number

  validation {
    condition     = var.user_index >= 0 && var.user_index <= 24
    error_message = "user_index must be between 0 and 24"
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "vnet_cidr" {
  description = "CIDR block for the ODAA VNet (e.g., 192.168.0.0/16)"
  type        = string
  default     = "192.168.0.0/16"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ===============================================================================
# Database Type Selection
# ===============================================================================

variable "db_type" {
  description = "Type of Oracle database to create: 'none' (networking only), 'adb' (Autonomous Database), 'basedb' (Base Database on Exadata)"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "adb", "basedb"], var.db_type)
    error_message = "db_type must be one of: none, adb, basedb"
  }
}

variable "byol" {
  description = "Use Bring Your Own License (true) or License Included (false) for Oracle databases"
  type        = bool
  default     = false
}

# ===============================================================================
# ADB (Autonomous Database) Configuration
# ===============================================================================

variable "adb_admin_password" {
  description = "Admin password for Autonomous Database (required when db_type = 'adb')"
  type        = string
  default     = null
  sensitive   = true
}

variable "adb_compute_model" {
  description = "Compute model for ADB (ECPU or OCPU)"
  type        = string
  default     = "ECPU"
}

variable "adb_compute_count" {
  description = "Number of ECPUs/OCPUs for ADB"
  type        = number
  default     = 2
}

variable "adb_data_storage_size_in_tbs" {
  description = "Data storage size in TBs for ADB"
  type        = number
  default     = 1
}

variable "adb_db_version" {
  description = "Oracle DB version for ADB (e.g., 23ai, 19c)"
  type        = string
  default     = "23ai"
}

variable "adb_db_workload" {
  description = "ADB workload type: OLTP or DW"
  type        = string
  default     = "OLTP"
}

variable "adb_auto_scaling_enabled" {
  description = "Enable auto-scaling for ADB compute"
  type        = bool
  default     = false
}

variable "adb_auto_scaling_for_storage_enabled" {
  description = "Enable auto-scaling for ADB storage"
  type        = bool
  default     = false
}

variable "adb_backup_retention_period_in_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 1
}

variable "adb_character_set" {
  description = "Character set for ADB"
  type        = string
  default     = "AL32UTF8"
}

variable "adb_national_character_set" {
  description = "National character set for ADB"
  type        = string
  default     = "AL16UTF16"
}

variable "adb_mtls_connection_required" {
  description = "Require mTLS connection for ADB"
  type        = bool
  default     = false
}

# ===============================================================================
# BaseDB (Exadata) Configuration
# ===============================================================================

variable "basedb_shape" {
  description = "Shape of the Exadata Infrastructure (e.g., ExaDbXS, Exadata.X9M)"
  type        = string
  default     = "ExaDbXS"
}

variable "basedb_compute_count" {
  description = "Number of compute servers for Exadata"
  type        = number
  default     = 2
}

variable "basedb_storage_count" {
  description = "Number of storage servers for Exadata"
  type        = number
  default     = 3
}

variable "basedb_zones" {
  description = "Availability zones for Exadata (francecentral supports 1 and 2)"
  type        = list(string)
  default     = ["1"]
}

variable "basedb_cpu_core_count" {
  description = "CPU core count for Cloud VM Cluster"
  type        = number
  default     = 4
}

variable "basedb_data_storage_size_in_tbs" {
  description = "Data storage size in TBs for Cloud VM Cluster"
  type        = number
  default     = 2
}

variable "basedb_db_node_storage_size_in_gbs" {
  description = "DB node storage size in GBs"
  type        = number
  default     = 120
}

variable "basedb_memory_size_in_gbs" {
  description = "Memory size in GBs for Cloud VM Cluster"
  type        = number
  default     = 60
}

variable "basedb_gi_version" {
  description = "Grid Infrastructure version"
  type        = string
  default     = "19.0.0.0"
}

variable "basedb_ssh_public_keys" {
  description = "SSH public keys for Cloud VM Cluster access"
  type        = list(string)
  default     = []
}

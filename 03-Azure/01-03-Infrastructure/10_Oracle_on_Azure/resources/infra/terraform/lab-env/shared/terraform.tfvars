# ===============================================================================
# Terraform Variables - Shared Infrastructure
# ===============================================================================

tenant_id = "f71980b2-590a-4de9-90d5-6fbc867da951"

# ===============================================================================
# Subscription Configuration
# ===============================================================================

# Gallery Subscription (sub-mhcore) - Compute Gallery
mhcore_subscription_id = "09808f31-065f-4231-914d-776c2d6bbe34"

# ODAA Subscription (sub-mhodaa) - Shared ODAA VNet, Anchors, Role Definition
mhodaa_subscription_id = "4aecf0e8-2fe2-4187-bc93-0356bd2676f5"

# ===============================================================================
# Location
# ===============================================================================

location = "francecentral"

# ===============================================================================
# Compute Gallery
# ===============================================================================

gallery_name = "gal_oracle_workshop"
image_name   = "oracle-workshop-vm"

# ===============================================================================
# ODAA Configuration
# ===============================================================================

odaa_vnet_cidr     = "192.168.0.0/16"
basedb_vnet_cidr   = "172.16.0.0/16"

# Entra ID user group for shared ODAA RBAC (mh-odaa-user-grp)
odaa_user_group_id = "5fbc2654-d343-401a-be86-08327fe66ec2"

# ===============================================================================
# Tags
# ===============================================================================

tags = {
  Project     = "OracleWorkshop"
  ManagedBy   = "Terraform"
  Environment = "Workshop"
}

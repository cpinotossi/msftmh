# ===============================================================================
# Terraform Variables - Oracle on Azure Workshop (Simplified)
# ===============================================================================

# ===============================================================================
# Azure Authentication (via Managed Identity - no client_secret needed)
# ===============================================================================

tenant_id = "f71980b2-590a-4de9-90d5-6fbc867da951"
# client_id and client_secret not needed - using Managed Identity

# ===============================================================================
# Subscription Configuration (3 Subscriptions)
# ===============================================================================

# Gallery Subscription (sub-mhcore) - Compute Gallery
mhcore_subscription_id = "09808f31-065f-4231-914d-776c2d6bbe34"

# VM Subscription (sub-mh0) - Workshop VMs, VNets
mh0_subscription_id = "556f9b63-ebc9-4c7e-8437-9a05aa8cdb25"

# ODAA Subscription (sub-mhodaa) - Shared ODAA VNet, Anchors, User RGs
mhodaa_subscription_id = "4aecf0e8-2fe2-4187-bc93-0356bd2676f5"

# ===============================================================================
# Location
# ===============================================================================

location = "francecentral"

# ===============================================================================
# VM Configuration
# ===============================================================================

vm_size            = "Standard_D2s_v5"
vm_os_disk_type    = "Standard_LRS" # Cheapest option for workshop
vm_os_disk_size_gb = 128
admin_username     = "azureuser"
create_public_ip   = false
enable_bastion     = true
bastion_sku        = "Standard"
enable_nat_gateway = true

# ===============================================================================
# Compute Gallery
# ===============================================================================

gallery_name     = "gal_oracle_workshop"
image_name       = "oracle-workshop-vm"
vm_image_version = "1.0.1" # null = use Ubuntu default, "1.0.1" = use gallery image

# ===============================================================================
# ODAA Configuration (Shared VNet + Anchors)
# ===============================================================================

odaa_vnet_cidr     = "192.168.0.0/16"
odaa_dns_zone_name = "adb.eu-paris-1.oraclecloud.com"

# Entra ID user group for shared ODAA RBAC (mh-odaa-user-grp)
odaa_user_group_id = "5fbc2654-d343-401a-be86-08327fe66ec2"

# ===============================================================================
# User Count — set this to control how many users to deploy (0-25)
# ===============================================================================

user_count = 1

# ===============================================================================
# Entra ID Login Configuration
# ===============================================================================

enable_entra_id_login = true
entra_id_admin_login  = false # true = Admin, false = User login

# User Object IDs from Entra ID (Azure AD)
# Source: user_credentials.json
user_object_ids = {
  "00" = "1b72fd4f-eb1b-4cb9-a4fd-6c05eec0879b" # Peter Parker
  "01" = "e0178e03-3be3-4bbf-ae14-fcc798214808" # Bruce Wayne
  "02" = "a3ce311c-347e-4506-b35c-fb2c1ef1717c" # Diana Prince
  "03" = "5bf0f7b5-66a6-4c16-a0b8-de1caa5257cc" # Clark Kent
  "04" = "f6e6390e-b5e8-4de5-ac5c-8ffb8bf81569" # Barry Allen
  "05" = "97ae2cd8-9b27-4a6c-9834-81a5825d337f" # Natasha Romanoff
  "06" = "31888258-1080-4a1b-b651-0c30c953cff2" # Tony Stark
  "07" = "a6231d83-b0ad-4174-aaa8-350040574dfa" # Carol Danvers
  "08" = "38f07c23-ae22-427e-bb8f-e3aae0e555ac" # Stephen Strange
  "09" = "7e9d110a-095f-4429-9bcf-23432891e3bf" # Wanda Maximoff
  "10" = "86819096-c460-4f0a-a33e-a9b9f60d4edd" # T'Challa Udaku
  "11" = "4903a469-dedd-48f5-b2b3-df3fb996d9bf" # Shuri Udaku
  "12" = "2463e218-6617-4aab-ae1a-dbeb51dceb1d" # Sam Wilson
  "13" = "7f001574-3d66-4801-9d10-c644fc5b79db" # Scott Lang
  "14" = "4216137f-e813-4227-8bc9-bf8a4026ec42" # Ororo Munroe
  "15" = "7b54752a-f78e-4a56-ab3f-9e4170485227" # Hal Jordan
  "16" = "51d0813a-6786-46b9-a67f-f2ab209af8d7" # Arthur Curry
  "17" = "326fa1e7-849d-4c66-9b95-1e156ffdee1d" # Victor Stone
  "18" = "d398c4bf-ab62-48cb-a432-ef5ffd3b541c" # Billy Batson
  "19" = "d18099e8-5fa0-4d25-86c8-222ff1d2f8a9" # Barbara Gordon
  "20" = "630b2796-b772-4e8e-a2e4-dfd84edd38e3" # Kamala Khan
  "21" = "47d071cc-c7f8-46db-a289-67fbb3c0e70f" # Kate Bishop
  "22" = "d4b20336-beaf-4259-8ad6-607d63b9a233" # Jessica Jones
  "23" = "48eecf0c-9784-4a69-a5c1-aa2f5e849423" # Matt Murdock
  "24" = "d37cbd7e-9efa-44af-b420-60e21d122b4f" # Luke Cage
}

# ===============================================================================
# Tags
# ===============================================================================

tags = {
  Project     = "OracleWorkshop"
  ManagedBy   = "Terraform"
  Environment = "Workshop"
}

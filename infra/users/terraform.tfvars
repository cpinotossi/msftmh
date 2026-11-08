# Subscription and tenant defaults are defined in variables.tf.
# New user object IDs come from identity.tfstate, never a previous tenant.
location   = "francecentral"
user_count = 7

vm_size            = "Standard_D2s_v5"
vm_os_disk_type    = "Standard_LRS"
vm_os_disk_size_gb = 128
admin_username     = "azureuser"
vm_image_version   = "1.0.2"

enable_entra_id_login = true
entra_id_admin_login  = false

tags = {
  Project     = "OracleWorkshop"
  ManagedBy   = "Terraform"
  Environment = "Workshop"
}

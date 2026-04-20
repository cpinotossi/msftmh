# ===============================================================================
# Shared Module - Outputs
# ===============================================================================

output "resource_group_name" {
  description = "Name of the shared resource group"
  value       = azurerm_resource_group.shared.name
}

output "resource_group_id" {
  description = "ID of the shared resource group"
  value       = azurerm_resource_group.shared.id
}

output "gallery_id" {
  description = "ID of the Azure Compute Gallery"
  value       = azurerm_shared_image_gallery.gallery.id
}

output "gallery_name" {
  description = "Name of the Azure Compute Gallery"
  value       = azurerm_shared_image_gallery.gallery.name
}

output "image_id" {
  description = "ID of the image definition"
  value       = azurerm_shared_image.oracle_workshop.id
}

output "image_name" {
  description = "Name of the image definition"
  value       = azurerm_shared_image.oracle_workshop.name
}

output "ssh_public_key" {
  description = "SSH public key for VM access (auto-generated)"
  value       = var.create_ssh_key ? tls_private_key.workshop[0].public_key_openssh : null
}

output "ssh_private_key" {
  description = "SSH private key for admin emergency access (sensitive)"
  value       = var.create_ssh_key ? tls_private_key.workshop[0].private_key_pem : null
  sensitive   = true
}

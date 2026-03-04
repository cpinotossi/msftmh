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

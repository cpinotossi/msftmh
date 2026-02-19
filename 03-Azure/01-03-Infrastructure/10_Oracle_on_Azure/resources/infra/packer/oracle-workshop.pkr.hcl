# ===============================================================================
# Packer Template - Oracle Workshop VM Image
# ===============================================================================
# This template builds a VM image with Oracle tools pre-installed using
# Ansible for provisioning. The image is stored in Azure Compute Gallery.
#
# Usage:
#   packer init .
#   packer build -var-file=variables.pkrvars.hcl oracle-workshop.pkr.hcl
# ===============================================================================

packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1.1"
    }
  }
}

# ===============================================================================
# Variables
# ===============================================================================

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID"
}

variable "client_id" {
  type        = string
  description = "Service Principal client ID"
}

variable "client_secret" {
  type        = string
  description = "Service Principal client secret"
  sensitive   = true
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID for image storage"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "francecentral"
}

variable "resource_group" {
  type        = string
  description = "Resource group for temporary build resources"
  default     = "rg-packer-build"
}

variable "gallery_name" {
  type        = string
  description = "Name of the Azure Compute Gallery"
  default     = "gal_oracle_workshop"
}

variable "gallery_resource_group" {
  type        = string
  description = "Resource group containing the Compute Gallery"
  default     = "rg-shared-workshop"
}

variable "image_name" {
  type        = string
  description = "Name of the image definition"
  default     = "oracle-workshop-vm"
}

variable "image_version" {
  type        = string
  description = "Version of the image (e.g., 1.0.0)"
  default     = "1.0.0"
}

variable "vm_size" {
  type        = string
  description = "VM size for the build"
  default     = "Standard_D2s_v5"
}

# ===============================================================================
# Source: Azure ARM Builder
# ===============================================================================

source "azure-arm" "oracle-workshop" {
  # Authentication - Service Principal (not Azure CLI)
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id

  # Source Image - Ubuntu 24.04 LTS
  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "ubuntu-24_04-lts"
  image_sku       = "server"

  # Build Configuration
  location = var.location
  vm_size  = var.vm_size

  # Temporary resource group for build
  build_resource_group_name = var.resource_group

  # Destination: Azure Compute Gallery
  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = var.gallery_resource_group
    gallery_name         = var.gallery_name
    image_name           = var.image_name
    image_version        = var.image_version
    replication_regions  = [var.location]
    storage_account_type = "Standard_LRS"
  }

  # Azure tags for the build VM
  azure_tags = {
    Purpose   = "PackerBuild"
    Project   = "OracleWorkshop"
    ManagedBy = "Packer"
  }
}

# ===============================================================================
# Build
# ===============================================================================

build {
  name    = "oracle-workshop"
  sources = ["source.azure-arm.oracle-workshop"]

  # Ansible Provisioner - Install Oracle Tools
  provisioner "ansible" {
    playbook_file = "../ansible/playbooks/oracle-tools.yml"
    user          = "packer"
    use_proxy     = false

    extra_arguments = [
      "--extra-vars", "ansible_become=true"
    ]
  }

  # Generalize the VM for Azure (required for image capture)
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "echo '>>> Cleaning up...'",
      "/usr/sbin/waagent -force -deprovision+user",
      "sync"
    ]
  }
}

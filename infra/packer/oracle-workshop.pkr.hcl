# ===============================================================================
# Packer Template - Oracle Workshop VM Image
# ===============================================================================
# Builds a Ubuntu 24.04 VM image with pre-installed Oracle tools via Ansible:
# - Oracle Instant Client 23.26.4 + SQL*Plus
# - Oracle SQLcl (SQL Developer Command Line)
# - rwloadsim/connping
# - Java 21 OpenJDK
# - Azure CLI
# - OCI CLI
#
# NOTE:
# This template uses the ansible-local provisioner, which runs Ansible
# directly on the target VM — no SSH round-trips between tasks.
# A small shell provisioner bootstraps Ansible on the VM first.
# This eliminates SSH fragility issues during image generalization.
# ===============================================================================

packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "= 2.6.5"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "= 1.1.3"
    }
  }
}

# ===============================================================================
# Variables
# ===============================================================================

variable "subscription_id" {
  type        = string
  default     = "aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483"
  description = "Azure Subscription ID"
}

variable "location" {
  type        = string
  default     = "francecentral"
  description = "Azure region for building the image"
}

variable "resource_group" {
  type        = string
  default     = "rg-workshop-images"
  description = "Resource group containing the Compute Gallery"
}

variable "build_resource_group" {
  type        = string
  default     = "rg-packer-build"
  description = "Resource group used for temporary Packer build resources (pkr*). Keep this separate from the shared gallery RG."
}

variable "gallery_name" {
  type        = string
  default     = "gal_oracle_workshop"
  description = "Azure Compute Gallery name"
}

variable "image_name" {
  type        = string
  default     = "oracle-workshop-vm"
  description = "Image definition name in the gallery"
}

variable "image_version" {
  type        = string
  default     = "1.1.0"
  description = "Image version to create (semver format)"
}

variable "vm_size" {
  type        = string
  default     = "Standard_D4as_v7"
  description = "VM size for building the image"
}

# ===============================================================================
# Source - Azure ARM Builder
# ===============================================================================

source "azure-arm" "oracle-workshop" {
  # Authentication — uses active az CLI session (az login --identity for MSI)
  use_azure_cli_auth = true
  subscription_id    = var.subscription_id

  # Build VM Configuration
  vm_size              = var.vm_size
  disk_controller_type = "NVMe"
  public_ip_sku        = "Standard"

  # Source Image - Ubuntu 24.04 LTS x64, Hyper-V generation V2
  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "ubuntu-24_04-lts"
  image_sku       = "server"
  image_version   = "24.04.202610250"

  # Use a separate resource group for temporary build resources (pkr*)
  build_resource_group_name = var.build_resource_group

  # Shared Image Gallery Destination
  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = var.resource_group
    gallery_name         = var.gallery_name
    image_name           = var.image_name
    image_version        = var.image_version
    storage_account_type = "Standard_LRS"

    target_region {
      name     = var.location
      replicas = 1
    }
  }

  # Tags
  azure_tags = {
    Environment = "Workshop"
    Purpose     = "Oracle Tools Base Image"
    ManagedBy   = "Packer"
  }

  # SSH Configuration
  communicator = "ssh"
  ssh_username = "packer"
  ssh_timeout  = "30m"
}

# ===============================================================================
# Build
# ===============================================================================

build {
  name    = "oracle-workshop-image"
  sources = ["source.azure-arm.oracle-workshop"]

  # Bootstrap Ansible on the VM so ansible-local can run
  provisioner "shell" {
    inline = [
      "echo '>>> Installing Ansible on build VM...'",
      "export DEBIAN_FRONTEND=noninteractive",
      "export NEEDRESTART_MODE=l",
      "sudo cloud-init status --wait",
      "sudo apt-get update -qq",
      "sudo apt-get install -y -qq ansible-core",
      "ansible --version",
    ]
  }

  # Run the playbook locally on the VM (no SSH between tasks)
  provisioner "ansible-local" {
    playbook_file = "${path.root}/ansible/oracle-tools.yml"
    extra_arguments = [
      "--extra-vars", "ansible_python_interpreter=/usr/bin/python3",
      "-vv",
    ]
  }

  provisioner "shell" {
    inline            = ["sudo reboot"]
    expect_disconnect = true
    pause_after       = "30s"
  }

  provisioner "shell" {
    script          = "${path.root}/scripts/verify-nvme.sh"
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E /bin/sh -eu '{{ .Path }}'"
  }

  # Final deprovision — runs over SSH as a separate step after Ansible
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E /bin/sh -eu '{{ .Path }}'"
    inline = [
      "echo '>>> Generalizing image...'",
      "rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub",
      "truncate -s 0 /etc/machine-id",
      "rm -f /var/lib/dbus/machine-id",
      "ln -sf /etc/machine-id /var/lib/dbus/machine-id",
      "find /var/log -type f -exec truncate -s 0 {} \\; 2>/dev/null || true",
      "cloud-init clean --logs",
      "rm -f /home/*/.bash_history /root/.bash_history 2>/dev/null || true",
      "/usr/sbin/waagent -force -deprovision+user",
      "export HISTSIZE=0",
      "sync",
    ]
    expect_disconnect = true
  }

  post-processor "manifest" {
    output     = "packer-manifest.json"
    strip_path = true
  }
}

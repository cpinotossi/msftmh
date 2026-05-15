# Oracle Workshop VM Image Builder

Builds a fully configured Ubuntu 24.04 VM image with pre-installed Oracle tools using **Packer** and **Ansible**, then publishes it to **Azure Compute Gallery**.

## Pre-installed Software

| Category | Tool | Version | Description |
|----------|------|---------|-------------|
| **Oracle DB** | Oracle Instant Client | 23.5 | Oracle database client libraries |
| **Oracle DB** | SQL*Plus | 23.5 | Oracle command-line SQL tool |
| **Oracle DB** | SQLcl | 24.3 | Modern SQL command-line with scripting |
| **Oracle DB** | rwloadsim/connping | 3.2.1 | Connection latency testing |
| **Oracle DB** | adbping | - | ADB latency testing (placeholder*) |
| **CLI** | Azure CLI | latest | Azure management |
| **CLI** | OCI CLI | latest | Oracle Cloud management |
| **Runtime** | Java | 17 | OpenJDK for SQLcl |
| **Runtime** | Python | 3.12 | Python 3 with pip |
| **Tools** | Network diagnostics | - | dig, traceroute, netcat, tcpdump |
| **Tools** | Utilities | - | git, jq, vim, nano, htop, tmux |

> *adbping requires manual download from Oracle Support (Doc ID 2863450.1)

## Prerequisites

1. **Packer** (1.9+)
   ```powershell
   choco install packer
   # or download from https://www.packer.io/downloads
   ```

2. **Ansible** (optional, for local debugging)
   - On Windows: Use WSL2 with Ansible installed
   - Packer will run Ansible via SSH on the target VM

3. **Azure Resources** (created by Terraform)
   - Resource Group: `rg-shared-workshop`
   - Compute Gallery: `gal_oracle_workshop`
   - Image Definition: `oracle-workshop-vm`

## Quick Start

### 1. Configure Variables

```powershell
# Copy the example variables file
Copy-Item variables.pkrvars.hcl.example variables.auto.pkrvars.hcl

# Edit with your Azure credentials
notepad variables.auto.pkrvars.hcl
```

Fill in your values:
```hcl
client_id       = "your-service-principal-client-id"
client_secret   = "your-service-principal-secret"
tenant_id       = "your-tenant-id"
subscription_id = "your-vm-subscription-id"

location        = "francecentral"
resource_group  = "rg-shared-workshop"
build_resource_group = "rg-packer-build"
gallery_name    = "gal_oracle_workshop"
image_name      = "oracle-workshop-vm"
image_version   = "1.0.0"
```

### 2. Build the Image

```powershell
# Validate first
.\build-image.ps1 -Validate

# Build version 1.0.0
.\build-image.ps1 -Version "1.0.0"

# Build with debug output
.\build-image.ps1 -Version "1.0.0" -Debug
```

### 3. Use in Terraform

After building, update `terraform.tfvars`:

```hcl
# Use the gallery image instead of default Ubuntu
vm_image_version = "1.0.0"
```

Then deploy:
```powershell
terraform plan -out=tfplan
terraform apply tfplan
```

## Directory Structure

```
packer/
├── oracle-workshop.pkr.hcl          # Packer template
├── variables.pkrvars.hcl.example    # Example variables (copy to .auto.pkrvars.hcl)
├── build-image.ps1                  # Build script (Windows)
├── README.md                        # This file
└── ansible/
    └── oracle-tools.yml             # Ansible playbook
```

## Build Process

1. **Create Temp VM**: Packer creates a temporary VM from Ubuntu 24.04
2. **Run Ansible**: Installs all Oracle tools and CLIs
3. **Cleanup**: Removes logs, SSH keys, cloud-init state
4. **Generalize**: Prepares VM for imaging (deprovision)
5. **Capture**: Publishes to Azure Compute Gallery

Estimated build time: **15-25 minutes**

## Customization

### Add Docker

Edit `ansible/oracle-tools.yml` and set:
```yaml
vars:
  install_docker: true
```

### Change Oracle Versions

Edit `ansible/oracle-tools.yml`:
```yaml
vars:
  oracle_instant_client_version: "23.5"
  sqlcl_version: "24.3"
  java_version: "17"
```

### Add Custom Tools

Add tasks to `ansible/oracle-tools.yml` in the appropriate section.

## Troubleshooting

### Build Fails at Ansible Step

1. Check SSH connectivity to the temp VM
2. Review Packer logs for Ansible errors
3. Try with `-Debug` flag for step-by-step execution

### Image Not Found in Gallery

Ensure Terraform has created:
- Resource Group: `rg-shared-workshop`
- Gallery: `gal_oracle_workshop`
- Image Definition: `oracle-workshop-vm`

Run `terraform apply` first if these don't exist.

### Ansible Connection Issues on Windows

Packer runs Ansible over SSH to the target VM. If you see connection issues:
1. Ensure the Azure firewall allows SSH (port 22)
2. Check the Service Principal has Contributor access

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Initial | Oracle Client 23.5, SQLcl 24.3, Azure CLI, OCI CLI |

## Related Files

- `../terraform.tfvars` - Set `vm_image_version` to use this image
- `../modules/shared/main.tf` - Compute Gallery and Image Definition
- `../misc/ansible/` - Original standalone Ansible playbook

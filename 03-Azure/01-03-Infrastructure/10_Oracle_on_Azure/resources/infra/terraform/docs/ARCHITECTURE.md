# Oracle on Azure Workshop - Simplified Architecture

## Overview

This document describes the simplified infrastructure architecture for the Oracle on Azure MicroHack workshop. The design prioritizes:

- **Cost efficiency**: Persistent resources are free, VMs can be deallocated
- **User isolation**: Each user has dedicated VNets in both subscriptions
- **Simplicity**: No complex Terraform loops, explicit module definitions

---

## Subscription Layout

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           VM SUBSCRIPTION (sub-mh0)                                 │
│                           Kaufmännisch: Workshop/Training Budget                    │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                         SHARED RESOURCES                                     │   │
│  │  ┌─────────────────────────┐    ┌─────────────────────────┐                 │   │
│  │  │ Azure Compute Gallery   │───>│ Image Definition        │                 │   │
│  │  │ gal_oracle_workshop     │    │ oracle-workshop-vm v1.0 │                 │   │
│  │  └─────────────────────────┘    └───────────┬─────────────┘                 │   │
│  └─────────────────────────────────────────────┼───────────────────────────────┘   │
│                    ┌───────────────────────────┼───────────────────────┐           │
│                    │                           │                       │           │
│                    ▼                           ▼                       ▼           │
│  ┌─────────────────────────┐ ┌─────────────────────────┐ ┌─────────────────────────┐│
│  │   USER 00 WORKSPACE     │ │   USER 01 WORKSPACE     │ │   USER 02 WORKSPACE     ││
│  ├─────────────────────────┤ ├─────────────────────────┤ ├─────────────────────────┤│
│  │ RG: rg-vm-user00        │ │ RG: rg-vm-user01        │ │ RG: rg-vm-user02        ││
│  │ ┌─────────────────────┐ │ │ ┌─────────────────────┐ │ │ ┌─────────────────────┐ ││
│  │ │ VNet: 10.0.0.0/16   │ │ │ │ VNet: 10.1.0.0/16   │ │ │ │ VNet: 10.2.0.0/16   │ ││
│  │ │  ┌───────────────┐  │ │ │ │  ┌───────────────┐  │ │ │ │  ┌───────────────┐  │ ││
│  │ │  │ VM user00     │  │ │ │ │  │ VM user01     │  │ │ │ │  │ VM user02     │  │ ││
│  │ │  └───────────────┘  │ │ │ │  └───────────────┘  │ │ │ │  └───────────────┘  │ ││
│  │ └──────────┬──────────┘ │ │ └──────────┬──────────┘ │ │ └──────────┬──────────┘ ││
│  └────────────┼────────────┘ └────────────┼────────────┘ └────────────┼────────────┘│
│               │                           │                           │             │
│               │         ... up to USER 24 ...                         │             │
│               │                                                       │             │
└───────────────┼───────────────────────────┼───────────────────────────┼─────────────┘
                │                           │                           │
                │ Peering 1:1               │ Peering 1:1               │ Peering 1:1
                ▼                           ▼                           ▼
┌───────────────┴───────────────────────────┴───────────────────────────┴─────────────┐
│                           ODAA SUBSCRIPTION (sub-mhodaa)                            │
│                           Kaufmännisch: Oracle Lizenz Budget                        │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────────────┐ ┌─────────────────────────┐ ┌─────────────────────────┐│
│  │   ODAA USER 00          │ │   ODAA USER 01          │ │   ODAA USER 02          ││
│  ├─────────────────────────┤ ├─────────────────────────┤ ├─────────────────────────┤│
│  │ RG: rg-odaa-user00      │ │ RG: rg-odaa-user01      │ │ RG: rg-odaa-user02      ││
│  │ ┌─────────────────────┐ │ │ ┌─────────────────────┐ │ │ ┌─────────────────────┐ ││
│  │ │VNet: 192.168.0.0/16 │ │ │ │VNet: 192.168.0.0/16 │ │ │ │VNet: 192.168.0.0/16 │ ││
│  │ │ ┌─────────────────┐ │ │ │ │ ┌─────────────────┐ │ │ │ │ ┌─────────────────┐ │ ││
│  │ │ │Delegated Subnet │ │ │ │ │ │Delegated Subnet │ │ │ │ │ │Delegated Subnet │ │ ││
│  │ │ │(Oracle.Database)│ │ │ │ │ │(Oracle.Database)│ │ │ │ │ │(Oracle.Database)│ │ ││
│  │ │ │  ┌───────────┐  │ │ │ │ │ │  ┌───────────┐  │ │ │ │ │ │  ┌───────────┐  │ │ ││
│  │ │ │  │ADB user00 │  │ │ │ │ │ │  │ADB user01 │  │ │ │ │ │ │  │ADB user02 │  │ │ ││
│  │ │ │  └───────────┘  │ │ │ │ │ │  └───────────┘  │ │ │ │ │ │  └───────────┘  │ │ ││
│  │ │ └─────────────────┘ │ │ │ │ └─────────────────┘ │ │ │ │ └─────────────────┘ │ ││
│  │ └─────────────────────┘ │ │ └─────────────────────┘ │ │ └─────────────────────┘ ││
│  └─────────────────────────┘ └─────────────────────────┘ └─────────────────────────┘│
│                                                                                     │
│               ... up to ODAA USER 24 ...                                            │
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │ SHARED: Private DNS Zone (adb.eu-paris-1.oraclecloud.com)                   │   │
│  │         Linked to ALL User VM VNets (25 links)                              │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Network Topology

### VNet Peering (1:1 User Isolation)

```
USER 00:  VM VNet (10.0.0.0/16)   <────────────>  ODAA VNet (192.168.0.0/16)
USER 01:  VM VNet (10.1.0.0/16)   <────────────>  ODAA VNet (192.168.0.0/16)
USER 02:  VM VNet (10.2.0.0/16)   <────────────>  ODAA VNet (192.168.0.0/16)
...
USER 24:  VM VNet (10.24.0.0/16)  <────────────>  ODAA VNet (192.168.0.0/16)

⚠️  No peering between User ODAA VNets = Complete user isolation
⚠️  No peering between User VM VNets   = Complete user isolation
```

### IP Address Scheme

| User | VM VNet CIDR | VM Subnet | ODAA VNet CIDR | ODAA Subnet |
|------|--------------|-----------|----------------|-------------|
| 00 | 10.0.0.0/16 | 10.0.0.0/24 | 192.168.0.0/16 | 192.168.0.0/24 |
| 01 | 10.1.0.0/16 | 10.1.0.0/24 | 192.168.0.0/16 | 192.168.0.0/24 |
| 02 | 10.2.0.0/16 | 10.2.0.0/24 | 192.168.0.0/16 | 192.168.0.0/24 |
| ... | ... | ... | ... | ... |
| 24 | 10.24.0.0/16 | 10.24.0.0/24 | 192.168.0.0/16 | 192.168.0.0/24 |

> Note: ODAA VNets use same CIDR (192.168.0.0/16) but are isolated by VNet boundaries

---

## Resource Inventory (25 Users)

### VM Subscription (sub-mh0)

| Resource Type | Count | Naming Pattern | Cost |
|---------------|-------|----------------|------|
| Resource Groups | 25 | rg-vm-user00..24 | Free |
| Virtual Networks | 25 | vnet-vm-user00..24 | Free |
| Subnets | 25 | snet-vm-user00..24 | Free |
| Virtual Machines | 25 | vm-user00..24 | $0 deallocated |
| OS Disks (Standard HDD) | 25 | disk-vm-user00..24 | ~$125/month |
| Compute Gallery | 1 | gal_oracle_workshop | Free |
| Image Definition | 1 | oracle-workshop-vm | Free |
| Image Version | 1 | 1.0.0 | ~$5/month |

### ODAA Subscription (sub-mhodaa)

| Resource Type | Count | Naming Pattern | Cost |
|---------------|-------|----------------|------|
| Resource Groups | 25 | rg-odaa-user00..24 | Free |
| Virtual Networks | 25 | vnet-odaa-user00..24 | Free |
| Delegated Subnets | 25 | snet-odaa-user00..24 | Free |
| VNet Peerings | 50 | peer-vm-to-odaa-user00..24 (bidirectional) | Free |
| Private DNS Zone | 1 | adb.eu-paris-1.oraclecloud.com | Free |
| DNS Zone Links | 25 | link-user00..24 | Free |
| Oracle ADB | 25 | adb-user00..24 | Workshop cost |

---

## Terraform Implementation Strategy

### Design Principles

1. **No loops (`for_each`, `count`)**: Explicit module definitions for each user
2. **No complex expressions**: Simple variable references only
3. **Maximum readability**: Anyone can understand the code immediately
4. **Easy debugging**: Each user's resources are independently defined

### Module Structure

```
modules/
├── user-vm/                 # VM infrastructure per user
│   ├── main.tf             # RG, VNet, Subnet, VM
│   ├── variables.tf
│   └── outputs.tf
│
├── user-odaa/              # ODAA infrastructure per user
│   ├── main.tf             # RG, VNet, Delegated Subnet
│   ├── variables.tf
│   └── outputs.tf
│
├── vnet-peering/           # Bidirectional VNet peering
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
└── shared/                 # Shared resources (Gallery, DNS)
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

### Main.tf Structure (Explicit Definitions)

```hcl
# ============================================================================
# SHARED RESOURCES
# ============================================================================

module "shared" {
  source = "./modules/shared"
  
  providers = {
    azurerm = azurerm.vm
  }
  
  location     = var.location
  gallery_name = "gal_oracle_workshop"
  tags         = var.tags
}

# ============================================================================
# USER 00
# ============================================================================

module "user_vm_00" {
  source = "./modules/user-vm"
  
  providers = {
    azurerm = azurerm.vm
  }
  
  user_index   = 0
  location     = var.location
  vm_image_id  = module.shared.image_id
  vnet_cidr    = "10.0.0.0/16"
  tags         = var.tags
}

module "user_odaa_00" {
  source = "./modules/user-odaa"
  
  providers = {
    azurerm = azurerm.odaa
  }
  
  user_index = 0
  location   = var.location
  vnet_cidr  = "192.168.0.0/16"
  tags       = var.tags
}

module "peering_00" {
  source = "./modules/vnet-peering"
  
  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }
  
  user_index           = 0
  vm_vnet_id           = module.user_vm_00.vnet_id
  vm_vnet_name         = module.user_vm_00.vnet_name
  vm_resource_group    = module.user_vm_00.resource_group_name
  odaa_vnet_id         = module.user_odaa_00.vnet_id
  odaa_vnet_name       = module.user_odaa_00.vnet_name
  odaa_resource_group  = module.user_odaa_00.resource_group_name
}

# ============================================================================
# USER 01
# ============================================================================

module "user_vm_01" {
  source = "./modules/user-vm"
  
  providers = {
    azurerm = azurerm.vm
  }
  
  user_index   = 1
  location     = var.location
  vm_image_id  = module.shared.image_id
  vnet_cidr    = "10.1.0.0/16"
  tags         = var.tags
}

module "user_odaa_01" {
  source = "./modules/user-odaa"
  
  providers = {
    azurerm = azurerm.odaa
  }
  
  user_index = 1
  location   = var.location
  vnet_cidr  = "192.168.0.0/16"
  tags       = var.tags
}

module "peering_01" {
  source = "./modules/vnet-peering"
  
  providers = {
    azurerm.vm   = azurerm.vm
    azurerm.odaa = azurerm.odaa
  }
  
  user_index           = 1
  vm_vnet_id           = module.user_vm_01.vnet_id
  vm_vnet_name         = module.user_vm_01.vnet_name
  vm_resource_group    = module.user_vm_01.resource_group_name
  odaa_vnet_id         = module.user_odaa_01.vnet_id
  odaa_vnet_name       = module.user_odaa_01.vnet_name
  odaa_resource_group  = module.user_odaa_01.resource_group_name
}

# ============================================================================
# USER 02 ... USER 24 (same pattern)
# ============================================================================
# Repeat the same structure for users 02-24
# Each user has exactly 3 module blocks: user_vm_XX, user_odaa_XX, peering_XX
```

### Pros and Cons of Explicit Definitions

| Pros | Cons |
|------|------|
| ✅ Maximum simplicity | ❌ More lines of code (~75 module blocks) |
| ✅ Easy to understand | ❌ Repetitive |
| ✅ Easy to debug | ❌ Manual updates for each user |
| ✅ No Terraform expertise needed | ❌ Copy-paste errors possible |
| ✅ Clear resource ownership | |
| ✅ Independent apply/destroy per user | |

---

## Cost Summary

### Persistent Costs (VMs Deallocated)

| Resource | Count | Cost/Month |
|----------|-------|------------|
| VM OS Disks (Standard HDD 128GB) | 25 | ~$125 |
| Image Version (Snapshot) | 1 | ~$5 |
| **TOTAL** | | **~$130/month** |

### Running Costs (Workshop Active)

| Resource | Count | Cost/Hour | 8h Workshop |
|----------|-------|-----------|-------------|
| VMs (Standard_D2s_v5) | 25 | ~$2.50 | ~$20 |
| Oracle ADB | 25 | Workshop pricing | Variable |
| **VM TOTAL** | | | **~$20/workshop** |

### Cost Optimization Strategies

1. **Deallocate VMs** after workshop ends
2. **Use Standard HDD** instead of SSD for OS disks
3. **Delete VMs completely** for long idle periods (recreate from image)
4. **Single shared image** for all users

---

## Deployment Workflow

### Initial Setup (Once)

```powershell
# 1. Build VM image with Packer + Ansible
cd packer
packer build oracle-workshop.pkr.hcl

# 2. Deploy persistent infrastructure
cd ../terraform
terraform apply -target=module.shared
terraform apply -target=module.user_vm_00 -target=module.user_odaa_00 ...
```

### Workshop Start

```powershell
# Start all VMs
az vm start --ids $(az vm list -g rg-vm-user* --query "[].id" -o tsv)
```

### Workshop End

```powershell
# Deallocate all VMs (stop billing)
az vm deallocate --ids $(az vm list -g rg-vm-user* --query "[].id" -o tsv)
```

---

## File Structure

```
infra/
├── terraform/
│   ├── main.tf                 # 25x explicit module definitions
│   ├── providers.tf            # 2 providers: azurerm.vm, azurerm.odaa
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── modules/
│       ├── user-vm/
│       ├── user-odaa/
│       ├── vnet-peering/
│       └── shared/
├── packer/
│   ├── oracle-workshop.pkr.hcl
│   └── variables.pkr.hcl
├── ansible/
│   └── playbooks/
│       └── oracle-tools.yml
└── scripts/
    ├── start-workshop.ps1
    ├── stop-workshop.ps1
    └── build-image.ps1
```

# Oracle Database @ Azure - Workshop Infrastructure

## Structure

```text
infra/
├── ansible/           # Ansible Playbooks (oracle-tools)
├── github-runner/     # Self-hosted Runner (one-time, local)
├── identity/          # Entra ID Users (one-time, local)
├── modules/           # Terraform Modules
│   ├── entra-id/      #   Entra ID (used by identity/)
│   ├── user-vm/       #   User VM (used by users/)
│   └── vnet-peering/  #   VNet Peering (used by users/)
├── packer/            # VM Image Build (Packer + Ansible)
├── scripts/           # PowerShell Utility Scripts
├── shared/            # Shared Infra: Gallery, ODAA VNets, Role Defs
└── users/             # Per-User: VMs, ODAA RGs, Peerings
```

## Architecture

```
sub-mhcore (09808f31...)        sub-mh0 (ff0bb075...)           sub-mhodaa (4aecf0e8...)
┌─────────────────────┐   ┌──────────────────────────┐   ┌──────────────────────────────┐
│ rg-shared-workshop  │   │ rg-vm-user00             │   │ rg-odaa-shared               │
│  └─ Compute Gallery │   │  ├─ vnet-vm-user00       │   │  ├─ vnet-odaa-shared         │
│                     │   │  │   (10.0.0.0/24)       │   │  │   (192.168.0.0/16)        │
│ rg-odaamh-github-   │   │  ├─ VM + Bastion         │   │  ├─ vnet-odaa-basedb         │
│ runner              │   │  └─ NAT Gateway          │   │  │   (172.16.0.0/16)         │
│  ├─ Container App   │   │                          │   │  ├─ Resource Anchor          │
│  │  Job (Runner)    │   │  Peerings:               │   │  └─ (Users create DBs here)  │
│  └─ Storage Account │   │  vm ↔ vnet-odaa-shared   │   │                              │
│     (tfstate)       │   │  vm ↔ vnet-odaa-basedb   │   │                              │
└─────────────────────┘   └──────────────────────────┘   └──────────────────────────────┘
```

Start the runner after each workflow trigger:

```pwsh
az containerapp job start --name caj-odaamh -g rg-odaamh-github-runner --subscription 09808f31-065f-4231-914d-776c2d6bbe34 -o none
```

## Before the Workshop

All workflows are triggered via `git commit` + `push`. The order matters.

### Step 1: Reset users (passwords + MFA)

Change the "mh-name" attribute in `users/user_credentials.template.json`. This triggers the reset workflow.

```pwsh
# e.g. set mh-name or make any change to the template
cd infra
code users/user_credentials.template.json

git add users/user_credentials.template.json
git commit -m "FRA-MH-20260421"
git push
# Check workflow status
gh run list --workflow="odaa-reset-users.yml" --repo cpinotossi/msftmh --limit 1
# Wait for completion and show result
gh run watch $(gh run list --workflow="odaa-reset-users.yml" --repo cpinotossi/msftmh --limit 1 --json databaseId -q ".[0].databaseId") --repo cpinotossi/msftmh --exit-status
# Download credentials artifact
gh run download $(gh run list --workflow="odaa-reset-users.yml" --repo cpinotossi/msftmh --limit 1 --json databaseId -q ".[0].databaseId") --repo cpinotossi/msftmh
```

### Step 2: Deploy workshop (Shared + User VMs)

A change to `users/terraform.tfvars` (e.g. `user_count`) triggers the deploy workshop workflow.

```pwsh
code users/terraform.tfvars
# Adjust user_count, then:
git add users/terraform.tfvars
git commit -m "deploy workshop user_count=25"
git push
# Check workflow status
gh run list --workflow="odaa-deploy-workshop.yml" --repo cpinotossi/msftmh --limit 1
# Wait for completion and show result
gh run watch $(gh run list --workflow="odaa-deploy-workshop.yml" --repo cpinotossi/msftmh --limit 1 --json databaseId -q ".[0].databaseId") --repo cpinotossi/msftmh --exit-status
```

> **Note:** Shared Infra (`1 - Deploy Shared`) must be deployed first. If not, trigger it manually:
> ```pwsh
> gh workflow run "1 - Deploy Shared" --repo cpinotossi/msftmh
> ```

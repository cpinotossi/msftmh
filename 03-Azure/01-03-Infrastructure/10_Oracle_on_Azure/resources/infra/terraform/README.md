# Oracle Workshop

## Struktur

```
terraform/
├── identity/          # Entra ID Users (einmalig, lokal)
├── github-runner/     # Self-hosted Runner (einmalig, lokal)
├── lab-env/
│   ├── shared/        # Shared Infra: Gallery, ODAA VNets, Role Defs
│   ├── users/         # Per-User: VMs, ODAA RGs, Peerings
│   └── modules/       # Terraform Module (user-vm, user-odaa, shared-odaa, ...)
├── scripts/           # manage-users.ps1, deploy.ps1, ...
└── packer/            # VM Image Build
```

## Architektur

```
sub-mhcore (09808f31...)        sub-mh0 (ff0bb075...)           sub-mhodaa (4aecf0e8...)
┌─────────────────────┐   ┌──────────────────────────┐   ┌──────────────────────────────┐
│ rg-shared-workshop  │   │ rg-vm-user00             │   │ rg-odaa-shared               │
│  └─ Compute Gallery │   │  ├─ vnet-vm-user00       │   │  ├─ vnet-odaa-shared         │
│                     │   │  │   (10.0.0.0/24)       │   │  │   (192.168.0.0/16)        │
│ rg-odaamh-github-   │   │  ├─ VM + Bastion         │   │  ├─ vnet-odaa-basedb         │
│ runner              │   │  └─ NAT Gateway          │   │  │   (172.16.0.0/16)         │
│  ├─ Container App   │   │                          │   │  └─ Resource Anchor          │
│  │  Job (Runner)    │   │  Peerings:               │   │                              │
│  └─ Storage Account │   │  vm ↔ vnet-odaa-shared   │   │ rg-odaa-user00               │
│     (tfstate)       │   │  vm ↔ vnet-odaa-basedb   │   │  └─ (User erstellt DBs hier) │
└─────────────────────┘   └──────────────────────────┘   └──────────────────────────────┘
```


Runner nach jedem Workflow-Trigger starten:

```pwsh
az containerapp job start --name caj-odaamh -g rg-odaamh-github-runner --subscription 09808f31-065f-4231-914d-776c2d6bbe34 -o none
```

## VOR dem Workshop

```pwsh
# Users zurücksetzen (Passwörter + MFA)
gh workflow run "1 - Reset Users" --repo cpinotossi/msftmh
# Runner starten (s.o.)
# Credentials Artifact herunterladen
gh run download $(gh run list --workflow="odaa-reset-users.yml" --repo cpinotossi/msftmh --limit 1 --json databaseId -q ".[0].databaseId") --repo cpinotossi/msftmh

# Shared Infra deployen (Gallery, ODAA VNets, Anchor)
gh workflow run "1 - Deploy Shared" --repo cpinotossi/msftmh
# Runner starten

# User VMs deployen (user_count in users/terraform.tfvars setzen, push triggert automatisch)
gh workflow run "2 - Deploy Workshop" --repo cpinotossi/msftmh
# Runner starten
```

## NACH dem Workshop

```pwsh
# 1. Oracle DBs manuell löschen (Azure Portal)
# 2. Cleanup (Passwörter rotieren + VMs löschen)
gh workflow run "3 - Cleanup Workshop" --repo cpinotossi/msftmh -f confirmation=CLEANUP
# Runner starten
```

## Terraform Import/State Fix

```pwsh
gh workflow run "4 - Terraform Import" --repo cpinotossi/msftmh -f project=shared -f import_file="lab-env/import-file.txt" -f dry_run=false
gh workflow run "4 - Terraform Import" --repo cpinotossi/msftmh -f project=users -f imports="rm: tls_private_key.workshop" -f dry_run=false
# Runner starten
```
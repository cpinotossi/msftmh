# Oracle Database @ Azure - Workshop Infrastructure

## Struktur

```text
infra/
├── ansible/           # Ansible Playbooks (oracle-tools)
├── github-runner/     # Self-hosted Runner (einmalig, lokal)
├── identity/          # Entra ID Users (einmalig, lokal)
├── modules/           # Terraform Module
│   ├── entra-id/      #   Entra ID (verwendet von identity/)
│   ├── user-vm/       #   User VM (verwendet von users/)
│   └── vnet-peering/  #   VNet Peering (verwendet von users/)
├── packer/            # VM Image Build (Packer + Ansible)
├── scripts/           # PowerShell Utility Scripts
├── shared/            # Shared Infra: Gallery, ODAA VNets, Role Defs
└── users/             # Per-User: VMs, ODAA RGs, Peerings
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

Alle Workflows werden via `git commit` + `push` getriggert. Die Reihenfolge ist wichtig.

### Schritt 1: Users zurücksetzen (Passwörter + MFA)

Wert des Atribute "mh-name" änderung im File `users/user_credentials.template.json`. Das triggert den Reset-Workflow.

```pwsh
# z.B. mh-name setzen oder beliebige Änderung am Template
cd 03-Azure/01-03-Infrastructure/10_Oracle_on_Azure/infra
code users/user_credentials.template.json

git add users/user_credentials.template.json
git commit -m "FRA-MH-20260421"
git push
# Workflow status prüfen
gh run list --workflow="odaa-reset-users.yml" --repo cpinotossi/msftmh --limit 1
# Wartet bis zum Abschluss und zeigt Ergebnis
gh run watch $(gh run list --workflow="odaa-reset-users.yml" --repo cpinotossi/msftmh --limit 1 --json databaseId -q ".[0].databaseId") --repo cpinotossi/msftmh --exit-status
# Credentials Artifact herunterladen
gh run download $(gh run list --workflow="odaa-reset-users.yml" --repo cpinotossi/msftmh --limit 1 --json databaseId -q ".[0].databaseId") --repo cpinotossi/msftmh
```

### Schritt 2: Workshop deployen (Shared + User VMs)

Änderung an `users/terraform.tfvars` (z.B. `user_count`) triggert den Deploy-Workshop-Workflow.

```pwsh
code users/terraform.tfvars
# user_count anpassen, dann:
git add users/terraform.tfvars
git commit -m "deploy workshop user_count=25"
git push
# Workflow status prüfen
gh run list --workflow="odaa-deploy-workshop.yml" --repo cpinotossi/msftmh --limit 1
# Wartet bis zum Abschluss und zeigt Ergebnis
gh run watch $(gh run list --workflow="odaa-deploy-workshop.yml" --repo cpinotossi/msftmh --limit 1 --json databaseId -q ".[0].databaseId") --repo cpinotossi/msftmh --exit-status
```

> **Hinweis:** Shared Infra (`1 - Deploy Shared`) muss vorher deployed sein. Falls nicht, manuell triggern:
> ```pwsh
> gh workflow run "1 - Deploy Shared" --repo cpinotossi/msftmh
> ```

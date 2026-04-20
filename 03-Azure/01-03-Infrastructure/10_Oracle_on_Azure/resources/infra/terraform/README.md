# Oracle Workshop CI/CD

## Struktur

```
terraform/
├── identity/       # Entra ID Users (einmalig)
├── github-runner/  # Self-hosted Runner (einmalig)
├── lab-env/        # Workshop VMs + ODAA
└── scripts/        # manage-users.ps1
```

## Einmalige Einrichtung

```pwsh
# 1. Users erstellen
cd identity && terraform apply

# 2. GitHub Runner deployen
cd github-runner && terraform apply
```

## Workshop-Ablauf

### VOR dem Workshop

```pwsh
# 1. Users zurücksetzen
gh workflow run "1 - Reset Users"

# 2. Auf Completion warten und Artifact downloaden
gh run watch
gh run download --name user-credentials-*

# 3. user_count setzen und deployen
code lab-env/terraform.tfvars  # user_count = 15
git add lab-env/terraform.tfvars
git commit -m "Deploy 15 users"
git push
```

### NACH dem Workshop

```pwsh
# 1. Oracle DBs manuell löschen (Azure Portal)

# 2. Cleanup
gh workflow run "3 - Cleanup Workshop" -f confirmation=CLEANUP
```

## Pipelines

| Workflow | Trigger | Aktion |
|----------|---------|--------|
| 1 - Reset Users | Manuell | Passwörter rotieren + MFA löschen |
| 2 - Deploy Workshop | Push auf `lab-env/terraform.tfvars` | VMs deployen |
| 3 - Cleanup Workshop | Manuell + "CLEANUP" | Passwörter rotieren + VMs löschen |

## Single Source of Truth

`lab-env/user_credentials.json` - Einzige Credentials-Datei
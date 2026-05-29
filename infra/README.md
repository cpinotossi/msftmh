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

## After the Workshop

### Step 1: Delete Oracle Databases

Users must delete all Oracle Autonomous Databases they created during the workshop **before** running cleanup. This must be done manually via the Azure Portal or CLI because ODAA resources are co-managed with Oracle and cannot be destroyed by Terraform.

### Step 2: Run the Cleanup Workflow

The cleanup workflow resets all passwords + MFA (invalidating old credentials) and destroys user VMs by setting `user_count=0`. Shared infrastructure (Gallery, VNets, Role Definitions) remains intact for the next workshop.

```pwsh
gh workflow run "3 - Cleanup Workshop" --repo cpinotossi/msftmh -f confirmation=CLEANUP
# Wait for completion
gh run watch $(gh run list --workflow="odaa-cleanup-workshop.yml" --repo cpinotossi/msftmh --limit 1 --json databaseId -q ".[0].databaseId") --repo cpinotossi/msftmh --exit-status
```

> **Note:** The workflow requires typing `CLEANUP` as confirmation. If Oracle databases still exist, the workflow will fail unless you pass `skip_oracle_check=true`.

## Workflows

All CI/CD workflows run on a self-hosted GitHub Actions runner deployed as a Container Apps Job in `sub-mhcore`.

| # | Workflow | Trigger | Purpose |
|---|----------|---------|---------|
| 0 | `0 - Build Image` | `workflow_dispatch` (manual) | Builds the VM image via Packer + Ansible, publishes to Azure Compute Gallery. Input: `image_version` (semver). |
| 1a | `1 - Deploy Shared` | `workflow_dispatch` (manual) | Deploys shared infrastructure: Compute Gallery, ODAA VNets, Role Definitions. Run once before first workshop. |
| 1b | `1 - Reset Users` | Push to `infra/users/user_credentials.template.json` | Rotates passwords and clears MFA for all 25 users. Uploads new credentials as artifact. |
| 2 | `2 - Deploy Workshop` | Push to `infra/users/terraform.tfvars` | Deploys per-user infrastructure (VMs, VNets, Peerings, Bastion, NAT Gateway) based on `user_count`. |
| 3a | `3 - Test Workshop` | After `2 - Deploy Workshop` completes, or manual | End-to-end challenge tests. Creates a test ADB, runs BATS tests on a test-runner VM, cleans up. |
| 3b | `3 - Cleanup Workshop` | `workflow_dispatch` (manual) | Post-workshop cleanup. Resets passwords + MFA, destroys user VMs (`user_count=0`). Requires `CLEANUP` confirmation. |
| 4 | `4 - Terraform Import` | `workflow_dispatch` (manual) | Imports existing Azure resources into Terraform remote state. Supports `shared` or `users` project. Dry-run mode available. |

### Workflow Execution Order

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ 0 - Build    │     │ 1 - Deploy   │     │ 1 - Reset    │     │ 2 - Deploy   │
│    Image     │────▶│   Shared     │     │   Users      │     │   Workshop   │
│  (one-time)  │     │  (one-time)  │     │  (per event) │     │  (per event) │
└──────────────┘     └──────────────┘     └──────┬───────┘     └──────┬───────┘
                                                  │                    │
                                                  │    ┌───────────────┘
                                                  ▼    ▼
                                           ┌──────────────┐
                                           │ 3 - Test     │
                                           │   Workshop   │
                                           │  (automatic) │
                                           └──────────────┘

                     After workshop:
                     ┌──────────────┐
                     │ 3 - Cleanup  │
                     │   Workshop   │
                     │   (manual)   │
                     └──────────────┘
```

## Test Framework

The workshop includes an end-to-end test suite that validates all four challenges using [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System).

### Structure

```text
tests/
├── bicep/
│   ├── adb-test.bicep          # Bicep template to create a test ADB instance
│   └── adb-test.json           # Compiled ARM template
├── helpers/
│   └── setup.bash              # Shared test setup (BATS helpers, env vars, Azure login)
├── challenge-1-odaa-sub.bats   # Tests: ODAA subscription and shared infra exist
├── challenge-2-create-adb.bats # Tests: ADB instance is created and available
├── challenge-3-nsg-dns.bats    # Tests: NSG rules and DNS configuration
├── challenge-4-perf-test.bats  # Tests: Performance tools available, ADB reachable
└── run-tests.sh                # Test runner entry point
```

### How It Works

1. The `3 - Test Workshop` workflow deploys a **test-runner VM** using the same Gallery image as user VMs.
2. It creates a dedicated test ADB (`adbtest00`) via Bicep, adds NSG rules via OCI CLI, and creates DNS records.
3. Test files are deployed to the VM and executed via `az vm run-command`.
4. After tests complete, the test ADB is deleted automatically.

The tests run independently of `user_count` — no user VMs are required.

### Challenge Coverage

| Test File | Challenge | What It Validates |
|-----------|-----------|-------------------|
| `challenge-1-odaa-sub.bats` | ODAA Subscription | Shared resource group, VNet, and delegated subnet exist |
| `challenge-2-create-adb.bats` | Create ADB | ADB is provisioned, available, and has correct properties (CPU, storage, workload type) |
| `challenge-3-nsg-dns.bats` | NSG + DNS | Private DNS zone exists, is linked to VNet, A-record resolves, NSG allows port 1522 |
| `challenge-4-perf-test.bats` | Performance Test | `connping` and `adbping` binaries available, ADB is reachable on port 1522, `rwloadsim` is installed |

### Running Tests Manually

```pwsh
gh workflow run "3 - Test Workshop" --repo cpinotossi/msftmh
gh run watch $(gh run list --workflow="odaa-test-workshop.yml" --repo cpinotossi/msftmh --limit 1 --json databaseId -q ".[0].databaseId") --repo cpinotossi/msftmh --exit-status
```

# Terraform Infrastructure Consolidation Analysis

## Research Topics

1. Current file/folder count and structure
2. Module and root config inventory (resources, providers, variables, outputs)
3. Dependency graph between configs
4. Consolidation recommendations with rationale
5. Proposed new structure with estimated file count
6. Risks and trade-offs

---

## 1. Current File/Folder Count

**93 total files** under `resources/infra/` (excluding `.terraform`, `.git`, lock files).

### Breakdown by Area

| Area | Terraform Files | Other Files | Total |
|------|----------------|-------------|-------|
| `lab-env/modules/shared/` | 4 (main, outputs, variables, versions) | — | 4 |
| `lab-env/modules/shared-odaa/` | 4 (main, outputs, variables, versions) | — | 4 |
| `lab-env/modules/user-vm/` | 4 (main, outputs, variables, versions) | — | 4 |
| `lab-env/modules/user-odaa/` | 4 (main, outputs, variables, versions) | — | 4 |
| `lab-env/modules/vnet-peering/` | 3 (main, outputs, variables) | — | 3 |
| `lab-env/shared/` | 7 (main, outputs, providers, backend, variables, versions, tfvars) | — | 7 |
| `lab-env/users/` | 9 (main, data, outputs, providers, backend, variables, versions, tfvars, template) | — | 9 |
| `identity/` | 5 (main, outputs, providers, variables, versions) | 1 (README) | 6 |
| `github-runner/` | 5 (main, outputs, providers, variables, versions) | 6 (README, role-assignment.json, tfstate, tfstate.backup, tfvars, tfvars.example) | 11 |
| `packer/` (root) | — | 2 (pkr.hcl, vars example) | 2 |
| `packer/packer/` | — | 6 (pkr.hcl, build-image.ps1, README, .gitignore, vars example, ansible playbook, install script) | 7 |
| Other (ansible, adbping, connping, k8s, scripts, .devcontainer, etc.) | — | ~37 | ~37 |

**Terraform-specific file count: ~54 files** across 4 root configs + 5 modules.

---

## 2. Module and Root Config Inventory

### Module: `shared` (lab-env/modules/shared/)

- **Resources (4):** `azurerm_resource_group.shared`, `azurerm_shared_image_gallery.gallery`, `tls_private_key.workshop` (conditional), `azurerm_ssh_public_key.workshop` (conditional), `azurerm_shared_image.oracle_workshop`
- **Providers:** `azurerm ~> 4.0`, `tls ~> 4.0`
- **Variables (6):** `prefix`, `location`, `gallery_name`, `image_name`, `create_ssh_key`, `tags`
- **Outputs (8):** `resource_group_name`, `resource_group_id`, `gallery_id`, `gallery_name`, `image_id`, `image_name`, `ssh_public_key`, `ssh_private_key`
- **Notes:** SSH key creation is conditional (`create_ssh_key`). In practice, `shared/` root config calls this with `create_ssh_key = false`; the SSH key is created directly in `users/` root config instead.

### Module: `shared-odaa` (lab-env/modules/shared-odaa/)

- **Resources (6):** `azurerm_resource_group.shared_odaa`, `azurerm_virtual_network.shared_odaa`, `azurerm_subnet.shared_odaa` (with Oracle delegation), `azurerm_virtual_network.basedb`, `azurerm_subnet.basedb` (with Oracle delegation), `azapi_resource.resource_anchor`
- **Providers:** `azurerm ~> 4.0`, `azapi ~> 2.0`
- **Variables (4):** `location`, `vnet_cidr`, `basedb_vnet_cidr`, `tags`
- **Outputs (11):** `resource_group_name`, `resource_group_id`, `vnet_id`, `vnet_name`, `subnet_id`, `subnet_name`, `basedb_vnet_id`, `basedb_vnet_name`, `basedb_subnet_id`, `basedb_subnet_name`, `resource_anchor_id`

### Module: `user-vm` (lab-env/modules/user-vm/)

- **Resources (~18):** RG, VNet, 2x Subnet (vm + bastion conditional), NAT Gateway + PIP + associations (3 conditional), NSG + association, Public IP (conditional), Bastion PIP + Bastion host (conditional), NIC, Linux VM, AAD login extension (conditional), 4x RBAC role assignments (conditional), Private DNS Zone (conditional), DNS zone VNet link (conditional)
- **Providers:** `azurerm ~> 4.0`
- **Variables (19):** `user_index`, `location`, `vnet_cidr`, `vm_size`, `vm_image_id`, `admin_username`, `admin_ssh_public_key`, `os_disk_type`, `os_disk_size_gb`, `create_public_ip`, `enable_bastion`, `bastion_sku`, `enable_nat_gateway`, `create_dns_link`, `dns_zone_id`, `dns_zone_name`, `dns_zone_resource_group`, `tags`, `enable_entra_id_login`, `entra_id_user_object_id`, `entra_id_admin_login`
- **Outputs (13):** `resource_group_name`, `resource_group_id`, `vnet_id`, `vnet_name`, `subnet_id`, `vm_id`, `vm_name`, `private_ip_address`, `public_ip_address`, `bastion_host_name`, `bastion_public_ip_address`, `user_index`, `dns_zone_name`, `dns_zone_resource_group`, `dns_zone_id`
- **Notes:** Most complex module. Handles VM, networking, DNS, Bastion, NAT, Entra ID login, RBAC.

### Module: `user-odaa` (lab-env/modules/user-odaa/)

- **Resources (2):** `azurerm_resource_group.odaa`, `azurerm_role_assignment.odaa_db_creator` (conditional)
- **Providers:** `azurerm ~> 4.0`
- **Variables (5):** `user_index`, `location`, `tags`, `entra_id_user_object_id`, `odaa_role_definition_id`
- **Outputs (3):** `resource_group_name`, `resource_group_id`, `user_index`
- **Notes:** Very thin module — only creates an RG and a single RBAC assignment.

### Module: `vnet-peering` (lab-env/modules/vnet-peering/)

- **Resources (2):** `azurerm_virtual_network_peering.vm_to_odaa`, `azurerm_virtual_network_peering.odaa_to_vm`
- **Providers:** `azurerm ~> 4.0` with **configuration_aliases** `[azurerm.mh0, azurerm.mhodaa]` (cross-subscription)
- **Variables (8):** `vm_vnet_id`, `vm_vnet_name`, `vm_resource_group`, `odaa_vnet_id`, `odaa_vnet_name`, `odaa_resource_group`, `peering_suffix`, `tags`
- **Outputs (4):** `vm_to_odaa_peering_id`, `odaa_to_vm_peering_id`, `vm_vnet_info`, `odaa_vnet_info`
- **Notes:** No versions.tf (provider version declared inline in main.tf). Reusable — called twice per user (ADB peering + BaseDB peering).

### Root Config: `shared/` (lab-env/shared/)

- **Modules called:** `shared`, `shared_odaa`
- **Direct resources (2):** `azurerm_role_definition.odaa_db_creator` (with import block), `azurerm_role_assignment.shared_odaa_group`
- **Provider aliases:** `azurerm.mhcore` (sub-mhcore), `azurerm.mhodaa` (sub-mhodaa), `azapi` (sub-mhodaa)
- **Auth:** MSI (`use_msi=true, use_cli=false`)
- **Backend:** `azurerm` with key `shared.tfstate`
- **Variables (9):** `tenant_id`, `mhcore_subscription_id`, `mhodaa_subscription_id`, `location`, `gallery_name`, `image_name`, `odaa_vnet_cidr`, `basedb_vnet_cidr`, `odaa_user_group_id`, `tags`
- **Outputs (10):** Passes through module outputs (gallery, ODAA VNet info, role definition ID)

### Root Config: `users/` (lab-env/users/)

- **Modules called:** `user_vm` (for_each), `user_odaa` (for_each), `peering` (for_each), `peering_basedb` (for_each)
- **Direct resources (1):** `tls_private_key.workshop`
- **Data sources (1):** `terraform_remote_state.shared` — reads from `shared.tfstate`
- **Provider aliases:** `azurerm.mh0` (sub-mh0), `azurerm.mhodaa` (sub-mhodaa)
- **Auth:** MSI (`use_msi=true, use_cli=false`)
- **Backend:** `azurerm` with key `users.tfstate`
- **Variables (20):** `tenant_id`, `mh0_subscription_id`, `mhodaa_subscription_id`, `tf_state_storage`, `tf_state_container`, `tf_state_rg`, `tf_state_use_azuread_auth`, `location`, `user_count`, `vm_size`, `vm_os_disk_type`, `vm_os_disk_size_gb`, `admin_username`, `vm_image_version`, `create_public_ip`, `enable_bastion`, `bastion_sku`, `enable_nat_gateway`, `odaa_dns_zone_name`, `enable_entra_id_login`, `entra_id_admin_login`, `user_object_ids`, `tags`
- **Outputs (4):** `user_vm_info`, `user_odaa_rgs`, `ssh_commands`, `ssh_private_key`

### Root Config: `identity/`

- **Modules called:** `entra_id_users` (source `../modules/entra-id` — **MODULE MISSING from repo**)
- **Direct resources (2):** `local_file.user_credentials`, `null_resource.mfa_reset` (conditional)
- **Providers:** `azuread` (client_id/client_secret auth — service principal)
- **Backend:** None visible (likely local state or managed externally)
- **Variables (8):** `microhack_event_name`, `user_count`, `tenant_id`, `client_id`, `client_secret`, `entra_user_principal_domain`, `azuread_propagation_wait_seconds`, `user_reset_trigger`
- **Outputs (6):** `user_object_ids`, `user_principal_names`, `group_object_id`, `user_credentials_file`, `user_count`, `microhack_event_name`
- **Notes:** Uses `azuread` provider (different from azurerm). Writes credentials JSON to `lab-env/user_credentials.json`. References missing module `../modules/entra-id`.

### Root Config: `github-runner/`

- **Modules called:** `github_runner` (AVM external module `Azure/avm-ptn-cicd-agents-and-runners/azurerm ~> 0.5`)
- **Direct resources (~12):** RG, User-Assigned MI, 6x RBAC role assignments (Contributor + UAA across 3 subs), Storage Account, Storage Container, RBAC for storage, Subnet for PE, Private DNS Zone + VNet link, Private Endpoint, `terraform_data.keda_labels`
- **Providers:** `azurerm` (sub-mhcore, `use_cli=true`), `random`
- **Auth:** CLI auth (`use_cli=true` — different from lab-env configs which use MSI)
- **Backend:** None (uses local `terraform.tfstate` — committed to repo!)
- **Variables (23):** Auth, subscriptions, location, GitHub config, tags, resource names, VNet config
- **Outputs (4):** `runner_resource_group`, `avm_module_outputs`, `managed_identity`, `terraform_state_storage`, `workflow_env_vars`
- **Notes:** Self-contained bootstrap config. Has local state files in repo. Deployed manually with CLI auth. No relationship to shared/users state.

---

## 3. Dependency Graph

```
github-runner/  (standalone, manual deploy, local state)
    └── Provisions: MI, Storage Account, Container Apps runner
    └── Outputs: TF state storage details used by shared/ and users/ backend configs

identity/  (standalone, separate SP auth, likely local state)
    └── References: ../modules/entra-id (MISSING MODULE)
    └── Outputs: user_credentials.json → consumed by humans
    └── Outputs: user_object_ids → manually copied to users/terraform.tfvars

lab-env/shared/  (azurerm backend, shared.tfstate)
    ├── Calls: modules/shared (azurerm.mhcore)
    ├── Calls: modules/shared-odaa (azurerm.mhodaa + azapi)
    ├── Creates: Custom role definition + group RBAC
    └── Outputs → consumed by users/ via terraform_remote_state

lab-env/users/  (azurerm backend, users.tfstate)
    ├── Reads: terraform_remote_state("shared") → shared.tfstate
    ├── Calls: modules/user-vm (for_each, azurerm.mh0)
    ├── Calls: modules/user-odaa (for_each, azurerm.mhodaa)
    ├── Calls: modules/vnet-peering (for_each x2, azurerm.mh0 + azurerm.mhodaa)
    └── Creates: SSH key pair

packer/  (standalone, no TF state — Packer tool)
    └── Reads: Compute Gallery from shared/ resources
    └── TWO VERSIONS of oracle-workshop.pkr.hcl exist
```

### Cross-config Data Flow

```
github-runner/ ──(storage account details)──> shared/ backend config (manual)
github-runner/ ──(storage account details)──> users/ backend config (manual)
identity/      ──(user_object_ids)──────────> users/ terraform.tfvars (manual copy)
identity/      ──(group_object_id)──────────> shared/ terraform.tfvars (manual copy)
shared/        ──(terraform_remote_state)───> users/ data.tf (automated)
```

---

## 4. Consolidation Analysis

### 4A. Can `shared/` and `users/` merge into one root config?

**Recommendation: NO — keep separate.**

Rationale:
- Different lifecycle: `shared/` is deployed once and rarely changes (gallery, VNets, role definitions). `users/` scales dynamically with `user_count` and changes per workshop event.
- Different subscription scopes: `shared/` uses `mhcore` + `mhodaa`. `users/` uses `mh0` + `mhodaa`. Merging would add a third provider alias.
- State blast radius: Keeping shared infra in a separate state file limits risk. A bad `terraform destroy` in `users/` won't touch the gallery or ODAA VNets.
- The `terraform_remote_state` pattern between them is clean and well-documented.

**Trade-off if merged:** Simpler CI (one `terraform apply` instead of two), but larger blast radius and slower plans (every plan refreshes all shared resources even when only changing user count).

### 4B. Can `user-odaa` be inlined into `users/` root config?

**Recommendation: YES — strong candidate for inlining.**

Rationale:
- Only 2 resources (RG + 1 RBAC assignment) — trivially small
- Only called from one place (`users/main.tf`)
- 4 files (main, outputs, variables, versions) for 2 resources is overhead
- Inlining saves 4 files and removes one module interface layer

Risk: Minimal. The resources are simple. The for_each pattern works the same with inline resources.

### 4C. Can `shared` module be inlined into `shared/` root config?

**Recommendation: MAYBE — moderate candidate.**

Rationale:
- 4 resources, only called from one place
- The `create_ssh_key` conditional is unused (`shared/` always passes `false`)
- But the module provides clean separation and could theoretically be reused

Risk: Low. But inlining saves only 4 files, and the module does provide conceptual separation (compute gallery concerns vs ODAA concerns).

### 4D. Can `shared-odaa` module be inlined into `shared/` root config?

**Recommendation: MAYBE — similar to shared module.**

Rationale:
- 6 resources, only called from one place
- Uses `azapi` provider (resource anchor) which adds complexity
- Clean conceptual boundary (ODAA networking)

Risk: Low, but the module keeps ODAA concerns nicely separated.

### 4E. Can `vnet-peering` module be simplified?

**Recommendation: KEEP as module — strong justification.**

Rationale:
- Used twice per user (ADB peering + BaseDB peering) = real reuse
- Cross-subscription provider aliases require module-level `configuration_aliases`
- Already lean (3 files, no versions.tf)

### 4F. Can modules use fewer files?

**Recommendation: YES — `versions.tf` can be eliminated from modules.**

Rationale:
- `vnet-peering` already demonstrates this: provider requirements inline in `main.tf`
- For modules, Terraform inherits provider versions from the root config. Module `versions.tf` files are advisory only.
- Removing `versions.tf` from `shared`, `shared-odaa`, `user-vm`, `user-odaa` saves 4 files
- Very small modules like `user-odaa` could be a single file (main.tf with outputs and variables inline), though this is unconventional

Risk: None for removing module `versions.tf`. Terraform docs recommend it but it's not required for child modules.

### 4G. Packer duplication

**Recommendation: ELIMINATE — remove `packer/oracle-workshop.pkr.hcl` (the outer one).**

Findings:
- `packer/oracle-workshop.pkr.hcl` — older version, uses `ansible` (remote) provisioner, references `../ansible/playbooks/oracle-tools.yml`
- `packer/packer/oracle-workshop.pkr.hcl` — newer version, uses `ansible-local` provisioner, has its own `ansible/oracle-tools.yml`, more robust generalization
- The nested `packer/packer/` is the actively developed version with build scripts, README, ansible playbook, and install script
- The outer `packer/oracle-workshop.pkr.hcl` appears to be a leftover from before the refactor

**Action:** Delete `packer/oracle-workshop.pkr.hcl` and `packer/variables.pkrvars.hcl.example`. Optionally move `packer/packer/` contents up to `packer/`.

Risk: Low if the outer file is truly unused. Verify by checking CI workflows.

### 4H. Can `identity/` and `github-runner/` merge?

**Recommendation: NO — keep separate.**

Rationale:
- Completely different concerns: Entra ID user management vs CI/CD infrastructure
- Different auth methods: `identity/` uses service principal (`client_id`/`client_secret`), `github-runner/` uses CLI auth
- Different providers: `identity/` uses `azuread`, `github-runner/` uses `azurerm` + `azapi`
- Different lifecycles: `identity/` runs per-event (create users), `github-runner/` is a one-time bootstrap
- `github-runner/` has local state committed to repo (intentional for bootstrap)

### 4I. `identity/` missing module

**Finding:** `identity/main.tf` references `source = "../modules/entra-id"` but no `modules/entra-id` directory exists in the repo. This config cannot run as-is. The module is either:
- Not yet created
- In a different location
- Was deleted/moved without updating the reference

---

## 5. Proposed Consolidation

### Changes (conservative approach)

| # | Change | Files Removed | Rationale |
|---|--------|--------------|-----------|
| 1 | Inline `user-odaa` into `users/main.tf` | -4 (module files) | 2 resources, single caller |
| 2 | Remove `versions.tf` from all 4 modules (merge into `main.tf` where needed) | -4 | Advisory only in child modules |
| 3 | Delete outer `packer/oracle-workshop.pkr.hcl` + `packer/variables.pkrvars.hcl.example` | -2 | Superseded by `packer/packer/` |
| 4 | Move `packer/packer/*` up to `packer/` and delete empty `packer/packer/` dir | 0 (reorganize) | Eliminate confusing nested structure |

**Estimated file reduction: 10 files** (93 → 83)

### More aggressive approach (additional)

| # | Change | Files Removed | Rationale |
|---|--------|--------------|-----------|
| 5 | Inline `shared` module into `shared/main.tf` | -4 | Single caller, unused SSH conditional |
| 6 | Inline `shared-odaa` module into `shared/main.tf` | -4 | Single caller |
| 7 | Merge `user-vm` outputs + variables into main.tf | Not recommended | Unconventional, hurts readability |

**Aggressive total: ~18 files removed** (93 → 75)

### Proposed Directory Structure (conservative)

```
resources/infra/
├── lab-env/
│   ├── modules/
│   │   ├── shared/          (3 files: main.tf, outputs.tf, variables.tf)
│   │   ├── shared-odaa/     (3 files: main.tf, outputs.tf, variables.tf)
│   │   ├── user-vm/         (3 files: main.tf, outputs.tf, variables.tf)
│   │   └── vnet-peering/    (3 files: main.tf, outputs.tf, variables.tf)  [unchanged]
│   ├── shared/              (7 files — unchanged)
│   └── users/               (9 files — user-odaa inlined into main.tf)
├── identity/                (6 files — unchanged, needs entra-id module fix)
├── github-runner/           (11 files — unchanged)
├── packer/                  (flattened: pkr.hcl, ansible/, scripts/, build-image.ps1, etc.)
├── ansible/                 (unchanged)
├── adbping/                 (unchanged)
├── connping/                (unchanged)
├── k8s/                     (unchanged)
└── scripts/                 (unchanged)
```

---

## 6. Risks and Trade-offs Summary

| Change | Risk | Trade-off |
|--------|------|-----------|
| Inline `user-odaa` | **Low** — simple resources, same for_each pattern | Slightly larger `users/main.tf`, but fewer files to navigate |
| Remove module `versions.tf` | **None** — root configs already enforce versions | Lose per-module version documentation (minor) |
| Delete outer packer template | **Low** — verify no CI references | Cleaner packer structure |
| Flatten `packer/packer/` | **Low** — path references in CI need updating | Less confusing directory structure |
| Inline `shared` module | **Medium** — loses module abstraction | Mixes gallery + ODAA concerns in one file if both inlined |
| Inline `shared-odaa` module | **Medium** — same as above | Provider passing becomes implicit instead of explicit |
| Merge `shared/` + `users/` | **High** — larger blast radius, 3 provider aliases, slower plans | Single apply, but not worth the operational risk |
| Merge `identity/` + `github-runner/` | **High** — incompatible auth, providers, lifecycles | No benefit |

---

## 7. Additional Findings

### Security Concern: `github-runner/terraform.tfstate` in repo
The `github-runner/` directory has `terraform.tfstate` and `terraform.tfstate.backup` committed to the repository. These files may contain sensitive information (principal IDs, subscription IDs, resource IDs). Consider:
- Adding to `.gitignore`
- Moving state to remote backend

### Missing Module: `modules/entra-id`
The `identity/main.tf` references `source = "../modules/entra-id"` but this module directory does not exist. This needs to be created or the reference updated.

### Duplicate `terraform.tfvars`
There is a file at `terraform/github-runner/terraform.tfvars` (outside the `resources/infra/` tree) that appears to be a duplicate or misplaced copy.

---

## Follow-on Questions

1. Is the outer `packer/oracle-workshop.pkr.hcl` referenced by any GitHub Actions workflow?
2. Where is the `modules/entra-id` module? Was it deleted, or does it live in a different repo?
3. Is the `github-runner/terraform.tfstate` committed intentionally, or should it be gitignored?
4. Is the `terraform/github-runner/terraform.tfvars` file (outside infra/) an active duplicate?

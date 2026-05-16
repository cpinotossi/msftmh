# Research: Workflow Triggers and Their Relationship

## Questions Investigated

1. What does each workflow do?
2. What are the exact trigger paths for each workflow?
3. What is in terraform.tfvars and what is in user_credentials.template.json?
4. Why does Step 1 (Reset Users) use user_credentials.template.json as trigger?
5. Why does Step 2 (Deploy Workshop) use terraform.tfvars as trigger?
6. Is there a logical dependency between the two steps?
7. Are both steps always required or only in certain scenarios?

---

## Workflow Analysis

### Workflow: `odaa-reset-users.yml` — "1 - Reset Users"

**Purpose:** Rotates passwords for ALL 25 workshop users and clears their MFA registrations (Authenticator app, etc.). Exports a timestamped `user_credentials_<timestamp>.json` as a GitHub artifact.

**Trigger path:**
```
03-Azure/01-03-Infrastructure/10_Oracle_on_Azure/resources/infra/lab-env/users/user_credentials.template.json
```

**What it does:**
1. Copies `user_credentials.template.json` to `user_credentials.json` (working file).
2. Logs into Azure via Managed Identity.
3. Runs `manage-users.ps1 -Action "reset-all"` which rotates passwords and clears MFA via Graph API.
4. Uploads the generated credentials file as an artifact (90-day retention).

**Concurrency group:** `workshop` (serialized, never cancels in-progress).

---

### Workflow: `odaa-deploy-workshop.yml` — "2 - Deploy Workshop"

**Purpose:** Deploys per-user Azure infrastructure (VMs, VNets, ODAA resource groups, peerings, Bastion, NAT Gateway) using Terraform. The number of users deployed is controlled by `user_count` in `terraform.tfvars`.

**Trigger path:**
```
03-Azure/01-03-Infrastructure/10_Oracle_on_Azure/resources/infra/lab-env/users/terraform.tfvars
```

**What it does:**
1. Installs Terraform 1.13.4.
2. Logs into Azure via Managed Identity with MSI proxy (translates API versions for Container Apps).
3. Runs `terraform init` with remote state backend (Azure Storage).
4. Runs `terraform apply -auto-approve` to deploy/update user infrastructure.
5. Outputs Terraform results in the workflow summary.

**Concurrency group:** `workshop-users` (serialized, never cancels in-progress).

---

### Workflow: `odaa-deploy-shared.yml` — "1 - Deploy Shared"

**Purpose:** Deploys shared infrastructure that all users depend on: Compute Gallery, ODAA VNets (shared + basedb), Role Definitions, and Resource Anchors.

**Trigger path:**
```
03-Azure/01-03-Infrastructure/10_Oracle_on_Azure/resources/infra/lab-env/shared/**
```

**What it does:**
1. Same Terraform + MSI proxy pattern as Deploy Workshop.
2. Applies Terraform in the `lab-env/shared/` directory.
3. Deploys to `sub-mhodaa` (ODAA subscription) — VNets, role definitions, etc.

**Concurrency group:** `workshop-shared` (serialized).

---

## File Contents

### `terraform.tfvars`

Configuration variables for the per-user Terraform deployment:
- **`user_count = 1`** — Controls how many users (0–25) get infrastructure deployed.
- **`location`** — Azure region (`francecentral`).
- **VM settings** — Size, disk type, disk size, image version, Bastion/NAT config.
- **ODAA settings** — DNS zone name for Oracle Database at Azure.
- **Entra ID login settings** — Whether to enable Entra ID login on VMs.
- **`user_object_ids`** — Map of user index to Entra ID Object ID (all 25 users).
- **Tags** — Standard tagging for the project.

### `user_credentials.template.json`

A JSON template file containing:
- **`mh-name`** — Workshop event identifier (e.g., `"FRANKURT-MH-20260421"`). This is the field operators edit to trigger the workflow.
- **`generated_at`** — Timestamp of last generation.
- **`group`** — Entra ID group info (`mh-odaa-user-grp` with its object ID).
- **`user_count`** — Number of users (25).
- **`users`** — Map of all 25 users with: display_name, object_id, user_principal_name, and `"password": "TO_BE_GENERATED"` placeholder.

---

## Why user_credentials.template.json Triggers Reset Users

The template serves as the **input manifest** for the reset script. It defines:
- Which users exist (their UPNs, object IDs).
- The workshop event name (`mh-name`) — editing this field is the intended "trigger action."

The workflow copies this template to a working file, then the reset script fills in real passwords. The trigger design is intentional: **the operator edits `mh-name` to a new event name** (e.g., `"BERLIN-MH-20260515"`), commits and pushes. This both:
1. Creates a Git audit trail of which workshop event triggered the reset.
2. Triggers the password rotation workflow via path-based push trigger.

The README confirms this: "Wert des Atribute 'mh-name' änderung im File ... Das triggert den Reset-Workflow."

---

## Why terraform.tfvars Triggers Deploy Workshop

The `terraform.tfvars` file contains `user_count` which is the primary operational parameter. Before each workshop, the operator:
1. Sets `user_count` to the number of attendees needed.
2. Commits and pushes.

This triggers Terraform to provision exactly that many user environments. The trigger is the config file itself because **any change to deployment parameters should re-run the deployment**. Other changes (VM size, location, image version) would also warrant a re-deploy.

---

## Dependency Between Steps

### Is there a logical dependency?

**Yes, partially:**

1. **Step 1 (Reset Users) → Step 2 (Deploy Workshop):** The README prescribes running Step 1 first, but there is **no hard technical dependency** between them. The reset workflow deals with Entra ID (passwords/MFA) while the deploy workflow deals with Azure infrastructure (VMs, VNets). They operate on different planes.

2. **Deploy Shared → Deploy Workshop:** There IS a hard technical dependency. The "Deploy Workshop" workflow requires shared infrastructure (Compute Gallery for VM images, shared ODAA VNets for peering). The README notes: "Shared Infra (`1 - Deploy Shared`) muss vorher deployed sein."

### Why the prescribed order matters operationally:

- If you deploy VMs **before** resetting passwords, participants could log into VMs using old/known credentials before you're ready.
- Resetting first ensures fresh credentials are available when VMs come online.
- The two workflows use different concurrency groups (`workshop` vs `workshop-users`), so they CAN run in parallel — but the README prescribes sequential execution for operational safety.

---

## When Are Steps Required?

| Scenario | Reset Users (Step 1) | Deploy Workshop (Step 2) |
|----------|---------------------|--------------------------|
| New workshop event (fresh start) | **Required** — new passwords for all users | **Required** — deploy user infrastructure |
| Adding more users to existing event | Not needed (passwords already set) | **Required** — increase `user_count` |
| Re-running same workshop (same users, same infra) | **Required** — rotate passwords for security | Not needed (infra already deployed) |
| Changing VM configuration (size, image) | Not needed | **Required** — update `terraform.tfvars` |
| After shared infra changes | Not needed | **May need re-apply** if peering/gallery changed |
| Scaling down users | Not needed | **Required** — decrease `user_count` (Terraform destroys extras) |

---

## Key Discoveries

- The three workflows form a **deployment pipeline**: Shared → Reset Users → Deploy Workshop.
- `Deploy Shared` is a prerequisite for `Deploy Workshop` (hard dependency on VNets/Gallery).
- `Reset Users` and `Deploy Workshop` are operationally sequential but technically independent.
- The trigger mechanism is "edit a tracked file, commit, push" — a GitOps pattern.
- Both `Reset Users` and `Deploy Workshop` also support `workflow_dispatch` for manual triggering without file changes.
- All workflows run on the same self-hosted runner (`[self-hosted, azure, container-apps, terraform]`).

---

## References

- `.github/workflows/odaa-reset-users.yml`
- `.github/workflows/odaa-deploy-workshop.yml`
- `.github/workflows/odaa-deploy-shared.yml`
- `03-Azure/01-03-Infrastructure/10_Oracle_on_Azure/resources/infra/lab-env/users/terraform.tfvars`
- `03-Azure/01-03-Infrastructure/10_Oracle_on_Azure/resources/infra/lab-env/users/user_credentials.template.json`
- `03-Azure/01-03-Infrastructure/10_Oracle_on_Azure/resources/infra/README.md`

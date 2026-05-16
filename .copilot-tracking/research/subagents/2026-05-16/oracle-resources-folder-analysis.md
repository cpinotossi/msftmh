# Oracle on Azure - Resources Folder Analysis

## Research Topics

Analyze each subfolder under `resources/` to determine purpose, key files, and active/stale status.

## Findings

### Folder Analysis Table

| Folder | Purpose | Key Files | Status |
|--------|---------|-----------|--------|
| `resources/scripts/` | PowerShell deployment automation for ODAA MH environments — deploys AKS clusters, ingress, multiple teams in parallel, manages environments, enables Entra SSO for Oracle ADB, and builds/deploys token refresh sidecars. | `Deploy-ODAAMHEnv.ps1`, `Deploy-MultipleEnvironments.ps1`, `Manage-Environments.ps1`, `Enable-EntraSSO-OracleADB.ps1`, `Deploy-TokenRefreshSidecar.ps1`, `Deploy-OracleHAEnvironment.ps1` (placeholder), `refresh-token.sh`, `jwt.ps1`, `Check-AKSIngress.ps1`, `DEPLOYMENT-SCRIPTS-README.md` | **Active** — well-documented, has comprehensive README, used for workshop provisioning. `Deploy-OracleHAEnvironment.ps1` is a placeholder for future HA feature. |
| `resources/template/` | Helm values template for Oracle GoldenGate (OGG) deployment in the workshop challenge (GoldenGate hack scenario). Configures source/target DB connections, schemas, and storage. | `gghack.yaml` | **Active** — used as a participant template during workshop challenges. |
| `resources/infra/` (top-level) | Root infrastructure directory. The README documents the full architecture across 3 Azure subscriptions (sub-mhcore, sub-mh0, sub-mhodaa), git-triggered CI/CD workflow for user reset + workshop deploy, and step-by-step pre-workshop instructions in German. | `README.md`, `Dockerfile.token-refresh`, `.gitignore` | **Active** — authoritative operations runbook for the workshop. |
| `resources/infra/.devcontainer/` | Dev container login helper scripts — authenticates Azure CLI using credentials from `terraform.tfvars` (service principal login). Not a full devcontainer config (no `devcontainer.json`). | `login-sp.ps1`, `login-sp.sh`, `.gitattributes` | **Active/Bootstrap** — utility scripts for operator authentication inside dev container. |
| `resources/infra/adbping/` | Docker container for Oracle ADB network latency testing using Oracle's adbping tool (Doc ID 2863450.1). Includes pre-extracted binary, Dockerfile, and network diagnostic scripts. | `Dockerfile`, `entrypoint.sh`, `network-test.sh`, `build.sh`, `2863450.1-ADBPING_LINUX.X64-*.zip` | **Active** — production-ready container used in workshop K8s deployments. |
| `resources/infra/ansible/` | Ansible playbook for provisioning Oracle Workshop VMs — installs Oracle Instant Client 23.5, SQL*Plus, SQLcl 24.3, Java 17, and base utilities on Ubuntu. Used by Packer during image builds. | `ansible.cfg`, `playbooks/oracle-tools.yml`, `inventory/hosts` | **Active** — integral part of the Packer VM image build pipeline. |
| `resources/infra/connping/` | Docker container for Oracle ADB connection latency testing using rwloadsim (connping/ociping) from Oracle's Real World Performance team. Alternative to adbping with different metrics. | `Dockerfile`, `entrypoint.sh`, `build.sh`, `README.md` | **Active** — production-ready container for K8s-based performance testing. |
| `resources/infra/github-runner/` | Terraform module to deploy a self-hosted GitHub Actions runner on Azure Container Apps. Scales from 0, uses Managed Identity for multi-subscription access, stores tfstate in Azure Blob. Orchestrates all CI/CD workflows for the workshop. | `main.tf`, `providers.tf`, `variables.tf`, `terraform.tfvars`, `terraform.tfvars.example`, `role-assignment.json`, `README.md` | **Active** — core CI/CD infrastructure. Contains `.terraform/` state (deployed). |
| `resources/infra/identity/` | Standalone Terraform config for Entra ID user lifecycle — creates users once, rotates passwords before events, exports `user_credentials.json`. Designed for "create once, rotate passwords only" pattern. | `main.tf`, `providers.tf`, `variables.tf`, `users.json`, `README.md` | **Active** — used pre-workshop for user provisioning. |
| `resources/infra/k8s/` | Pre-configured Kubernetes YAML manifests for deploying adbping and connping containers as Deployments or Jobs on AKS. Participants use these during the workshop. | `namespace.yaml`, `adbping-deployment.yaml`, `adbping-job.yaml`, `connping-deployment.yaml`, `network-test-pod.yaml`, `README.md` | **Active** — workshop challenge materials for participants. |
| `resources/infra/lab-env/` | Main Terraform lab environment split into shared infra and per-user resources. `shared/` creates Compute Gallery, ODAA VNets, role definitions. `users/` creates N user VMs, ODAA RGs, VNet peerings. `modules/` contains reusable TF modules (user-vm, vnet-peering). | `shared/main.tf`, `users/main.tf`, `modules/user-vm/`, `modules/vnet-peering/` | **Active** — primary workshop infrastructure, has `.terraform/` and backend state. |
| `resources/infra/modules/` | Standalone Terraform modules directory. Currently contains only `entra-id/` module for creating Entra ID security groups and RBAC for AKS deployment access. | `entra-id/main.tf`, `entra-id/variables.tf`, `entra-id/outputs.tf` | **Stale/Unclear** — the `entra-id` module is not referenced by lab-env (which uses its own `modules/` subfolder). May be leftover from earlier architecture or used by an external workflow. |
| `resources/infra/packer/` | Packer + Ansible pipeline for building Ubuntu 24.04 VM images with pre-installed Oracle tools (Instant Client, SQLcl, rwloadsim, adbping). Publishes to Azure Compute Gallery. | `oracle-workshop.pkr.hcl`, `build-image.ps1`, `variables.pkrvars.hcl.example`, `ansible/`, `packer/`, `scripts/`, `README.md` | **Active** — essential for creating the workshop VM golden image. |
| `resources/infra/scripts/` | PowerShell helper scripts for infrastructure operations: user management (password rotate + MFA reset), ODAA cleanup/destroy, Packer leftover cleanup, Oracle SDN registration, MFA permission grants. | `manage-users.ps1`, `cleanup-odaa-and-destroy.ps1`, `cleanup-packer-leftovers.ps1`, `register-oracle-sdn.ps1`, `add-mfa-permission.ps1` | **Active** — operational scripts used in CI/CD and pre/post-workshop maintenance. |
| `resources/infra/terraform/` | Residual Terraform directory. After cleanup, only contains `github-runner/terraform.tfvars` — likely a legacy location. The actual github-runner Terraform is in `resources/infra/github-runner/`. | `github-runner/terraform.tfvars` | **Stale** — appears to be a leftover tfvars file. The real github-runner config lives one level up at `resources/infra/github-runner/`. Could be safely removed or is perhaps referenced as a symlink/include. |

## Key Discoveries

1. **Architecture spans 3 subscriptions**: sub-mhcore (gallery, runner), sub-mh0 (user VMs), sub-mhodaa (Oracle ODAA resources).
2. **CI/CD is git-triggered**: Changes to specific files (e.g., `user_credentials.template.json`, `terraform.tfvars`) trigger GitHub Actions workflows via the self-hosted runner.
3. **Two potentially stale items**:
   - `resources/infra/modules/entra-id/` — not referenced by lab-env modules.
   - `resources/infra/terraform/github-runner/terraform.tfvars` — duplicate/leftover from the actual github-runner folder.
4. **The `resources/scripts/` vs `resources/infra/scripts/` split**: Top-level scripts are participant-facing deployment scripts (AKS/Bicep); infra scripts are operator/CI tooling (user mgmt, cleanup).
5. **`Deploy-OracleHAEnvironment.ps1`** is explicitly a placeholder — HA for ODAA is "in development."

## Clarifying Questions

- Is `resources/infra/modules/entra-id/` still used by any workflow or can it be considered stale?
- Is `resources/infra/terraform/github-runner/terraform.tfvars` intentionally kept as a secondary reference, or is it orphaned?

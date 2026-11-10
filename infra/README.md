---
title: Seven-user Base Database workshop infrastructure
description: Prepare the independent Azure deployments, then add Oracle anchors and BaseDB after onboarding.
---

## Deployment model

The workshop uses Bicep, fixed configuration and exactly seven participants:
`mhuser1` through `mhuser7`. Each participant has an isolated VM spoke.

| Subscription | Resources |
|--------------|-----------|
| Workshop `aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483` | Hub, firewall, Bastion, DNS resolver/zones, image gallery, seven VM spokes |
| ODAA `4ce5b5cc-e869-451f-98fc-f50448849ee0` | Oracle VNet/delegated subnet, central Resource Anchor and Network Anchor, BaseDB resource groups |

Both subscriptions are in tenant `8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5`.
Use the [independent deployment guide](deployments/README.md) for exact entry
points, dependencies, static parameter files and commands.

There is no Terraform state in the active Azure deployment path. Entra user
creation uses a stateless directory operation: the Microsoft Graph Bicep users
resource supports reading existing users, not creating them.

## Hosted GitHub pipelines

The [OIDC bootstrap](deployments/README.md#github-oidc-bootstrap) creates one
managed identity in the workshop subscription, not a runner. All active workflows
use GitHub-hosted runners. The image build uses a temporary public-SSH build VM;
private workshop tests execute through Managed Run Command on an existing
participant VM. No Terraform state or runner network is used.

The internal-runner deployment and Terraform roots have been removed from the
repository. Their deletion does not tear down old cloud resources or delete
local state. The new CI identity is separate from those historical resources.

## Start without Oracle onboarding

1. Create the seven identities using the [provisioning script](identity/provision.ps1).
2. Deploy the hub: firewall DNS proxy, central Bastion, Private DNS Resolver and
   central private DNS zone. It does not depend on any Oracle resource.
3. Create the image gallery and build the reviewed
   [Oracle client image](packer/README.md).
4. Deploy the seven spoke networks and own-spoke permissions. This can complete
   without a published image or available VM capacity. It grants the workshop
   group Reader access to the hub and gallery.
5. Deploy the seven VMs only after image version `1.1.0` is published, peerings
   are connected and `Standard_D2as_v7` is available in zone 2 with sufficient quota.

The hub can also be deployed before identity creation: its participant Reader
assignment is applied with the spoke deployment. Participants cannot change
hub, central DNS or other users' spokes.

VM custom DNS points to the actual private firewall IP. The firewall forwards
to resolver inbound IP `10.100.0.132`; the private zone
`basedb.workshop.internal` is linked only to the hub. Internet traffic follows
the firewall, not per-user NAT gateways.

## Continue after Oracle onboarding

1. Verify OracleSubscription `default` is `Succeeded` and its cloud account is
   `Available`; `Accepted` or `Pending` is not ready.
2. Deploy the Oracle VNet, delegated subnet and Resource Anchor
   `anchor-odaa-shared`.
3. Connect the hub and Oracle VNet with peering and symmetric firewall routes.
4. Deploy central zonal Network Anchor `nw-anchor-workshop`, with native
   Oracle-to-Azure DNS zone replication enabled and DNS endpoints disabled.
5. Provision one approved BaseDB in `rg-odaa-shared`. Discover the Azure private
   DNS zone Oracle creates during provisioning, then deploy stage 07 in that
   group to link the existing zone to the hub VNet.
6. Provision the remaining participant BaseDB systems alongside the shared
   Resource Anchor, using distinct DB system names. Verify actual replicated
   records and client DNS over UDP/TCP. Oracle-to-Azure DNS is separately pending.

All Oracle resources use subscription `4ce5b5cc-e869-451f-98fc-f50448849ee0`.
The seven workshop users share BaseDB management permissions in this group,
including permissions to change or delete each other's databases. Shared
networking and anchors remain read-only to participants.

The agreed database target remains France Central, one single-node DB system
per participant, Enterprise Edition, License Included, and Oracle 26ai where
regionally available. Verify the exact shape, version, compute count, storage,
zone mapping, quota and prices before provisioning. The 256 GB data-storage
candidate does not include additional software/recovery volumes.

> [!IMPORTANT]
> Compilation and offline tests are not live Oracle certification. The
> Oracle-dependent deployments remain blocked until onboarding is complete.

## VM image and capacity

The refreshed image pins Ubuntu 24.04 Gen2 and verified Oracle tool versions.
See the [image guide](packer/README.md) for release sources, checksums and
runtime validation results.

The initial D2s_v5 build failed because that SKU was regionally restricted.
The approved replacement uses `Standard_D4as_v7` for the temporary image build
and `Standard_D2as_v7` in zone 2 for participants. No GPU is required.
These VMs use NVMe, not SCSI. The gallery metadata, Linux boot configuration
and post-reboot checks are part of the image build; Oracle client versions
and their network configuration do not change because of the disk controller.

## Organizer onboarding

The [OracleSubscription template](deployments/oracle-subscription.bicep) is an
optional entry point for one-time organizer onboarding. It does not transfer
subscriptions, activate OCI or deploy the hub.

> [!WARNING]
> Creating an OracleSubscription can initiate a paid Marketplace transaction.
> This is an organizer operation, not a participant challenge.

Review the deployment from a local terminal:

```bash
az deployment sub what-if \
  --subscription 4ce5b5cc-e869-451f-98fc-f50448849ee0 \
  --location francecentral \
  --template-file infra/deployments/oracle-subscription.bicep
```

For explicitly approved onboarding, start the deployment:

```bash
az deployment sub create \
  --subscription 4ce5b5cc-e869-451f-98fc-f50448849ee0 \
  --location francecentral \
  --name oracle-subscription \
  --template-file infra/deployments/oracle-subscription.bicep
```

## Tests, credentials and cleanup

The [test guide](../tests/README.md) describes guarded Phase B validation.
Tests consume successful ARM deployment outputs, not old Terraform state.
They use the seven existing participant VMs and distinct test DB names
`basetest01` through `basetest07` in the shared Oracle resource group.
No test workflow automatically runs after an infrastructure push.

Passwords, OCI private keys and private SSH keys must not enter source control,
deployment outputs, command logs or public artifacts. Initial participant
credentials must be stored only in an organizer-authorized, protected location.

BaseDB cleanup deletes only explicitly owned database resources. It preserves
shared anchors, central DNS, hub, participant spokes and identities.
Infrastructure teardown is a separate, explicitly reviewed operation.

All paid hub services live in the workshop subscription. Azure peering and
network traffic can still produce charges on the Oracle side, so the placement
does not guarantee an Oracle-only invoice.

## Repository entry points

| Path | Purpose |
|------|---------|
| [deployments/](deployments/README.md) | Static Bicep stages and shared modules |
| [identity/](identity/) | Entra provisioning script and [password/MFA reset guide](identity/README.md) |
| [packer/](packer/README.md) | Canonical Oracle client toolchain and NVMe image build |
| [ansible/playbooks/oracle-tools.yml](ansible/playbooks/oracle-tools.yml) | Remote entry point that reuses the image toolchain |
| [deployments/oracle-subscription.bicep](deployments/oracle-subscription.bicep) | Organizer Marketplace and OracleSubscription onboarding |
| [scripts/setup-github-federation.ps1](scripts/setup-github-federation.ps1) | New-tenant GitHub OIDC bootstrap |
| [scripts/cleanup-base-database.ps1](scripts/cleanup-base-database.ps1) | Owned BaseDB cleanup, not infrastructure teardown |

The optional Ansible entry point has no public-IP inventory or SSH configuration.
Pass an explicitly reviewed inventory and connection settings when using it.
Normal deployment and acceptance tests use the published image and Managed Run
Command on private VMs instead.

Historical Terraform, runner and ADB/AKS sources remain available in Git history,
not as alternative deployment instructions in the current tree. Ignored local
state, credential files and provider caches are preserved in private recovery
archives rather than used as active deployment inputs.

## Local files and retired Terraform

The current deployment needs no Terraform executable, `.tf` configuration,
Terraform backend or remote state. Packer remains required for image builds;
its `.pkr.hcl` template and example `.pkrvars.hcl` are **not Terraform configuration**.
The [repository map](../README.md#repository-map) distinguishes required shared
runtime helpers, validation suites and optional organizer entry points.

During local cleanup, retired `infra/shared`, `infra/users`, `infra/test-runner`
and `infra/github-runner` directories, plus the old Terraform cache/lock under
`infra/identity`, were moved to a private archive outside the checkout:
`~/.workshop-legacy-backups/msftmh-<UTC timestamp>/`.
The archive preserves the original state, variable files and provider caches.
It is a local recovery copy, not a deployment input. Do not copy its contents
back into source control or use an old state to operate the new tenant.
Archiving local files does not delete or change cloud resources.

One root `.gitignore` now protects the entire tree. Legacy Terraform exclusions
remain intentionally, but the nested exception that allowed
`infra/users/terraform.tfvars` as a workflow trigger is gone.

Keep local authentication separate from project source:

| Local files | Treatment |
|-------------|-----------|
| `infra/.oci/` or another private OCI CLI profile location | Organizer OCI authentication; retained, ignored and never displayed |
| `.workshop-secrets/` in the workspace root | Private identity exports, participant passwords, keys and endpoint metadata; Git-ignored, never commit |
| `.venv/` | Optional local Python environment, not source |
| `infra/packer/variables.auto.pkrvars.hcl` | Optional local Packer values; retain privately, never commit |
| `packer-manifest.json`, `__pycache__/` | Regenerable output/cache, not source |
| Retired Terraform archive | Recovery only; not used by current workflows or walkthroughs |

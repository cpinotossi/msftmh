---
title: Independent seven-user workshop deployments
description: Deploy the Azure workshop before Oracle onboarding, then add Oracle networking and DNS.
---

## Fixed environment

| Setting | Value |
|---------|-------|
| Tenant | `8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5` |
| Workshop subscription | `aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483` |
| Oracle subscription | `4ce5b5cc-e869-451f-98fc-f50448849ee0` |
| Region | France Central |
| Participants | Exactly `mhuser1` through `mhuser7` |
| Hub | `10.100.0.0/16` |
| VM spokes | `10.0.1.0/24` through `10.0.7.0/24` |
| Oracle delegated subnet | `192.168.0.0/24` |
| Resolver inbound endpoint | `10.100.0.132` |
| Central private DNS zone | `basedb.workshop.internal` |

Azure infrastructure uses Bicep and ARM deployment history, not Terraform state.
Each deployment has a small parameter file. There is no configurable participant
count or runtime inventory discovery. Bicep loops expand only the seven literal
participants.

New Entra object IDs and the firewall/Oracle DNS endpoint addresses must be
copied from their successful creation outputs. Empty placeholders are not valid
deployment inputs. Keep passwords and private SSH keys out of parameter files.

## GitHub OIDC bootstrap

All active workflows use GitHub-hosted `ubuntu-latest` runners and OIDC.
No Container Apps runner, runner PAT, Terraform backend, state storage or private
endpoint is required. Private SQL and DNS probes run on the selected workshop VM
through Azure Managed Run Command; the hosted runner uses public Azure/OCI
control-plane APIs and never needs direct access to the VM or database.

Create the CI identity once using an authorized administrator in the new tenant:

```bash
pwsh -NoProfile -File ../scripts/setup-github-federation.ps1 -WhatIf
pwsh -NoProfile -Command '& ../scripts/setup-github-federation.ps1 -Confirm:$false'
```

[00-github-identity.bicep](00-github-identity.bicep) creates only
`rg-workshop-ci/id-workshop-github` and IAM configuration. It grants Contributor
and User Access Administrator on the two fixed subscriptions because the
deployment stages create custom roles and participant role assignments.
The administrator-only script also grants Microsoft Graph `User.Read.All` and
`Group.Read.All` for read-only roster verification. It does not grant directory
write permissions, create users or store a client secret.

Set repository Actions variable `AZURE_CLIENT_ID` to the printed client ID.
The tenant and subscription IDs remain static in the workflows.
`AZURE_AUTH_MODE`, `IMAGE_BUILD_RUNNER`, runner `ARM_CLIENT_ID` and `TF_STATE_*`
settings are no longer active inputs. Remove old environment-level
`AZURE_CLIENT_ID` overrides so the seven test jobs use the same new identity.

The initial trust accepts only
`repo:cpinotossi/msftmh:ref:refs/heads/main`, issued by
`https://token.actions.githubusercontent.com` for `api://AzureADTokenExchange`.
Tests use separate `mhuser1` through `mhuser7` GitHub environments for SQL/OCI
secrets. Before enabling their trusts, configure each environment with custom
deployment branch policies: exactly branch `main`, no wildcard or tag policy.
Keep any existing reviewer and wait-timer protections.

After these GitHub settings are verified, enable the seven environment subjects:

```bash
pwsh -NoProfile -Command '& ../scripts/setup-github-federation.ps1 -EnableParticipantEnvironments -Confirm:$false'
```

The script reads all seven environment policies through the authenticated `gh`
CLI before enabling them. An auth error or unexpected policy blocks this step.
Running the bootstrap without that switch revokes the seven managed environment
trusts and keeps `main` only; incremental Bicep alone does not revoke omitted
credentials.

Publish and review the workflow changes before dispatching them from `main`.
GitHub variables alone do not replace old workflow YAML. Keep
`WORKSHOP_PHASE_B_READY` disabled until Oracle onboarding and stages 04-07 are
complete. OCI API credentials and the actual DNS/PDB probe behavior still require
live Phase-B validation.

The test workflow creates a temporary private
[hub DNS diagnostic VM](hub-dns-diagnostic.bicep) for direct resolver and Oracle
endpoint queries; participant VMs retain firewall-only DNS.
Stage 02 reserves `snet-dns-diagnostic` (`10.100.1.0/28`) and its internet route
through the firewall. On an already deployed hub, apply
[hub-dns-diagnostic-network.bicep](hub-dns-diagnostic-network.bicep) to
`rg-workshop-hub` to add only this subnet, route and separate firewall rule group
without replacing existing VNet peerings or base rules.
VM, NIC, NSG and disk are deleted after each test using
run-specific ownership checks. See [diagnostic recovery](../../tests/README.md)
for interrupted runs and Azure-only smoke checks. The temporary VM has costs
while allocated; no permanent internal GitHub runner is created.

During migration, disable the old remote workflows before removing obsolete
`TF_*` repository variables. Keep the legacy shared deployment, workshop
deployment, user reset and Terraform import workflows disabled. The image,
test and cleanup paths are reused, so keep those workflows paused until their
hosted-OIDC replacements are reviewed and published. Then re-enable them:

```bash
gh workflow enable odaa-build-image.yml --repo cpinotossi/msftmh
gh workflow enable odaa-test-workshop.yml --repo cpinotossi/msftmh
gh workflow enable odaa-cleanup-workshop.yml --repo cpinotossi/msftmh
```

Verify hosted OIDC and the fixed roster with the read-only identity workflow
before starting an infrastructure deployment:

```bash
gh workflow run odaa-provision-identity.yml --repo cpinotossi/msftmh --ref main
```

Set `WORKSHOP_HUB_DEPLOYMENT_ID` to the full ARM ID of the successful
`workshop-02-hub` resource-group deployment. This output reference does not
require Terraform state. Keep participant SQL/OCI secrets in their respective
environments; do not reuse credentials from the old tenant without verification.
Removing unused GitHub variables does not delete old runner registrations,
Azure runner infrastructure, storage accounts or state files.

## Phase A: No Oracle dependency

| Step | Entry point | Scope | Dependency |
|------|-------------|-------|------------|
| 1 | Stateless identity creation under [identity/](../identity/README.md) | New Entra tenant | Authorized directory administrator |
| 2 | [02-hub.bicep](02-hub.bicep) | Workshop `rg-workshop-hub` | None |
| 2a | [02-image-gallery.bicep](02-image-gallery.bicep) | Workshop `rg-workshop-images` | None |
| 2b | [Packer image build](../packer/README.md) | Workshop temporary build RG and gallery | Gallery and an available build VM SKU |
| 3a | [03-users.bicep](03-users.bicep) | Workshop subscription | Workshop group ID, seven object IDs, hub and gallery |
| 3b | [03-user-vms.bicep](03-user-vms.bicep) | Workshop subscription | Seven connected spokes, published image and VM capacity |

Step 3a creates seven resource groups, VNets, NSGs, routes, bidirectional
hub peerings, participant Contributor assignments and group Reader access to the
hub and image gallery. It creates no VMs and
can complete even when the image build or VM capacity is blocked.

Step 3b creates exactly seven private `Standard_D2as_v7` VMs in zone 2 from image version
`1.1.0`, Entra SSH login extensions, VM User Login assignments and central
`vm-mhuserN` DNS records. No VM gets a public IP, individual Bastion or NAT
gateway. Verify the image version exists and all seven hub peerings are
`Connected` before starting it.

The VMs explicitly use an NVMe storage controller. The gallery definition
advertises `DiskControllerTypes=SCSI,NVMe`, and the image build prepares and
reboot-tests the Ubuntu NVMe drivers. The read-only prerequisite checker
distinguishes regional restrictions from restrictions on individual zones.

The hub provides a shared Standard Bastion, Standard Firewall with DNS Proxy,
and Private DNS Resolver with separate inbound/outbound subnets. The spoke
deployment applies Reader access so every participant can inspect the hub
without changing it. Participants can modify only their own spoke resource group.

DNS initially follows:

```text
VM -> firewall private IP -> resolver inbound 10.100.0.132
   -> central Azure private zone or public DNS
```

The firewall blocks traffic between participant/test client CIDRs and permits
HTTP/HTTPS internet egress for package installation and Azure login. NSGs
also deny inter-client traffic and DNS to destinations other than the firewall,
including Azure platform DNS. DNS-over-HTTPS is not filtered by this lab policy.

> [!WARNING]
> Firewall, Bastion, VMs, image storage and temporary build resources incur
> charges. A successful Bicep compilation does not establish capacity or
> successful provisioning. Do not substitute a GPU or change region without
> an explicit decision. Delete temporary build resources after the build.

Sign in using the new tenant and select the workshop subscription:

```bash
az login --tenant 8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5
az account set --subscription aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483
```

Register the workshop providers before deployment:

```bash
az provider register --namespace Microsoft.Network --wait
az provider register --namespace Microsoft.Compute --wait
az provider register --namespace Microsoft.Storage --wait
```

This subscription also required feature `AllowBringYourOwnPublicIpAddress`
for the hub public IPs. Its registration succeeded without changing an
organization policy. If Azure reports `SubscriptionNotRegisteredForFeature`,
register the named feature and propagate it through provider registration:

```bash
az feature register --namespace Microsoft.Network --name AllowBringYourOwnPublicIpAddress
az feature show --namespace Microsoft.Network --name AllowBringYourOwnPublicIpAddress \
  --query properties.state -o tsv
az provider register --namespace Microsoft.Network --wait
```

Continue only after the feature reports `Registered`.

After filling [02-hub.bicepparam](02-hub.bicepparam), preview and deploy:

```bash
az group create --name rg-workshop-hub --location francecentral
az deployment group what-if --resource-group rg-workshop-hub \
  --name workshop-02-hub --parameters ./02-hub.bicepparam
az deployment group create --resource-group rg-workshop-hub \
  --name workshop-02-hub --parameters ./02-hub.bicepparam
```

Run these commands from this directory. For subscription-scoped stages, use
`az deployment sub what-if` and `az deployment sub create`, with
`--location francecentral`, the correct subscription and stage parameter file.
Do not use `az deployment subscription`.

## Phase B: Wait for successful Oracle onboarding

| Step | Entry point | Deployment subscription / scope |
|------|-------------|---------------------------------|
| 4 | [04-oracle-network.bicep](04-oracle-network.bicep) | Oracle subscription |
| 5 | [05-oracle-connectivity.bicep](05-oracle-connectivity.bicep) | Workshop subscription; modules configure both subscriptions |
| 6 | [06-network-anchor.bicep](06-network-anchor.bicep) | Oracle `rg-odaa-shared` |
| 7 | [07-oracle-dns.bicep](07-oracle-dns.bicep) | Workshop `rg-workshop-hub` |
| 8 | [BaseDB lab](../../walkthrough/create-odaa-basedb/create-odaa-basedb.md) | Assigned `rg-odaa-mhuserN` |

Before Phase B, verify OracleSubscription `default` has provisioning state
`Succeeded` and cloud account state `Available`. Do not treat `Accepted`,
`Pending`, a failed details query or a successful what-if as completed onboarding.

Step 4 creates the shared Oracle VNet, delegated subnet and Resource Anchor
`anchor-odaa-shared`, seven isolated database resource groups, and `rg-odaa-test`.
Participants get Oracle Reader access plus a narrow BaseDB creator role only
in their own database group. Shared anchors and network resources are not
participant-writable.

Step 4 also prepares the static return route table on the Oracle subnet.
Step 5 adds hub-to-Oracle peering and Oracle firewall rules.
Client routes target the exact delegated prefix `192.168.0.0/24`, not the
broader Oracle VNet prefix. Peering alone is not transitive.

Step 6 creates one centrally owned `nw-anchor-workshop`. Verify the approved
region/zone mapping before deploying it. All BaseDB systems must match that
anchor's zone and region. Its listening endpoint accepts requests from the
resolver outbound subnet `10.100.0.192/26`. Its forwarding rule sends
`basedb.workshop.internal` queries to `10.100.0.132`.

For step 7, copy the actual listening IP and OCI subnet DNS domain, including
the trailing dot, into [07-oracle-dns.bicepparam](07-oracle-dns.bicepparam).
Do not guess these values from a VCN label.

```text
Azure -> Oracle:
VM -> firewall DNS proxy -> resolver inbound -> outbound ruleset
   -> Network Anchor listening endpoint -> Oracle private DNS

Oracle -> Azure:
Oracle DNS -> Network Anchor forwarding endpoint -> resolver inbound
           -> central Azure private DNS zone
```

Only the actual Oracle domain is forwarded to Oracle. Do not forward the Azure
private zone or a wildcard domain back to Oracle: that creates a DNS loop.
Verify UDP and TCP 53 in both directions, DNS endpoint OCI NSG rules, Oracle
listener security, effective routes and SQL connectivity before the workshop.
OCI policies must also isolate participant database operations.

## Billing boundaries and cleanup

Hub, DNS, Bastion, gallery and client resources are in the workshop subscription.
The Oracle subscription contains required Oracle networking, anchors and
database resources, not paid hub DNS or firewall infrastructure. Azure networking
and peering traffic can still incur Oracle-side charges; zero non-Oracle charges
cannot be guaranteed.

Use incremental deployments and inspect what-if before reapplying any stage.
Base spoke route tables already include the future exact Oracle prefix without
depending on any Oracle resource. The Oracle base subnet includes its return
route table, so later peering/DNS deployments do not own or replace that subnet.

BaseDB cleanup deletes only explicitly owned database resources. It does not
remove central DNS, anchors, hub, spokes or identities. Review and explicitly
approve infrastructure teardown separately.

The older Terraform roots under `shared/`, `users/` and `test-runner/` are
retained for historical state/reference only. They are not the deployment path
for this environment; the old monolithic apply workflows are retired.

## Local checks

```bash
../../.venv/bin/python -m unittest discover -s tests -v
az bicep build --file ./02-hub.bicep --stdout
az bicep build --file ./03-users.bicep --stdout
az bicep build --file ./03-user-vms.bicep --stdout
```

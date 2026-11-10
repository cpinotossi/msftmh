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

New Entra object IDs, the firewall address and the actual replicated DNS zone must be
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
There are no runner/authentication mode overrides or Terraform backend inputs.
Remove old environment-level
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
[hub DNS diagnostic VM](hub-dns-diagnostic.bicep) for resolver and firewall
queries; participant VMs retain firewall-only DNS.
Stage 02 reserves `snet-dns-diagnostic` (`10.100.1.0/28`) and its internet route
through the firewall. On an already deployed hub, apply
[hub-dns-diagnostic-network.bicep](hub-dns-diagnostic-network.bicep) to
`rg-workshop-hub` to add only this subnet, route and separate firewall rule group
without replacing existing VNet peerings or base rules.
VM, NIC, NSG and disk are deleted after each test using
run-specific ownership checks. See [diagnostic recovery](../../tests/README.md)
for interrupted runs and Azure-only smoke checks. The temporary VM has costs
while allocated; no permanent internal GitHub runner is created.

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
| 1 | Stateless identity creation with [provision.ps1](../identity/provision.ps1) | New Entra tenant | Authorized directory administrator |
| 2 | [02-hub.bicep](02-hub.bicep) | Workshop `rg-workshop-hub` | None |
| 2a | [02-image-gallery.bicep](02-image-gallery.bicep) | Workshop `rg-workshop-images` | None |
| 2b | [Packer image build](../packer/README.md) | Workshop temporary build RG and gallery | Gallery and an available build VM SKU |
| 3a | [03-users.bicep](03-users.bicep) | Workshop subscription | Workshop group ID, seven object IDs, hub and gallery |
| 3b | [03-user-vms.bicep](03-user-vms.bicep) | Workshop subscription | Seven connected spokes, published image and VM capacity |

Step 3a creates seven resource groups, VNets, NSGs, routes, bidirectional
hub peerings, participant Contributor assignments, organizer VM Administrator
Login assignments and group Reader access to the hub and image gallery. It creates no VMs and
can complete even when the image build or VM capacity is blocked.

`organizerObjectId` in [03-users.bicepparam](03-users.bicepparam) identifies
`admin@cptdemo.org`. Stage 3a grants that user Virtual Machine Administrator Login
on each of the seven `rg-vm-mhuserN` groups, enabling Entra SSH and sudo on their
VMs through the shared Bastion. Participant VM User Login remains scoped to the
participant's own VM. No organizer group membership or new subscription-wide
role is added.

The organizer already has inherited Owner access to both subscriptions,
including Bastion, NICs, networks and the shared Oracle resource group.
Owner covers Azure resource management, but does not include the VM login
data actions. The explicit VM Administrator Login grants provide that missing
access; they do not grant Oracle SQL users or OCI API permissions.

The seven grants were applied and verified in the live workshop. Organizer
Entra certificate login and passwordless sudo through Bastion passed on VM 1,
without an SSH-key fallback. VMs 2-7 were deallocated and were left off;
their end-to-end SSH checks and participant-account logins remain pending.

To apply only these role assignments on an existing lab, use
[spoke-access.bicep](modules/spoke-access.bicep) per participant resource group
with its matching `userObjectId` and the configured `organizerObjectId`.
Preview first and deploy in incremental mode. This avoids redeploying VMs or networks.

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
| 7 | [07-oracle-dns.bicep](07-oracle-dns.bicep) | Oracle `rg-odaa-shared`; links the workshop hub |
| 8 | [BaseDB lab](../../walkthrough/create-odaa-basedb/create-odaa-basedb.md) | Oracle `rg-odaa-shared` for all seven participants |

Before Phase B, verify OracleSubscription `default` has provisioning state
`Succeeded` and cloud account state `Available`. Do not treat `Accepted`,
`Pending`, a failed details query or a successful what-if as completed onboarding.

Step 4 creates `rg-odaa-shared`, the Oracle VNet, delegated subnet and Resource
Anchor `anchor-odaa-shared`. All seven users deploy their databases into this
same resource group in ODAA subscription `4ce5b5cc-e869-451f-98fc-f50448849ee0`.
This also satisfies the service's requirement that a DB system and its Resource
Anchor share a resource group. No per-participant Oracle resource groups or
separate test resource group are created.

The participant group gets Oracle Reader/catalog access and a narrow BaseDB
creator role on `rg-odaa-shared`. It can manage all BaseDB systems there,
including databases created by other participants. Shared anchors and network
resources are not participant-writable. Azure VM spokes remain individually
scoped. Existing obsolete participant groups are not automatically deleted.

Step 4 also prepares the static return route table on the Oracle subnet.
Step 5 adds hub-to-Oracle peering and Oracle firewall rules.
Client routes target the exact delegated prefix `192.168.0.0/24`, not the
broader Oracle VNet prefix. Peering alone is not transitive.

Step 6 creates one centrally owned `nw-anchor-workshop`. Verify the approved
region/zone mapping before deploying it. All BaseDB systems must match that
anchor's zone and region. Native Oracle-to-Azure DNS zone replication is enabled;
the listening and forwarding endpoints are disabled. The provider does not
permit changing these DNS flags on an existing anchor. Replacing an anchor with
dependent databases requires explicit approval for database recreation and data loss.

On the first deployment, create one approved BaseDB after step 6 and before
step 7. Oracle creates the replicated Azure private DNS zone and records during
database provisioning. Discover that actual zone in `rg-odaa-shared`; do not
create an empty substitute zone or guess its name from the requested VCN label.
Copy its name, without a trailing dot, into
[07-oracle-dns.bicepparam](07-oracle-dns.bicepparam), then deploy step 7 in the
ODAA subscription. It adds only a non-registering hub VNet link to the existing
zone and preserves the service-created Oracle VNet link and records.
Subsequent automation reads all four canonical deployments, including step 7,
before creating its test database.

```text
Database creation: Oracle private DNS -> replicated Azure private DNS zone
Client lookup: VM -> firewall DNS proxy -> resolver inbound
                 -> hub-linked replicated Azure private DNS zone
```

When migrating from conditional forwarding, retire only the obsolete
`oracle-vcn` forwarding rule after verifying the replicated zone and hub link.
Do not delete the shared resolver or unrelated rules.
Verify the actual A record against the OCI node IP and test UDP/TCP DNS through
the resolver and firewall. Oracle-to-Azure name resolution is separately pending,
not part of replicated-DNS acceptance. Verify Oracle listener security,
effective routes and real PDB SQL connectivity before enabling Phase B.
OCI policies must match the approved shared-lab access model.

Oracle-side database NSG rules are not exposed by the Bicep
`Oracle.Database/dbSystems` resource. During the workshop, participants add
their own SQL ingress rule in
[Challenge 3](../../walkthrough/configure-odaa-basedb-nsg/configure-odaa-basedb-nsg.md).
The `mh-workshop-participants-nsg-rules` policy grants only
`NETWORK_SECURITY_GROUP_UPDATE_SECURITY_RULES`, limited to the workshop
compartment and NSGs tagged
`OracleWorkshopAccess.ParticipantNsgRules=enabled`. Only the approved shared
workshop NSG carries this tag. Participants cannot change NSG tags, but their
rule permission is not isolated to their own rule within the shared group.
Oracle default rules must remain unchanged.

For separate organizer/CI validation after the exercise, the versioned
[SQL ingress configuration](../../tests/workshop_config.json) and
[OCI reconciliation command](../../tests/README.md#reproducible-oracle-sql-ingress)
add stateful TCP 1521 access from exactly the seven client networks to the actual
DB node NSG. The command verifies live scope and preserves provider rules.
The test workflow includes this step; no OCI secrets are embedded in Bicep.
Do not run the reconciliation or test workflow before participants finish
their rule-creation exercise: it would add all seven client rules in advance.

The [participant Markdown guides](../../README.md#challenges) reuse these shared
resources. Assigned DB names are `basedb1` through `basedb7`; CI keeps
`basetest01` through `basetest07`. Participants create databases in the portal
and copy private DNS/TCP/SQL checks into a Bastion SSH terminal. Organizer-owned
discovery and OCI NSG commands use local OCI credentials. Cleanup remains a
separate, owner-filtered organizer operation.

## Billing boundaries and cleanup

Hub, central client DNS, Bastion, gallery and client resources are in the workshop
subscription. Required Oracle networking, anchors, databases and the replicated
Azure private DNS zone are in the ODAA subscription. The hub resolver and firewall
remain in the workshop subscription. Private DNS, Azure networking and peering
can incur ODAA-subscription charges; zero non-Oracle charges cannot be guaranteed.

Use incremental deployments and inspect what-if before reapplying any stage.
Base spoke route tables already include the future exact Oracle prefix without
depending on any Oracle resource. The Oracle base subnet includes its return
route table, so later peering/DNS deployments do not own or replace that subnet.

BaseDB cleanup deletes only explicitly owned database resources. It does not
remove central DNS, anchors, hub, spokes or identities. Review and explicitly
approve infrastructure teardown separately.

Historical Terraform and internal-runner sources are available only in Git
history. Removing their files from this repository does not delete cloud
resources, ignored local state or credentials.

## Local checks

```bash
../../.venv/bin/python -m unittest discover -s tests -v
az bicep build --file ./02-hub.bicep --stdout
az bicep build --file ./03-users.bicep --stdout
az bicep build --file ./03-user-vms.bicep --stdout
```

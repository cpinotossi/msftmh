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

The legacy [github-runner/](github-runner/) configuration is historical only.
Do not apply it to the new tenant or delete its old resources/state as part of
this migration. Updating authentication is separate from publishing workflow
changes and approving Oracle-dependent tests.

## Start without Oracle onboarding

1. Create the seven identities using the [identity guide](identity/README.md).
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
4. Deploy central zonal Network Anchor `nw-anchor-workshop`, with both Oracle
   DNS endpoints enabled.
5. Configure forwarding of the actual OCI subnet DNS domain to the anchor's
   actual listening IP. Oracle forwards the Azure private zone to the hub
   resolver. Do not add mutual wildcard forwarding.
6. Provision BaseDB only in the assigned `rg-odaa-mhuserN`.

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

## Onboarding notebook

The [Bash onboarding notebook](notebooks/odaa-tenant-onboarding.ipynb) checks
prerequisites, lists Marketplace plans, previews the OracleSubscription and
performs a separately approved deployment with the adjacent
[Bicep template](notebooks/oracle-subscription.bicep).

Select the repository Bash Jupyter kernel and sign in through a separate
terminal. The creation cell can initiate a Marketplace transaction. The
notebook does not transfer subscriptions, activate OCI, or deploy the hub.

## Tests, credentials and cleanup

The [test guide](../tests/README.md) describes guarded Phase B validation.
Tests consume successful ARM deployment outputs, not old Terraform state.
They use the seven existing participant VMs and isolated database resource
groups. No test workflow automatically runs after an infrastructure push.

Passwords, OCI private keys and private SSH keys must not enter source control,
deployment outputs, command logs or public artifacts. Initial participant
credentials must be stored only in an organizer-authorized, protected location.

BaseDB cleanup deletes only explicitly owned database resources. It preserves
shared anchors, central DNS, hub, participant spokes and identities.
Infrastructure teardown is a separate, explicitly reviewed operation.

All paid hub services live in the workshop subscription. Azure peering and
network traffic can still produce charges on the Oracle side, so the placement
does not guarantee an Oracle-only invoice.

The historical Terraform roots under [shared/](shared/), [users/](users/) and
[test-runner/](test-runner/) are retained only for old-state/reference work.
Their old monolithic deployment workflows are retired. Do not apply those
roots to the new environment.

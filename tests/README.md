---
title: Base Database@Azure automation
description: Configure, validate, and safely clean up Oracle Base Database@Azure workshop automation.
---

## Base Database@Azure automation

The workshop has exactly seven participants, `mhuser1` through `mhuser7`, with
index keys `01` through `07`. The static roster in `workshop_config.json` maps each
participant to `rg-vm-mhuserN/vm-mhuserN` and `rg-odaa-mhuserN`. There is no
configurable participant count.

Phase A deploys identity, image, hub and seven isolated VM spokes without Oracle
access or dependencies. Phase B adds the shared Oracle network, connectivity,
central network anchor and DNS through independent Bicep stages under
`infra/deployments/`. Legacy shared/test-runner Terraform drafts and their remote
state are not canonical deployment inputs.

> [!IMPORTANT]
> Both test and cleanup workflows are manual and blocked until an organizer sets
> `WORKSHOP_PHASE_B_READY=true`. Do not enable this guard until Phase B is approved
> and the required deployments have succeeded. Local mocks do not access Azure
> or OCI.

The test creates a Single Node Enterprise Edition, LicenseIncluded DB system
in the selected participant's existing Oracle resource group. It uses the
existing central network anchor and never creates or deletes shared anchors,
DNS zones, links or records. It also creates a private temporary hub diagnostic
VM in a run-owned workshop resource group, not a GitHub runner. It does not deploy a legacy Terraform test runner,
adopt existing same-name databases, or modify legacy Autonomous Database resources.

## Static network architecture

Tenant `8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5` contains the workshop subscription
`aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483` and Oracle subscription
`4ce5b5cc-e869-451f-98fc-f50448849ee0`. Compatibility aliases `mhcore` and `mh0`
both refer to the workshop subscription.

The workshop hub contains the firewall, Private DNS Resolver, central Bastion and
organizer-managed `basedb.workshop.internal` zone in `rg-workshop-hub`. Every spoke
peers only with the hub, uses the firewall as custom DNS, and routes both the
default prefix and exact Oracle delegated subnet `192.168.0.0/24` through the
firewall. Direct spoke-to-Oracle peering and a broader `192.168.0.0/16` Oracle UDR
are not accepted.

Oracle networking remains in
`rg-odaa-shared/vnet-odaa-shared/snet-odaa-delegated`, with resource anchor
`anchor-odaa-shared` and one zonal network anchor `nw-anchor-workshop`.
Participants can create their isolated BaseDB systems, but cannot change this
shared infrastructure.

Forward DNS follows VM -> firewall proxy -> hub resolver -> Oracle listening
endpoint. Reverse DNS follows Oracle forwarding -> hub resolver inbound. The
runtime Oracle endpoint IPs come from the actual network anchor ARM response.
ARM exposes `ociVcnDnsLabel` and `ociSubnetId`, not the full subnet domain:
discovery uses that returned subnet ID to read its authoritative OCI domain and
the actual DB VNIC hostname. It never constructs an Oracle domain suffix or
uses a fabricated IP. Missing values fail the test.

## Required configuration

Dispatch with confirmation `RUN_PHASE_B_BASEDB_TEST`, a participant index, an
exact shape, exact database version, availability zone, compute model, compute
count, and data storage of at least 256 GB.
`VM.Standard.x86` is the documented candidate accepted by the pinned ARM API.
Prefer a regional 26ai version; no unverified version literal or fallback is
provided. The regional `dbSystemShapes` and `dbSystemDbVersions` preflight runs
before deployment, verifies single-node support and PDB support, and rejects
missing/mismatched compute metadata. ECPU and OCPU are never interconverted;
ECPU guidance is 4-256, OCPU uses advertised core bounds. Regional availability,
capacity, storage increments and subscription entitlement still require a live
preflight/deployment.

Repository settings:

* `WORKSHOP_PHASE_B_READY` and repository variable `AZURE_CLIENT_ID`, configured
  by the [new-tenant OIDC bootstrap](../infra/deployments/README.md#github-oidc-bootstrap)
* Explicit ARM deployment ID variables `WORKSHOP_HUB_DEPLOYMENT_ID`,
  `WORKSHOP_ORACLE_NETWORK_DEPLOYMENT_ID`, `WORKSHOP_NETWORK_ANCHOR_DEPLOYMENT_ID`
  and `WORKSHOP_ORACLE_DNS_DEPLOYMENT_ID`
* Separate `mhuserN` GitHub environments with `BASE_DB_SYS_PASSWORD` and
  `BASE_DB_TEST_PASSWORD` secrets; never share participant passwords
* `BASE_DB_SYS_PASSWORD` with 9-30 characters and at least two of each uppercase,
  lowercase, digit and special `_`, `#`, `-`; no other special characters
* Distinct `BASE_DB_TEST_PASSWORD` for the PDB-local `WORKSHOP` account, with
  9-30 characters containing only letters, digits, `_`, `#`, `-`
* Environment variable `BASE_DB_SSH_PUBLIC_KEY` containing an RSA public key
* Variable `OCI_COMPARTMENT_ID`, secrets `OCI_CLI_USER`, `OCI_CLI_TENANCY`,
  `OCI_CLI_FINGERPRINT`, `OCI_CLI_KEY_CONTENT`; region is `eu-paris-1`.
  OCI CLI is read-only and discovers the DB node/VNIC, anchor subnet domain and
  actual PDB service because ARM does not expose BaseDB dbNodes or PDB children.

The deployment-output exporter reads full ARM deployment responses and checks
all four provisioning states before exporting a public-output allowlist. Missing
outputs, secure outputs, multiline values and API errors fail before any config
is written. No Terraform remote state is read.

```bash
python3 tests/export_shared_config.py --participant 01
python3 tests/export_shared_config.py \
  --deployment-id "$WORKSHOP_HUB_DEPLOYMENT_ID" \
  --deployment-id "$WORKSHOP_ORACLE_NETWORK_DEPLOYMENT_ID" \
  --deployment-id "$WORKSHOP_NETWORK_ANCHOR_DEPLOYMENT_ID" \
  --deployment-id "$WORKSHOP_ORACLE_DNS_DEPLOYMENT_ID"
```

Without `GITHUB_ENV`/`GITHUB_OUTPUT`, these commands print public config for
inspection; they do not alter the calling shell.

Infrastructure prerequisites:

* Successful canonical stages 02 Hub, 04 Oracle Network, 06 Network Anchor and
  07 Oracle DNS; stage 05 Oracle Connectivity must complete before stage 07.
* Existing selected VM, its isolated Oracle DB resource group, and a zonally
  compatible central network anchor with both DNS endpoints enabled.
* Firewall DNS proxy configured to use hub resolver inbound, with an enabled
  Oracle-domain forwarding rule targeting the actual anchor listening endpoint.
* UDP/TCP port 53 reachability and the discovered DB TCP listener, normally 1521,
  not the ADB TLS port 1522. Tests never mutate Oracle NSGs.
* VM identity Reader permissions for network/DB topology probes and organizer
  permissions for isolated DB creation/deletion and managed VM Run Command.
* OCI read access to nodes, homes, databases, PDBs, VNICs and the anchor subnet.
  OCI credentials are never copied to the participant VM.
* Image-provided BATS, `/opt/bats-support/load`, `/opt/bats-assert/load`, Azure CLI,
  `dig` and Python `oracledb`, available to root/managed Run Command.

The workflow orchestrator is GitHub-hosted, not an internal runner. It installs
the pinned OCI CLI for discovery and authenticates to Azure using OIDC. The VM
keeps its private NIC; all guest execution uses the management-plane Run Command
API. Enforce main-only branch policies on each participant GitHub environment
before enabling its OIDC trust.

Before provisioning, the workflow grants the selected VM identity Reader on
its own spoke and database groups, the hub and the shared Oracle group. The
deterministic role-assignment names make this repeatable; no access to another
participant's spoke or database group is granted.

Participant probes query the firewall only over UDP and TCP 53. The separate
[hub diagnostic](hub_dns_diagnostic.py) uses `snet-dns-diagnostic`
(`10.100.1.0/28`) for direct resolver/Oracle endpoint queries and compares the
central Azure zone's SOA through Oracle with the hub resolver's answer over both
transports. Oracle endpoint NSGs must allow this diagnostic source on UDP/TCP 53.
Participant NSGs remain unchanged.

The diagnostic uses the verified private D2as_v7/NVMe image `1.1.0` in zone 2.
It has no public IP, login ingress, SQL/OCI credentials or managed identity.
Internet egress is routed through the firewall and restricted to agent package
downloads. The VM, NIC, NSG and disk are temporary and incur charges while
allocated; the empty subnet and route table remain part of stage 02.

An `always()` step removes only the exact run-owned diagnostic resource group,
after verifying its subscription, full ID and ownership tags. Hard workflow
termination or an Azure API failure can still leave resources behind. Recover
with the cleanup workflow's optional `diagnostic_owner` (`run_id-run_attempt`)
or, using an authorized Azure login from the repository root:

```bash
export BASE_DB_OWNER=123456789-1
python3 tests/hub_dns_diagnostic.py cleanup
```

For an Azure-only smoke test before Oracle onboarding, use `create`, `smoke`,
then `cleanup` with the same owner. `HUB_DNS_OK` verifies only the central zone
through the firewall/resolver; it does not claim Oracle bidirectional DNS success.

### Secure SQL credentials

The workflow uses a **managed** `Microsoft.Compute/virtualMachines/runCommands`
resource (API `2024-11-01`), not action Run Command `invoke`. Passwords are sent
only in `protectedParameters` through a local mode0600 request file that is
removed afterward. They are never public parameters, inline script literals,
CLI arguments, artifacts or logs. On Linux, named protected parameters become
environment variables, as specified by the official managed Run Command guide.

The remote bootstrap connects as `SYSTEM` to the discovered PDB service, verifies
the intended container before DDL, creates the PDB-local `WORKSHOP` user and grants
only `CREATE SESSION`. It writes a root-owned mode0600 regular file at
`/etc/oracle-workshop/base-db-test.json`; password environment variables are then
unset before BATS. The file is removed by an EXIT/signal trap, and the managed
Run Command resource is deleted after execution. An existing credential file is
never overwritten. The driver must already be installed.

The test authenticates as `WORKSHOP` using the discovered PDB service, runs
`SELECT sys_context('USERENV', 'CON_NAME'), 1 FROM dual`, and checks the actual
container and returned value. Driver exceptions and secret contents are not
printed. Provisioning or TCP connectivity alone cannot pass.

## Cleanup safety

Only resources tagged `workshop=odaa` and `managed-by=workshop-base-db` are eligible.
Test cleanup additionally restricts `automation-owner` to its GitHub run/attempt.
Only DB systems in the seven `rg-odaa-mhuserN` resource groups are eligible.
No network anchors are enumerated or deleted,
even if an old anchor carries workshop ownership tags. Existing same-name test
databases are never overwritten or adopted.

DB deletion must be verified absent. API/list/delete failures stop cleanup; they
never become empty lists, false 404s or success summaries. The cleanup workflow
preserves all shared anchors, DNS, Azure/OCI networking, exactly seven VMs,
identity accounts and credentials. Infrastructure teardown and credential
rotation are separate organizer operations, not part of DB cleanup.

```powershell
./infra/scripts/cleanup-odaa-and-destroy.ps1 -SubscriptionId '<subscription>' -WhatIf
./infra/scripts/cleanup-odaa-and-destroy.ps1 -SubscriptionId '<subscription>' -Confirm:$false
```

## Local validation and template build

```bash
az bicep build --file tests/bicep/base-db-test.bicep
python3 -m unittest discover -s tests -p 'test_*.py' -v
bash -n tests/run-tests.sh
```

Keep `base-db-test.json` aligned with its Bicep source. The template deploys only
the DB system, using cross-resource-group central anchor IDs. Mocks cover metadata selection,
unit handling, cleanup ownership/order/API failures, PDB descriptor parsing,
SQL container validation, ARM deployment-output guards, the fixed seven-user
mapping, hub-only routing, firewall DNS, bidirectional UDP/TCP DNS, remote exit
handling and TAP count/shape checks.
Managed Run Command provisioning and execution states, integer `exitCode=0`,
the process marker **and** all 13 ordered non-skipped TAP results
including the SQL test must succeed. Truncated/missing output fails closed.
Live Azure/OCI provisioning and regional 26ai availability cannot be certified
without valid access; local validation does not claim cloud E2E success.

## Official contracts

* [Base Database creation, shapes and password/storage rules](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/azucr-create-base-database.html)
* [DB systems ARM 2025-09-01](https://learn.microsoft.com/azure/templates/oracle.database/2025-09-01/dbsystems)
* [Network anchors ARM 2025-09-01](https://learn.microsoft.com/azure/templates/oracle.database/2025-09-01/networkanchors)
* [Regional shape metadata](https://learn.microsoft.com/rest/api/oracle/db-system-shapes/list-by-location?view=rest-oracle-2025-09-01)
* [Public OpenAPI specification](https://github.com/Azure/azure-rest-api-specs/blob/main/specification/oracle/resource-manager/Oracle.Database/OracleDatabase/stable/2025-09-01/openapi.json)
* [OCI PDB connection strings model](https://github.com/oracle/oci-python-sdk/blob/master/src/oci/database/models/pluggable_database_connection_strings.py)
* [Managed Run Command protected parameters and exit status](https://learn.microsoft.com/azure/virtual-machines/linux/run-command-managed)
* [Managed Run Command ARM contract](https://learn.microsoft.com/azure/templates/microsoft.compute/2024-11-01/virtualmachines/runcommands)

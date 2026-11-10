---
title: Base Database@Azure automation
description: Configure, validate, and safely clean up Oracle Base Database@Azure workshop automation.
---

## Base Database@Azure automation

The workshop has exactly seven participants, `mhuser1` through `mhuser7`, with
index keys `01` through `07`. The static roster in `workshop_config.json` maps each
participant to `rg-vm-mhuserN/vm-mhuserN` and a distinct test DB name,
`basetest01` through `basetest07`. Every database uses `rg-odaa-shared` in the
fixed ODAA subscription. There is no configurable participant count.

Participant walkthroughs use the separate `workshopDatabaseName` mapping,
`basedb1` through `basedb7`, with owner `participant-mhuserN`. The shared name
guard and Bicep template permit those names without changing CI's reserved test
selection. Both use PDB `WORKSHOP`. See the
[participant guides](../README.md#challenges).
Participants copy commands into a Bastion SSH terminal, while the CI lifecycle
uses Managed Run Command. Participants use `dig`, `nc` and SQL*Plus in small
steps. SQL*Plus reuses `SYSTEM` with a hidden password prompt, verifies the PDB,
and executes SELECTs only in the Easy Connect challenge. The measurement
challenge uses image-provided `ociping` and `connping` with separate password
prompts. The optional ten-sample min/median/max probe remains separate in this automation.
CI's separate limited-user lifecycle is unchanged.
Shell walkthrough tests validate command syntax, SQL*Plus command contracts,
and shell execution with mocked command-line tools.
Cleanup is a separate, owner-filtered organizer operation.

Phase A deploys identity, image, hub and seven isolated VM spokes without Oracle
access or dependencies. Phase B adds the shared Oracle network, connectivity,
central network anchor and DNS through independent Bicep stages under
`infra/deployments/`. ARM deployment outputs, not Terraform state, are the
canonical deployment inputs.

> [!IMPORTANT]
> Both test and cleanup workflows are manual and blocked until an organizer sets
> `WORKSHOP_PHASE_B_READY=true`. Do not enable this guard until Phase B is approved
> and the required deployments have succeeded. Local mocks do not access Azure
> or OCI.

The test creates a Single Node Enterprise Edition, LicenseIncluded DB system
in the shared Oracle resource group under the selected participant's reserved
test name. It uses the
existing central network anchor and never creates or deletes shared anchors,
DNS zones, links or records. It also creates a private temporary hub diagnostic
VM in a run-owned workshop resource group, not a GitHub runner. It does not
adopt existing same-name databases, or modify legacy Autonomous Database resources.
After discovery, it adds only missing stateful TCP 1521 ingress rules to the
actual DB node's attached OCI NSG, using the seven client CIDRs in
[workshop_config.json](workshop_config.json). Provider-managed rules are preserved.

## Static network architecture

Tenant `8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5` contains the workshop subscription
`aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483` and Oracle subscription
`4ce5b5cc-e869-451f-98fc-f50448849ee0`. Probe configuration uses explicit
`TEST_WORKSHOP_SUBSCRIPTION_ID`, `TEST_ODAA_SUBSCRIPTION_ID`,
`TEST_VM_RESOURCE_GROUP` and `TEST_VM_VNET_NAME` values. No old subscription
aliases or Terraform environment-variable fallbacks are accepted.

The workshop hub contains the firewall, Private DNS Resolver, central Bastion and
organizer-managed `basedb.workshop.internal` zone in `rg-workshop-hub`. Every spoke
peers only with the hub, uses the firewall as custom DNS, and routes both the
default prefix and exact Oracle delegated subnet `192.168.0.0/24` through the
firewall. Direct spoke-to-Oracle peering and a broader `192.168.0.0/16` Oracle UDR
are not accepted.

Oracle networking remains in
`rg-odaa-shared/vnet-odaa-shared/snet-odaa-delegated`, with resource anchor
`anchor-odaa-shared` and one zonal network anchor `nw-anchor-workshop`.
Participants can create and manage all BaseDB systems in this group, but cannot
change the shared network or anchors. This is a shared lab, not a database
management isolation boundary between participants. Separate SQL credentials
do not remove their shared Azure database-management permissions.

Client DNS follows VM -> firewall proxy -> hub resolver -> hub-linked replicated
Azure private DNS zone. The Network Anchor enables native zone replication and
disables listening. Oracle creates the Azure zone and records during database
provisioning. Stage 07 links that existing zone to the hub; no manually populated
replacement zone is accepted. Oracle-to-Azure resolution is separately pending
and is not certified by these forward-path tests.
ARM exposes `ociVcnDnsLabel` and `ociSubnetId`, not the full subnet domain:
discovery uses that returned subnet ID to read its authoritative OCI domain and
the actual DB VNIC hostname. It never constructs an Oracle domain suffix or
uses a fabricated IP. Missing values fail the test.

CDB discovery uses the OCI CLI composite `db database list --db-system-id`
command. Unlike the node and PDB listings, it does not accept `--db-home-id`
or `--all`.

## Required configuration

Dispatch with confirmation `RUN_PHASE_B_BASEDB_TEST`, a participant index, an
exact shape, exact database version, availability zone, compute model, compute
count, and data storage of at least 256 GB.
The minimum-cost starting configuration within the approved Enterprise Edition,
LicenseIncluded target is the workflow default: `VM.BaseDB.x86`, version
`26.0.0.0.0`, ECPU count 4 and 256 GB of data storage, with one node.
Start with one participant's test before creating the remaining databases.
Availability zone remains an explicit input matching the central Network Anchor.
The verified France Central catalog advertises `VM.BaseDB.x86`, shape family
`VIRTUALMACHINE`, ECPU minimum 4, maximum 256 and increment 4 in zone 1
(checked 2026-11-09). The LVM version catalog lists `26.0.0.0.0` as non-preview
with PDB support. The older
`VM.Standard.x86` documentation/CLI enum is not the regional shape.
These editable defaults are not a capacity guarantee or a runtime fallback.
The regional `dbSystemShapes` and `dbSystemDbVersions` preflight runs
before deployment, verifies single-node support and PDB support, and rejects
missing/mismatched compute metadata. ECPU and OCPU are never interconverted;
Compute limits and increments use the explicitly verified metadata compute
model without conversion. Regional availability,
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
* Existing selected VM, the shared Oracle DB resource group, and a zonally
  compatible central network anchor with native zone replication enabled and
  listening disabled.
* A provider-created Azure private DNS zone in `rg-odaa-shared`, exported as
  `BASE_DB_ORACLE_DNS_ZONE_ID`, with a completed, non-registering hub VNet link.
  Bootstrap step 6, one approved database, then step 7 before the first workflow.
* Firewall DNS proxy configured to use hub resolver inbound. No Oracle-domain
  conditional forwarding rule is required.
* UDP/TCP port 53 reachability and the discovered DB TCP listener, normally 1521,
  not the ADB TLS port 1522. The organizer's OCI identity needs NSG read and
  security-rule add permissions in the linked compartment. Participant VM
  identities do not receive OCI write credentials.
* VM identity Reader permissions for network/DB topology probes and organizer
  permissions for DB creation/deletion and managed VM Run Command.
* OCI read access to nodes, homes, databases, PDBs, VNICs and the anchor subnet.
  OCI credentials are never copied to the participant VM.
* Image-provided BATS, `/opt/bats-support/load`, `/opt/bats-assert/load`, Azure CLI,
  `dig`, Python `oracledb` and Oracle Instant Client, available to root/managed
  Run Command. The image's loader configuration must expose the native client.

The workflow orchestrator is GitHub-hosted, not an internal runner. It installs
the pinned OCI CLI for discovery and authenticates to Azure using OIDC. The VM
keeps its private NIC; all guest execution uses the management-plane Run Command
API. Enforce main-only branch policies on each participant GitHub environment
before enabling its OIDC trust.

Before provisioning, the workflow grants the selected VM identity Reader on
its own spoke, the hub and the shared Oracle group. The deterministic
role-assignment names make this repeatable; no access to another participant's
Azure spoke is granted. All Oracle databases are visible in the shared group.

Participant probes query the firewall only over UDP and TCP 53. The separate
[hub diagnostic](hub_dns_diagnostic.py) uses `snet-dns-diagnostic`
(`10.100.1.0/28`) for resolver and firewall queries. `REPLICATED_DNS_OK` requires
the actual database IP over UDP/TCP through both servers and matching central
Azure-zone SOA answers. It does not claim Oracle-to-Azure forwarding works.
Topology probes separately require the actual Azure A record to match the OCI
node and the zone's hub link to be completed. Participant NSGs remain unchanged.

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

### Reproducible Oracle SQL ingress

Azure routes, firewall and NSGs remain Bicep-managed. The
`Oracle.Database/dbSystems@2025-09-01` schema exposes no OCI NSG rules or NSG IDs;
an Azure NSG cannot replace that separate Oracle-side control.
Participants create their own client rule in the
[network security challenge](../walkthrough/configure-odaa-basedb-nsg/configure-odaa-basedb-nsg.md).
The following reconciliation is for organizer/CI validation, not workshop
preparation before that exercise.

> [!WARNING]
> Do not run `configure-network` or the Phase-B test workflow while participants
> are completing the rule-creation challenge. They add all seven client rules
> to the shared OCI NSG and would pre-complete that exercise.

For organizer/CI validation after the exercise, run:

```bash
python3 tests/base_database.py configure-network --dry-run
python3 tests/base_database.py configure-network
```

Use the same explicit subscription, owner, zone, central anchor and OCI
authentication environment as creation/discovery, including
`OCI_COMPARTMENT_ID`. The workflow runs this automatically before SQL probes.
The command verifies DB ownership/availability, the live seven Azure VNet
prefixes, and the actual DB node VNIC, anchor subnet, VCN and linked compartment.
It adds only missing stateful ingress rules for TCP 1521 from those seven
`/24` networks, verifies the result, and makes no changes on a second run.
It does not open SSH, DNS, a whole `10.0.0.0/8` range or public ingress, and does
not replace provider rules, subnet security lists or managed route tables.
Drifted rules carrying its ownership description require explicit review.

An organizer can invoke this OCI step after Bicep, without putting an OCI API key
into an ARM deployment. A Bicep `deploymentScripts` wrapper would still require
OCI authentication, separate OCI calls and lifecycle handling; it is not native
Bicep management of Oracle NSGs.

### Secure SQL credentials

Both SQL bootstrap and validation initialize python-oracledb Thick mode using
the image-provided Instant Client. The database requires Native Network
Encryption/Data Integrity; Thin mode fails with `DPY-3001` inside `DPY-6005`
even when TCP 1521 is reachable. Do not disable database encryption to make a
client test pass. No image rebuild is needed when using the prepared `1.1.0`
client image, which already includes Instant Client and its loader configuration.

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

### Optional SQL latency measurement

The prepared secure probe also supports `python3 sql_probe.py --latency`.
This is an organizer option inside the managed Run Command environment
described above, while its short-lived root-only credential file and discovered
`TEST_DB_*` variables are available. It is not a participant command and does
not run from a local machine without private database connectivity and that
secure credential setup.

The option first verifies the intended PDB, then runs one warm-up and ten
separately timed `SELECT 1 FROM dual` calls on the same connection. It prints
JSON with `samples`, `unit` (`ms`), `min`, `median` and `max`. Login and warm-up
are excluded; the result includes SQL execution and is not pure network RTT.
The normal CI invocation remains unchanged and does not enable this option
automatically. Participant measurements use `ociping` and `connping` instead.

## Cleanup safety

Only resources tagged `workshop=odaa` and `managed-by=workshop-base-db` are eligible.
Test cleanup additionally restricts `automation-owner` to its GitHub run/attempt.
Only DB systems in `rg-odaa-shared` in ODAA subscription
`4ce5b5cc-e869-451f-98fc-f50448849ee0` are eligible. Other participants' run-owned
databases are preserved by the exact `automation-owner` constraint, not by
separate resource groups. This cleanup constraint does not restrict a
participant's approved manual management rights over other databases.
No network anchors are enumerated or deleted,
even if an old anchor carries workshop ownership tags. Existing same-name test
databases are never overwritten or adopted.

DB deletion must be verified absent. API/list/delete failures stop cleanup; they
never become empty lists, false 404s or success summaries. The cleanup workflow
preserves all shared anchors, DNS, Azure/OCI networking, exactly seven VMs,
identity accounts and credentials. Infrastructure teardown and credential
rotation are separate organizer operations, not part of DB cleanup.

```powershell
./infra/scripts/cleanup-base-database.ps1 -SubscriptionId '<subscription>' -WhatIf
./infra/scripts/cleanup-base-database.ps1 -SubscriptionId '<subscription>' -Confirm:$false
```

## Local validation and template build

```bash
az bicep build --file tests/bicep/base-db-test.bicep --stdout
python3 -m unittest discover -s tests -p 'test_*.py' -v
bash -n tests/run-tests.sh
```

Deployment and offline tests compile the same Bicep source directly; there is
no checked-in generated ARM JSON copy to keep aligned. The template deploys only
the DB system, using cross-resource-group central anchor IDs. Mocks cover metadata selection,
unit handling, cleanup ownership/order/API failures, PDB descriptor parsing,
SQL container validation, ARM deployment-output guards, the fixed seven-user
mapping, hub-only routing, firewall DNS, replicated UDP/TCP DNS, remote exit
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

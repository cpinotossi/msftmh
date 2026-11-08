---
title: Create an Oracle Base Database@Azure DB system
description: Provision a private single-node Base Database and a workshop PDB.
---

## Challenge 2: Create a Base Database

[Back to the workshop](../../README.md)

Base Database uses a DB system, a container database (CDB), and one or more
pluggable databases (PDBs). It is not the Autonomous Database creation wizard.
Use the Base Database service in Oracle Database@Azure. Depending on the portal
experience, database provisioning opens the linked OCI console.

## Approved workshop target

| Setting | Workshop value |
|---------|----------------|
| Azure subscription / resource group | ODAA subscription / your own `rg-odaa-mhuserN` |
| Region | France Central |
| Availability zone | Same zone as the assigned Network Anchor |
| Deployment | One single-node DB system per participant, no RAC |
| Edition / license | Enterprise Edition / License Included |
| Database version | Oracle 26ai, using an exact version offered in this region |
| Shape | Organizer-approved supported VM shape; candidate `VM.Standard.x86` |
| Compute | Explicitly approved count within the selected shape's limits |
| Initial data storage | 256 GB candidate, subject to shape constraints and approval |
| DB system / hostname | Organizer-assigned name for `mhuser1` through `mhuser7` |
| CDB / PDB | `BASEN` / `WORKSHOPN`, using your participant number |
| Listener | TCP 1521 on the private network |
| SSH access | Your public key; keep the private key local |

> [!IMPORTANT]
> Shape, compute and the exact 26ai version are not yet regionally validated.
> Do not deploy until the organizer confirms them. `cpuCoreCount`, OCPUs and
> ECPUs are not interchangeable. Do not copy ADB's compute or 20 GB storage
> settings. Oracle documents 256 GB as the minimum Base Database data storage;
> recovery and software volumes add storage and cost.

Organizers can inspect the regional catalogs without deploying:

```bash
az oracle-database database-system-shape list \
  --subscription sub-mhodaa --location francecentral -o json
az oracle-database db-system-db-version list \
  --subscription sub-mhodaa --location francecentral -o json
```

Use the exact API version string from the catalog, not an assumed literal
`26ai`. If 26ai is unavailable, stop and agree an alternative with the organizer.
Also check the tenancy's region subscription, service quotas, availability zone
mapping, and estimated costs for the total participant count.

## Verify the prepared infrastructure

In the ODAA subscription, open `rg-odaa-shared` and verify:

* `vnet-odaa-shared` and `snet-odaa-delegated`
* Subnet delegation to `Oracle.Database/networkAttachments`
* Resource Anchor `anchor-odaa-shared`
* Central Network Anchor `nw-anchor-workshop`
* Connected peering to `vnet-workshop-hub`, not directly to your spoke

Bicep prepares these resources after Oracle onboarding. Your own VM is in
`rg-vm-mhuserN` and `vnet-vm-mhuserN`; its traffic reaches Oracle through the
hub firewall. Do not recreate shared resources or change their address space.

## Select the centrally managed Network Anchor

Network Anchors connect the delegated Azure subnet to OCI networking. They are
zonal: the DB system must use the same region and zone.

1. Open Oracle Database@Azure, Multicloud Resources, Network Anchors.
2. Select `nw-anchor-workshop`. Participants do not create, change or delete it.
3. Use `rg-odaa-shared`, France Central, the approved zone,
   `anchor-odaa-shared`, `vnet-odaa-shared`, and `snet-odaa-delegated`.
4. Review the required client and backup subnet configuration for the selected
   shape. Do not invent an overlapping backup CIDR.
5. Inspect the enabled DNS listening/forwarding endpoints. Azure Oracle-domain
   queries arrive from the hub resolver outbound subnet; Oracle Azure-domain
   queries are forwarded to resolver inbound IP `10.100.0.132`.
6. Do not apply participant cleanup tags to this shared anchor.
7. Verify successful provisioning before creating your DB system.

The Azure private zone is centrally managed in `rg-workshop-hub`.
Oracle's native hostname domain is resolved through the Network Anchor
listening endpoint. The organizer configures the actual OCI subnet domain and
listening IP in the Azure forwarding ruleset.

> [!NOTE]
> Use only your assigned anchor and subnet capacity. If the service rejects an
> additional anchor in the prepared subnet, stop and ask the organizer to assign
> an existing compatible anchor or provision separate delegated subnet capacity.
> Do not delete another participant's anchor.

## Create the DB system and initial PDB

1. Select Oracle Base Database Service, Create DB system. Do not select
   Autonomous Database.
2. Select your own `rg-odaa-mhuserN`, shared Resource Anchor/linked compartment,
   shared Network Anchor and matching region/zone.
3. Enter the unique DB system name and hostname assigned by the organizer.
4. Select the approved shape, compute count, Enterprise Edition, License
   Included, and data storage allocation.
5. Upload an SSH public key. If you need a key, run the following locally and
   upload only the `.pub` file. Do not overwrite an existing key.

   ```bash
   ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/odaa-basedb-mhuserN"
   ```

6. Use the private client subnet associated with the assigned anchor. Do not
   expose the database listener to the internet.
7. Select the actual regional 26ai database image/version approved by the
   organizer. Enter CDB name `BASEN` and PDB name `WORKSHOPN`.
8. Enter the administrator password and confirm the TDE wallet configuration.
   Store credentials outside the repository. Follow the portal's password
   requirements; Oracle's current guide requires 9 to 30 characters with at
   least two uppercase, lowercase, numeric and special characters (`_`, `#`, `-`).
9. For this disposable workshop, disable automatic backups if the organizer has
   approved doing so. This is not a production backup recommendation.
10. Set the DB system tags to `workshop=odaa`,
    `managed-by=workshop-base-db`, and `automation-owner=participant-mhuserN`.
    These tags apply only to your database, not to the shared anchor. Without them cleanup
    intentionally leaves the database running.
11. Review the full cost and settings, then create the DB system.

Provisioning can take substantially longer than ADB provisioning. Wait for
successful provisioning and the OCI `AVAILABLE` lifecycle state. Treat a failed
or timed-out deployment as a failure, not as permission to continue.

## Record the connection details

Record the following values from the DB system/node and database/PDB details:

* Azure DB system resource ID and associated Network Anchor ID
* OCI DB system, node/VNIC and database identifiers
* The single node's private IPv4 address
* The actual native Oracle hostname, PDB service name and listener port

Do not use ADB's `privateEndpointIp`, `privateEndpointLabel`, `_high` service or
ADB connection profile fields. A PDB service name can include a domain and is
not necessarily equal to the PDB name.

If the portal does not show the PDB service, the database administrator can
inspect services on the DB host as the Oracle software owner:

```sql
show pdbs
select name, network_name, pdb from cdb_services where pdb = 'WORKSHOPN';
```

The PDB must be open and its service registered with the listener. On the DB
host, `lsnrctl status` helps verify listener services. Do not guess the service
name or use the CDB root service for participant exercises.

## Prepare a limited workshop user

The database administrator creates the user in the intended PDB, not in CDB
root. Use SQL*Plus interactively and enter the administrator password at the
prompt:

```bash
sqlplus -L 'sys@//NODE_PRIVATE_IP:1521/ACTUAL_PDB_SERVICE as sysdba'
```

Verify the container, then create a limited account. Enter a separate
workshop password at the hidden prompt; do not reuse the SYS password.
For this example, choose a password containing only letters, digits, `_`, `#`
and `-` so SQL*Plus substitution cannot alter the statement.

```sql
show con_name
set verify off
accept workshop_password char prompt 'Workshop password: ' hide
create user workshop identified by "&workshop_password";
undefine workshop_password
grant create session to workshop;
```

Only proceed if `show con_name` reports your assigned workshop PDB. The baseline connectivity
exercise needs `CREATE SESSION`, not DBA privileges.

## Success criteria

* The DB system is available with the approved version, shape and license.
* The PDB is open and the correct PDB service is known.
* The node has a private address in the assigned network.
* The `WORKSHOP` account exists in the intended PDB.

Continue with [networking and DNS](../update-odaa-basedb-nsg-dns/update-odaa-basedb-nsg-dns.md).

## References

* [Oracle Base Database creation](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/azucr-create-base-database.html)
* [Network Anchor design](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/network-anchor-design.htm)
* [Azure DB system CLI](https://learn.microsoft.com/cli/azure/oracle-database/db-system)

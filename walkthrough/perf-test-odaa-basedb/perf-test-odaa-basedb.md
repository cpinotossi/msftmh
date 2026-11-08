---
title: Test Base Database SQL connectivity and latency
description: Connect to the intended PDB and measure SQL round trips from the workshop VM.
---

## Challenge 4: Connect and measure SQL latency

[Back to the workshop](../../README.md)

Complete [private networking and DNS](../update-odaa-basedb-nsg-dns/update-odaa-basedb-nsg-dns.md)
first. Connect to your `vm-mhuserN` through the central Azure Bastion. The client image contains
Oracle Instant Client, SQL*Plus, SQLcl and rwloadsim/connping.

Base Database does not use ADB's `ADMIN` user, `_high` service or downloaded ADB
wallet. This private workshop uses TCP 1521. For production, design transport
encryption explicitly; a private route is not encryption and this example is
not a production TLS configuration.

## Connect to your PDB

Obtain the actual PDB service from the administrator. Replace
`ACTUAL_PDB_SERVICE` below; do not infer it from the hostname or CDB name.

```bash
source /etc/profile.d/oracle-workshop.sh
sqlplus -L 'workshop@//ACTUAL_ORACLE_HOSTNAME:1521/ACTUAL_PDB_SERVICE'
```

Enter the workshop user's password at the prompt. Do not use SYS for performance
tests or put a password on the command line.

Run the following inside SQL*Plus:

```sql
whenever oserror exit failure
whenever sqlerror exit failure rollback
set heading off feedback off pagesize 0
select 'SQL_OK:' || sys_context('USERENV', 'CON_NAME') from dual;
```

The result must identify your assigned workshop PDB. An open TCP port, a successful login to
CDB root, or an `ORA-` error does not satisfy this challenge.

## Measure repeated SQL round trips

Stay in the same SQL*Plus session:

```sql
set timing on
select 1 from dual;
/
/
/
/
/
set timing off
exit
```

Record the individual elapsed times. Repeat after a warm-up and compare
minimum, median and maximum times across samples. These measurements include
client processing, network and database execution; they are not pure network
RTT and are not a throughput benchmark.

Do not use one server-side PL/SQL loop to estimate client/network round trips.
The repeated `/` commands execute separate statements from the client.

## Optional connection benchmarks

`connping` is a database connection tool, not `connping IP PORT`.
Read `connping --help` for the installed version and use the actual PDB service
and limited workshop credentials. Avoid exposing passwords through shell
history, process arguments or reports; use a supported secure credential
mechanism before automating this optional benchmark.

ADB-specific `adbping` is not installed or required by the Base Database image.
For a separate TCP reachability check use `nc`, not a SQL latency tool.

## Troubleshooting

| Symptom | Check |
|---------|-------|
| No DNS answer | VNet custom DNS, firewall proxy, hub resolver/ruleset and Network Anchor listening endpoint |
| Timeout or refused TCP | Exact Oracle route, hub firewall, OCI rules, host firewall and listener |
| ORA-12514 | Exact PDB service, PDB open state and listener registration |
| ORA-01017 | PDB-local account, password and intended service |
| Unexpected container | You connected to the wrong service |

## Success criteria

* `SQL_OK:WORKSHOPXX` is returned from the intended PDB.
* Multiple client-driven SQL statements complete without errors.
* You distinguish DNS, TCP connectivity, SQL round trips and connection setup.

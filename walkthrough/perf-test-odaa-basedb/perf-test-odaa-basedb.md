---
title: Measure database round trips with ociping and connping
description: Run ociping and connping through portal Bastion and interpret measured database connection, Oracle Net and SQL timings.
---

## Challenge 6: Measure database round trips

[Workshop overview](../../README.md)

> [!WARNING]
> **User2 is only an example.** Replace `mhuser2`, `vm-mhuser2`,
> `rg-vm-mhuser2` and `basedb2` with your own assigned user
> number and resource names. Tenant, subscriptions, shared networking and PDB
> `WORKSHOP` stay the same.

Complete the [Easy Connect login](../connect-odaa-basedb/connect-odaa-basedb.md)
first. Have the Easy Connect string from
[Challenge 5](../connect-odaa-basedb/connect-odaa-basedb.md#step-3-copy-the-workshop-pdb-connection-string)
ready. Use the administrator password you saved during database creation.
`WORKSHOP` is the PDB name; `SYSTEM` is the login.
No additional database user is created.

Run each Bash command in your VM shell in the Bastion browser tab.
No local terminal, Azure CLI, package installation or additional database user
is needed. This challenge uses only `ociping` and `connping` for measurements.

## Step 1: Sign in to the Azure portal

1. Open the [Azure portal](https://portal.azure.com/) in your workshop browser.
2. Sign in with your assigned account, for example `mhuser2@cptdemo.org`,
   and complete MFA when prompted.

## Step 2: Select your VM

1. In the portal search bar, search for **Virtual machines** and open the service.
2. Select your assigned VM, for example `vm-mhuser2` in `rg-vm-mhuser2`.

## Step 3: Inspect your VM

On **Overview**, check that the VM is **Running**. If it is stopped,
select **Start** and wait until it is running.

## Step 4: Connect through Bastion

1. On the VM page, select **Connect > Connect via Bastion**.
2. Use the existing Bastion host `bas-workshop-hub`.
3. Under **Connection settings**, select **SSH**, port `22`, and
   **Microsoft Entra ID** as the **Authentication type**.
4. Select **Connect** and allow popups.
5. Run all remaining commands in this Bastion browser tab,
   as in the
   [DNS challenge](../verify-odaa-basedb-dns/verify-odaa-basedb-dns.md#connect-to-your-vm-through-bastion-and-test-dns).

## Step 5: Prepare the measurement tools

In the **VM shell**, check the machine:

```bash
hostname
```

For User2, the result is `vm-mhuser2`.

Load the prepared Oracle environment:

```bash
source /etc/profile.d/oracle-workshop.sh
```

Both tools are already installed in the workshop image. Check their help:

```bash
ociping --help
```

```bash
connping --help
```

The tested User2 VM reports release `3.3.0.1`. The tools use Oracle Instant
Client; keep the database's required encryption settings unchanged.

## Step 6: Enter the database endpoint

In the **VM shell in the Bastion browser tab**, save your Easy Connect
string in `DB_CONNECT`. Replace the value inside the quotes with the string
copied from OCI. This example is for User2. Do not add spaces around `=`.

```bash
DB_CONNECT='basedb2.ocisnetodaadel.ocivnetodaasha.oraclevcn.com:1521/WORKSHOP.ocisnetodaadel.ocivnetodaasha.oraclevcn.com'
```

Keep the full string, including `:1521/` and the domain after `WORKSHOP`.
Do not include a username or password.

## Step 7: Measure Oracle Net round trips with ociping

Run this command in the VM shell:

```bash
ociping -l "SYSTEM@//${DB_CONNECT}" --period=60 --interval=1
```

Enter the administrator password when prompted. It is not displayed.
Never put the password into a command, shell variable or file.
Do not record the terminal while entering credentials.

The tool authenticates once, then repeatedly calls Oracle's `OCIPing()` on
the same connection. It does not execute a SQL query and is not an ICMP ping.
The requested run period is 60 seconds with a one-second interval.
The final statistics appear when the tool finishes.

### User2 example output

This is an excerpt from the participant's actual run; intermediate lines
are omitted:

```text
Connected default database to:
Oracle AI Database 26ai Standard Edition 2 Release 23.26.4.0.0 - Production
1.182 6.7
1.120 7.7
1.127 8.7
1.992 57.7
1.117 58.7
1.126 59.7
ociping (ms) mean=1.199, stddev=0.160, min=1.110, max=1.992
```

In `1.182 6.7`, the first number is the round-trip duration in
**milliseconds**. The second number is elapsed time within the test run
in **seconds**, not another latency value.

| Statistic | User2 result | Meaning                         |
|-----------|--------------|---------------------------------|
| `mean`    | 1.199 ms     | Average round-trip duration      |
| `stddev`  | 0.160 ms     | Spread of the measured durations |
| `min`     | 1.110 ms     | Fastest measured round trip      |
| `max`     | 1.992 ms     | Slowest measured round trip      |

This run averaged about **1.2 ms** with relatively little variation.
It measures the VM-to-database path and Oracle client/server processing,
not pure network transit. Your browser-to-Bastion connection is not part
of this measured round trip. Your results may differ.

## Step 8: Compare login, Oracle ping and SQL with connping

Run this command in the same VM shell:

```bash
connping -l "SYSTEM@//${DB_CONNECT}" --period=60 --interval=1
```

Enter the password again when prompted.
Unlike `ociping`, this tool repeatedly creates a new connection. For each
connection, it measures login, an Oracle ping and a simple query against
`dual` separately.

### User2 example output

These are the participant's actual results from an earlier short
10-second run. It produced only two measurement rows, so use the 60-second
command above for a longer observation.

```text
connect:50.85 ms, ociping:1.179 ms, dualping:1.276 ms, sid=52, inst#=1, time=8.8
connect:66.65 ms, ociping:2.280 ms, dualping:2.305 ms, sid=52, inst#=1, time=9.8
connect mean=58.75, stddev=7.90, min=50.85, max=66.65
ociping mean=1.73, stddev=0.55, min=1.18, max=2.28
dualping mean=1.79, stddev=0.51, min=1.28, max=2.31
```

All three duration measurements and their summary statistics are in
**milliseconds**, including the summary lines without an explicit `ms`.

| Measurement | User2 average | Meaning                                      |
|-------------|---------------|----------------------------------------------|
| `connect`   | 58.75 ms      | Establish a new connection and authenticate   |
| `ociping`   | 1.73 ms       | Perform an Oracle ping after login            |
| `dualping`  | 1.79 ms       | Execute a simple query and receive its result |

`stddev`, `min` and `max` have the same meaning as in the previous table.
`sid` identifies the database session, `inst#` the database instance,
and `time` the elapsed test time in seconds.

In this short run, login took much longer than a ping or query after login.
This illustrates why applications often reuse connections through a
connection pool. Two samples are not enough for a reliable performance
baseline. Do not treat these values as guaranteed workshop targets or
directly compare their averages with a longer run taken at another time.

> [!IMPORTANT]
> The blocks marked as output are examples, not commands.
> Do not paste `ociping mean=...` or `dualping mean=...` into the shell.
> `dualping` is a measurement label from `connping`, not a separate command.

## Step 9: Explain the difference between the tools

| Tool       | Connection behavior       | Measurements                           |
|------------|---------------------------|----------------------------------------|
| `ociping`  | Reuses one connection     | Oracle ping round trips                |
| `connping` | Reconnects for each sample | Login, Oracle ping and SQL query times |

The `ociping` label inside `connping` output describes its Oracle ping
measurement; it does not mean you need to run an extra command.
Both tools include client/server processing in their timings.
A fractional value such as `0.650 ms` is less than one millisecond.

References: Oracle's [ociping manual](https://oracle.github.io/rwloadsim/refman/ociping.html)
and [connping manual](https://oracle.github.io/rwloadsim/refman/connping.html).

## Step 10: Close the VM session

After both tools finish, you are back at the VM shell prompt.
End the Bastion session:

```bash
exit
```

This ends the VM session in the browser.

No database or VM is deleted or stopped. Cleanup is a separate
[organizer operation](../../infra/scripts/cleanup-base-database.ps1).

## Success criteria

* Both tools authenticated to your PDB as `SYSTEM` without exposing the password.
* You measured round trips with `ociping` and login/SQL timings with `connping`.
* You can explain milliseconds, elapsed test seconds and the four summary statistics.
* You can distinguish login time, Oracle ping time and SQL query time.

No user, table or grant is created or changed. The workshop uses `SYSTEM`
without SYSDBA; use a least-privilege account for production applications.

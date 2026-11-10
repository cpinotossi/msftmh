---
title: Connect to BaseDB with Easy Connect
description: Open OCI from Azure, retrieve the PDB connection string and connect with SQLPlus through portal Bastion.
---

## Challenge 5: Retrieve the PDB connection string and connect

[Workshop overview](../../README.md)

> [!WARNING]
> **User2 is only an example.** Replace `mhuser2`, `vm-mhuser2`,
> `rg-vm-mhuser2` and `basedb2` with your own assigned user
> number and resource names. Tenant, subscriptions, shared networking and PDB
> `WORKSHOP` stay the same.

Complete the [DNS challenge](../verify-odaa-basedb-dns/verify-odaa-basedb-dns.md)
first. Keep your database hostname and private IP ready, along with the
administrator password saved during database creation.

The synchronized `mh-workshop-participants` group has read access to database
and virtual network details in the OCI workshop compartment through
`mh-workshop-participants-readonly`. Entra signs you in; this OCI policy
allows you to view the resources. The separate NSG rule-editing permission
is used in the preceding
[security challenge](../configure-odaa-basedb-nsg/configure-odaa-basedb-nsg.md).

## Step 1: Open your BaseDB system from Azure

1. Open the [Azure portal](https://portal.azure.com/).
2. Search for **Oracle AI Database@Azure** and open the service.

   ![Oracle Database@Azure](media/image%20copy%2021.png)

3. Open **Oracle Base Database Service** and select your BaseDB system,
   for example `basedb2` for User2.

   ![Oracle Base Database](media/image%20copy%2022.png)

4. On **Overview**, verify that the system is available.
5. Select **Go to OCI**. The OCI Console opens in a new browser tab.

   ![Go to OCI](media/image%20copy%2023.png)

6. If asked, enter tenancy `cptdemo` and select identity domain **Default**.
7. Select **Microsoft Entra ID - CPTDEMO Workshop** and sign in with your
   assigned account, for example `mhuser2@cptdemo.org`. Complete Entra MFA
   when prompted.

## Step 2: Verify the database node

1. On your DB system page, open **Nodes**.

   ![Database Nodes](media/image%20copy%2024.png)

2. Find the database node and note **Private IP address** and **DNS name**.

   ![Database Node Details](media/image%20copy%2025.png)

3. Compare them with the private IP and full hostname from the DNS challenge.

## Step 3: Copy the WORKSHOP PDB connection string

1. On the DB system page, open **Databases**.
2. Find your database row, for example `basedb2`. Open **...** at the right
   end of that row and select **View database**.

   ![View database](media/image%20copy%2026.png)

3. You are now viewing the container database (CDB), which contains the
   pluggable databases (PDBs). Open **Pluggable Databases (PDB)**.

   ![Pluggable Databases](media/image%20copy%2027.png)

4. Find `WORKSHOP`. Open **...** on that row and select **PDB connection**.

   ![PDB connection](media/image%20copy%2028.png)

5. Select **Easy Connect** and copy the connection string.

   ![Easy Connect format](media/image%20copy%2029.png)

The format is `<host>:1521/<pdb-service>`. For User2:

```text
basedb2.ocisnetodaadel.ocivnetodaasha.oraclevcn.com:1521/WORKSHOP.ocisnetodaadel.ocivnetodaasha.oraclevcn.com
```

Keep the full string, including the domain after `WORKSHOP`.

## Step 4: Open your VM through Azure portal Bastion

Bastion opens a shell on your Azure VM. SQL*Plus on that VM connects
to the BaseDB over the private network.

1. Return to the Azure portal and open **Virtual machines**.
2. Select your VM, for example `vm-mhuser2` in `rg-vm-mhuser2`.
3. Check that the VM is **Running**. If it is stopped, select **Start**
   and wait until it is running.
4. Select **Connect > Connect via Bastion** and use `bas-workshop-hub`.
5. Select **SSH**, port `22`, and **Microsoft Entra ID** authentication.
6. Select **Connect** and allow popups.

Run all following shell commands in the Bastion browser tab.
You can reuse your session from the DNS challenge if it is still open.

## Step 5: Connect with the Easy Connect string

Load the prepared Oracle client:

```bash
source /etc/profile.d/oracle-workshop.sh
```

Replace the value inside the quotes with your Easy Connect string from
Step 3. This example is for User2. Do not add spaces around `=`.
Do not include a username or password in the value.

```bash
DB_CONNECT='basedb2.ocisnetodaadel.ocivnetodaasha.oraclevcn.com:1521/WORKSHOP.ocisnetodaadel.ocivnetodaasha.oraclevcn.com'
```

Connect as `SYSTEM`:

```bash
sqlplus -L "SYSTEM@//${DB_CONNECT}"
```

At `Enter password:`, enter the administrator password saved during database
creation. It is not displayed. Never include it in a shell command.
After a successful login, the prompt changes to `SQL>`.

![SQLPlus prompt](media/image%20copy%2030.png)

SQL*Plus uses the prepared Oracle Instant Client and preserves database
encryption. No OCI CLI credentials or additional installation are needed.

## Step 6: Verify the PDB connection

At the **SQL*Plus prompt**, run each command separately:

```sql
SHOW USER
```

Expected: `USER is "SYSTEM"`.

```sql
SHOW CON_NAME
```

Expected: `WORKSHOP`.

```sql
SELECT 1 AS result FROM dual;
```

Expected: one row with `RESULT` equal to `1`.

## Step 7: Close the connection

Leave SQL*Plus:

```sql
EXIT
```

You are back in the VM shell. End the Bastion session:

```bash
exit
```

Neither command stops or deletes the VM or database.

## Success criteria

* The OCI node's private IP matches the DNS record.
* You have saved your full Easy Connect string.
* You connected as `SYSTEM` to `WORKSHOP` and a SELECT returned `1`.

Next: [Measure database round trips](../perf-test-odaa-basedb/perf-test-odaa-basedb.md).

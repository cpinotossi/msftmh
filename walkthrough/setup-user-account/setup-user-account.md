---
title: Set up your workshop account
description: Sign in with your assigned identity and connect to your private VM through Bastion.
---

## Challenge 0: Set up your account

[Workshop overview](../../README.md)

> [!WARNING]
> **User2 is only an example.** Replace `mhuser2`, `vm-mhuser2`,
> `rg-vm-mhuser2` and `basedb2` with your own assigned user
> number and resource names. Tenant, subscriptions, shared networking and PDB
> `WORKSHOP` stay the same.

Use the Azure portal in your browser. Open your VM shell through the prepared
Bastion host; no local terminal or Azure CLI is needed.

## Step 1: Sign in

1. Open the [Azure portal](https://portal.azure.com/) in a private browser window.
2. Sign in with your assigned account, for example `mhuser2@cptdemo.org`.
3. Complete the initial password change and MFA.
4. In the account menu, verify that you are using directory
   `8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5`.

Do not put passwords, MFA codes or tokens into shell commands or shared output.

## Step 2: Inspect both subscriptions

1. In the Azure portal search bar, search for **Subscriptions** and open
   the service.
2. Open subscription `aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483`. It contains the
   client VMs and Bastion. Check its subscription ID on **Overview**.
3. Return to **Subscriptions** and open `odaa`
   (`4ce5b5cc-e869-451f-98fc-f50448849ee0`). It contains the Oracle resources.
4. Verify that both belong to directory
   `8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5`.

## Step 3: Connect to your VM

1. In the portal search bar, search for **Virtual machines** and open the service.
2. Open your VM, for example `vm-mhuser2` in `rg-vm-mhuser2` for User2.
3. On **Overview**, check that its status is **Running**. If it is stopped,
   select **Start** and wait until it is running.
4. Select **Connect > Connect via Bastion** and use `bas-workshop-hub`.
5. Under **Connection settings**, select **SSH**, port `22`, and
   **Microsoft Entra ID** as the **Authentication type**.
6. Select **Connect** and allow popups. Your VM shell opens in a Bastion
   browser tab.

## Step 4: Inspect your VM session

In the **VM shell in the Bastion browser tab**, display the machine name:

```bash
hostname
```

For User2, the result is `vm-mhuser2`. Display your Linux login name:

```bash
whoami
```

End the VM session:

```bash
exit
```

This closes the shell session in the Bastion browser tab, not the Azure portal.

## Your access

| Scope | Participant access |
|-------|--------------------|
| Own `rg-vm-mhuserN` | Contributor |
| Own `vm-mhuserN` | Entra SSH with Virtual Machine User Login |
| `rg-workshop-hub` and `rg-workshop-images` | Reader |
| `rg-odaa-shared` in the ODAA subscription | BaseDB management; shared infrastructure read-only |
| Tagged workshop OCI NSG | View details and change security rules; add only your own client SQL rule |

This is a shared database-management lab. Work only on your assigned database,
even though the group can manage all participant databases.

Next: [Understand the ODAA subscription](../create-odaa-subscription/create-odaa-subscription.md).

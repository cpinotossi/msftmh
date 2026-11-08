---
title: Set up your workshop account
description: Sign in with your assigned mhuser identity, register MFA and verify isolated resource access.
---

## Challenge 0: Set up your account

[Back to the workshop](../../README.md)

The workshop has exactly seven identities, `mhuser1` through `mhuser7`, in
tenant `8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5`. Use your organizer-provided UPN
and initial password, not an account from the previous workshop tenant.

## Sign in and register MFA

1. Open a private browser window or a separate browser profile.
2. Sign in to the [Azure portal](https://portal.azure.com/) using your assigned
   account, for example `mhuser1@mngenvmcap956455.onmicrosoft.com`.
3. Change the initial password when prompted.
4. Complete the tenant's MFA registration prompts. Use
   [Microsoft's MFA guide](https://learn.microsoft.com/entra/identity/authentication/tutorial-enable-azure-mfa)
   if you need help.
5. Verify the selected directory is the new workshop tenant.

Do not share your password, MFA registration information or session tokens.

## Verify your access

For `mhuser1`, expect the following. Replace `1` with your assigned number.

| Resource / scope | Access |
|------------------|--------|
| Workshop `rg-vm-mhuser1` | Contributor, without role-assignment rights |
| Your `vm-mhuser1` | Virtual Machine User Login |
| Workshop `rg-workshop-hub` | Reader only |
| Workshop `rg-workshop-images` | Reader only |
| ODAA `rg-odaa-mhuser1` after Phase B | Restricted BaseDB creator role |
| Shared Oracle infrastructure after Phase B | Reader and required catalog-read actions |

The hub and all VM spokes are in workshop subscription
`aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483`. Oracle resources are in
`4ce5b5cc-e869-451f-98fc-f50448849ee0`.

You may inspect firewall, DNS resolver, routing and central DNS settings to
learn the architecture. You cannot modify shared resources or another
participant's spoke. Report missing access to the organizer; do not request
Owner or subscription-wide Contributor as a workaround.

## Connect to your VM

After the organizer confirms the image and VM deployments are complete:

```bash
az login --tenant 8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5
az network bastion ssh \
  --subscription aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483 \
  --name bas-workshop-hub \
  --resource-group rg-workshop-hub \
  --target-resource-id /subscriptions/aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483/resourceGroups/rg-vm-mhuser1/providers/Microsoft.Compute/virtualMachines/vm-mhuser1 \
  --auth-type AAD
```

Use your own VM name and resource group. If only the spoke network exists
because image/SKU capacity is pending, VM login is not ready yet.

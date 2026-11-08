---
title: Stateless workshop identity
description: Exactly seven fixed Entra users and one group through a transparent Graph script
---

## Supported mode and Bicep limitation

All Azure infrastructure uses Bicep. Identity creation is the necessary
exception: the official [Microsoft.Graph/users reference](https://learn.microsoft.com/en-us/graph/templates/bicep/reference/users?view=graph-bicep-1.0)
supports only read-only `existing` users, not user creation or password profiles.
The Graph Bicep extension therefore cannot provision these participants.

`provision.ps1` uses Azure CLI authentication and Microsoft Graph v1.0 directly.
There is no Terraform, backend, storage access, deployment script, privileged
managed identity, or persistent infrastructure state. Directory lookups are
authoritative; the private JSON file is a credential export, not state.
Do not change or bypass the organization's storage network policy.

Creation requires a delegated Azure CLI administrator session. Graph v1.0
[does not reliably list service-principal group owners](https://learn.microsoft.com/en-us/graph/api/group-list-owners?view=graph-rest-1.0),
so app-only creation is deliberately rejected rather than weakening ownership
checks. CI uses OIDC for read-only verification of identities created locally.

## Fixed roster

* Tenant: `8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5`
* Verified domain: `mngenvmcap956455.onmicrosoft.com`
* Participants: exactly `mhuser1` through `mhuser7`
* Participant keys: `"01"` through `"07"`
* Group: `mh-workshop-participants`

No tenant, domain, count, user-name, or group-name options exist. The only
arguments are the mandatory private `OutputFile` and optional `ReadOnly`.
Use PowerShell 7.3 or later on Linux or macOS.

## Local creation command

Use the Azure CLI session signed into the fixed tenant with an active Global
Administrator role. User Administrator is ordinarily sufficient for these
non-admin users and their ordinary security group. Global Administrator does
not grant Azure RBAC, but this script needs no Azure resource or storage role.

If necessary, sign in explicitly:

```bash
az login --tenant 8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5 --allow-no-subscriptions
```

Create a private directory and provision the fixed identities:

```bash
install -d -m 700 "$HOME/.workshop-secrets"
pwsh -NoProfile -File infra/identity/provision.ps1 \
  -OutputFile "$HOME/.workshop-secrets/user_credentials.json"
```

The script acquires a Graph token without printing it. It checks the Azure CLI
tenant and token tenant, then validates existing groups and all seven UPNs
before any directory mutation. API failures stop execution with sanitized
errors. Actual delegated Graph permissions must be checked during the
explicitly authorized run; no identity creation is performed by offline tests.

## Ownership and reruns

New groups are owned by the signed-in administrator and marked with:

```text
msftmh fixed seven workshop participants; tenant 8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5
```

An existing group must have that description, be an ordinary security group,
have verifiable owners, and contain no unrelated members. Mutation additionally
requires the current administrator to be an owner. Unmarked, unowned, ambiguous,
or unrelated groups cause a protective abort, not automatic adoption. An
organizer must inventory and approve any existing-group migration separately.

Existing participants are reused by their exact fixed UPNs. Guest and
on-premises-synchronized user objects are rejected. Existing users are never
patched, disabled, renamed, or password-reset. Reruns create only missing fixed
objects and add only missing memberships in the verified workshop group.
No password or MFA rotation workflow remains.

## Protected export

The caller's absolute output path must be outside the workspace, with a private
parent directory and no symbolic-link ancestors. The file has mode `0600` and
is exclusively opened during the run.

`user_credentials.json` contains:

* `tenant_id` and `group_id`
* `user_object_ids` and `user_principal_names`, keyed `"01"` through `"07"`
* `users`, with object ID, username, UPN, display name, password, and password status

Passwords are cryptographically random and force a change at next sign-in.
They are never printed, passed as CLI arguments, uploaded as artifacts, or
placed in Bicep parameters. Each successful creation is saved immediately.
Candidates are saved before creation; an interrupted request can leave
`creation-unconfirmed` status. Preserve that private file for organizer review.
Do not assume an unconfirmed candidate was applied.

A rerun preserves a saved initial password only when its object ID still
matches the directory. Existing passwords cannot be read from Graph. Without a
matching saved credential, the export records `unavailable-existing` and a null
password instead of silently resetting the account. Saved initial passwords
are not guaranteed to remain current after participants change them.

To print only the non-secret IDs for Bicep integration:

```bash
pwsh -NoProfile -Command '
  $data = Get-Content -Raw "$HOME/.workshop-secrets/user_credentials.json" | ConvertFrom-Json
  $data.group_id
  $data.user_object_ids | ConvertTo-Json
'
```

Never print or commit the complete credential export.

## Manual workflows and static Bicep stages

`odaa-provision-identity.yml` is now a manual **verification** entrypoint.
It delegates to `odaa-read-identity.yml`, which runs `provision.ps1 -ReadOnly`
on a hosted runner. Missing users, incomplete membership, or an invalid group
stop the job without creation or repair. OIDC needs `AZURE_CLIENT_ID`,
federation, and admin-consented Graph read permissions such as `User.Read.All`
and `Group.Read.All`; no Graph write permissions are needed by this workflow.

The read-only workflow emits only `group_id` and seven current `user_object_ids`.
The hub is independent and has no identity dependency. Stages 03 networks and
04 receive the group ID. Network, VM, and Oracle-network stages map keys `"01"`
through `"07"` to template keys `mhuser1` through `mhuser7`. No old tenant IDs or
credential templates are consumed.

All stage entrypoints are manual and deploy one matching static `.bicepparam`
file from `../deployments/`:

* 02: `odaa-deploy-hub.yml`, workshop `rg-workshop-hub`
* 03 networks: `odaa-deploy-users.yml`, workshop subscription, `workshop-03-users`
* 03 VMs: `odaa-deploy-user-vms.yml`, workshop subscription, `workshop-03-user-vms`
* 04: `odaa-deploy-oracle-network.yml`, ODAA subscription
* 05: `odaa-deploy-oracle-connectivity.yml`, workshop subscription
* 06: `odaa-deploy-network-anchor.yml`, ODAA `rg-odaa-shared`
* 07: `odaa-deploy-oracle-dns.yml`, workshop `rg-workshop-hub`

Workshop subscription is `aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483`; ODAA remains
separate at `4ce5b5cc-e869-451f-98fc-f50448849ee0`.

Fill the actual hub firewall IP in stage 03 networks and stages 04/05. Network
deployment requires no SSH key, image, or VM capacity. The separate VM stage
requires an SSH public key, published image version `1.1.0`, and an unrestricted
`Standard_D2s_v5` SKU with enough family/regional vCPU quota for seven VMs.
It does not substitute a GPU. These checks cannot guarantee instantaneous
physical allocation capacity.

Fill the actual Oracle DNS domain (trailing dot included) and listening IP in
stage 07. Stage 06 uses fixed `zone = '1'`.
Do not invent these values or replace them with deployment inputs.

Phase A is identity, hub, image, and seven user spokes/VMs; it has no Oracle
readiness dependency. Every Phase-B deployment depends on the read-only
`RequireOracleSubscription` gate. It requires exactly one Oracle subscription
with `provisioningState=Succeeded` and `cloudAccountState=Available`.
Pending, missing, failed, ambiguous, or unreadable state prevents all Phase-B
writes.

The independent image entrypoint remains `odaa-build-image.yml`. Old monolithic
Terraform deployment/import/reset entrypoints and identity Terraform sources
are retired. Removal of the unused bootstrap resource group is a separate
organizer operation after safe inventory, not part of this script.

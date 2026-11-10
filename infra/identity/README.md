---
title: Reset workshop passwords and MFA
description: Reset the seven workshop accounts and save their temporary passwords in a private local JSON file.
---

## Reset passwords and MFA before a workshop

Run the following blocks in order from the repository root in Bash.
PowerShell 7.3 or later is required. No `az login` is needed for this reset.

Use your organizer account that owns `mh-workshop-participants`.
Activate **Global Administrator** in PIM for tenant
`8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5` before starting.

> [!WARNING]
> The reset affects all seven accounts, `mhuser1@cptdemo.org` through
> `mhuser7@cptdemo.org`. It sets new temporary passwords, removes supported
> MFA registrations and passkeys, and revokes Entra sessions.
> Run it before handing accounts to participants.

## Step 1: Install the authentication module once

```bash
pwsh -NoProfile -Command 'Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery -Force -ErrorAction Stop'
```

The module is already installed on the current organizer machine; skip this
step there.

## Step 2: Prepare the private output file

```bash
WORKSHOP_SECRETS="$(git rev-parse --show-toplevel)/.workshop-secrets"
install -d -m 700 "$WORKSHOP_SECRETS"
OUTPUT_FILE="$WORKSHOP_SECRETS/user_credentials_$(date -u +%Y%m%dT%H%M%SZ).json"
```

The directory is Git-ignored. Each run uses a new filename.
Use the same Bash terminal for the remaining steps.

## Step 3: Sign in and reset passwords and MFA

```bash
pwsh -NoProfile -File infra/identity/provision.ps1 \
  -ResetCredentials -ConfirmReset \
  -OutputFile "$OUTPUT_FILE"
```

The command starts its own Microsoft Graph login:

1. Open the device-login URL printed in this terminal.
2. Enter the code printed by this command.
3. Sign in with the organizer account whose PIM role you activated.
4. Complete MFA and approve the requested Microsoft Graph permissions.
5. Return to the terminal; the reset continues automatically.

Do not run `Connect-MgGraph` separately. The login and reset must use the same
PowerShell process. Do not share the device code.

Expected: `Seven workshop accounts reset. Private export saved; no credentials printed.`
Participants must change their temporary password at their next sign-in.
MFA policies remain unchanged and determine re-registration requirements.

## Step 4: Distribute the temporary passwords

Open the JSON file at `$OUTPUT_FILE` in a private local editor.
Display its path without printing passwords:

```bash
printf '%s\n' "$OUTPUT_FILE"
```

Check that its overall `status` is `completed`.
Each entry under `users` contains the participant's `user_principal_name`
and temporary `password`. Share only that participant's credentials through
an approved secure channel. Do not upload the JSON as a GitHub artifact,
commit it or print its contents in shared output.

If a run fails, preserve the JSON: completed changes are not rolled back.
Review its per-user status fields before distributing credentials.
A new run resets all seven accounts again.

For a default MFA phone number that Graph cannot delete, use
**Entra ID > Users > Authentication methods > Require re-register MFA** in the
[Entra admin center](https://entra.microsoft.com), then review remaining methods.
Unsupported authentication method types require separate administrator review.

This resets Entra accounts only, not local OCI passwords, OCI MFA or BaseDB
administrator passwords.

## OCI sign-in and Entra MFA

Open the [OCI Console for cptdemo](https://cloud.oracle.com/?tenant=cptdemo),
select the `Default` domain, then select
`Microsoft Entra ID - CPTDEMO Workshop`.
Sign in with your assigned `mhuserN@cptdemo.org` account.

The OCI Console sign-on policy contains the `Workshop Entra MFA` rule.
It requires both membership in the synchronized `mh-workshop-participants`
group and authentication by the configured Entra SAML identity provider.
For matching sign-ins, Entra supplies authentication without an additional
OCI MFA challenge. Keep Entra Conditional Access MFA enforcement enabled
for this application; this OCI rule does not independently validate an
Entra MFA claim.

The existing OCI administrator MFA rule remains first. The general OCI MFA
rule remains after the workshop rule, protecting local sign-ins and other
users. Do not replace these conditions with a group-only MFA exemption.
Oracle records explicit consent for the policy modification and notifies
identity-domain administrators.

After this policy change, start a new sign-in in a private browser window
rather than continuing an existing OCI MFA-enrollment flow. The saved rule
configuration was verified; an interactive participant retry is still needed.

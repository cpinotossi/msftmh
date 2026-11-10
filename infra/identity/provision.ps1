# Stateless Microsoft Graph v1.0 provisioning. The directory is authoritative.
# Passwords go only to the caller's private file, never stdout or CLI arguments.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OutputFile,
    [switch]$ReadOnly,
    [switch]$ResetCredentials,
    [switch]$ConfirmReset
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
$PSNativeCommandUseErrorActionPreference = $false
$tenant = '8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5'
$domain = 'cptdemo.org'
$groupName = 'mh-workshop-participants'
$groupDescription = "msftmh fixed seven workshop participants; tenant $tenant"
$participants = [ordered]@{
    '01' = 'mhuser1'; '02' = 'mhuser2'; '03' = 'mhuser3'; '04' = 'mhuser4'
    '05' = 'mhuser5'; '06' = 'mhuser6'; '07' = 'mhuser7'
}
if ($ResetCredentials -and ($ReadOnly -or -not $ConfirmReset)) {
    throw 'ResetCredentials requires ConfirmReset and cannot be combined with ReadOnly.'
}
if ($ConfirmReset -and -not $ResetCredentials) { throw 'ConfirmReset requires ResetCredentials.' }

# Deliberately Unix-only: explicit private directory and file permissions.
if (-not ($IsLinux -or $IsMacOS)) { throw 'Use PowerShell 7 on Linux or macOS.' }
if (-not [IO.Path]::IsPathFullyQualified($OutputFile)) { throw 'OutputFile must be an absolute private path.' }
$OutputFile = [IO.Path]::GetFullPath($OutputFile)
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$relative = [IO.Path]::GetRelativePath($workspace, $OutputFile)
if (-not $relative.StartsWith("../")) {
    if (-not $relative.StartsWith(".workshop-secrets/", [StringComparison]::Ordinal)) {
        throw 'Workspace credentials must be saved inside .workshop-secrets.'
    }
    git -C $workspace check-ignore --no-index --quiet -- .workshop-secrets/
    if ($LASTEXITCODE -ne 0) { throw 'Workspace .workshop-secrets must be Git-ignored.' }
    $tracked = @(git -C $workspace ls-files -- .workshop-secrets/)
    if ($LASTEXITCODE -ne 0 -or $tracked.Count -ne 0) {
        throw 'Cannot use workspace credentials with Git-tracked files or an unverified Git index.'
    }
}
$directory = [IO.Path]::GetDirectoryName($OutputFile)
if (-not [IO.Directory]::Exists($directory)) { throw 'Create a private output directory with mode 0700 first.' }
$ancestor = $directory
while ($ancestor) {
    if ([IO.File]::GetAttributes($ancestor) -band [IO.FileAttributes]::ReparsePoint) {
        throw 'Output path ancestors must not be symbolic links.'
    }
    $ancestor = [IO.Path]::GetDirectoryName($ancestor)
}
if ([int][IO.File]::GetUnixFileMode($directory) -band 63) { throw 'Output directory must have no group/other permissions.' }
if ([IO.File]::Exists($OutputFile) -and ([IO.File]::GetAttributes($OutputFile) -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'OutputFile must not be a symbolic link.'
}
if ($ResetCredentials -and [IO.File]::Exists($OutputFile)) {
    throw 'Credential resets require a new OutputFile; existing exports are never overwritten.'
}

$token = $null
$claims = $null
if ($ResetCredentials) {
    if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
        throw 'Install Microsoft.Graph.Authentication first: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery'
    }
    $requiredScopes = @(
        'User.Read.All', 'Group.Read.All', 'User-PasswordProfile.ReadWrite.All'
        'UserAuthenticationMethod.ReadWrite.All', 'User.RevokeSessions.All'
    )
    Connect-MgGraph -TenantId $tenant -Scopes $requiredScopes -UseDeviceCode -ContextScope Process -NoWelcome -ErrorAction Stop
    $context = Get-MgContext -ErrorAction Stop
    if ($context.TenantId -ne $tenant -or $context.AuthType -ne 'Delegated' -or $context.ContextScope -ne 'Process') {
        throw 'Reset requires a delegated Microsoft Graph session in the fixed tenant with process-only context.'
    }
    $missingScopes = @($requiredScopes | Where-Object { $_ -notin $context.Scopes })
    if ($missingScopes.Count) {
        throw "Microsoft Graph consent is missing required scopes: $($missingScopes -join ', '). No changes made."
    }
    $actor = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/me?$select=id' -OutputType PSObject -ErrorAction Stop
    $actorId = [guid]::Parse($actor.id).ToString()
} else {
    $accountTenant = (az account show --query tenantId -o tsv 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $accountTenant -ne $tenant) { throw 'Sign Azure CLI into the fixed target tenant first.' }
    $token = (az account get-access-token --tenant $tenant --resource https://graph.microsoft.com --query accessToken -o tsv 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Azure CLI could not acquire a Microsoft Graph token.' }
    try {
        $payload = $token.Split('.')[1].Replace('-', '+').Replace('_', '/')
        $payload = $payload.PadRight($payload.Length + ((4 - $payload.Length % 4) % 4), '=')
        $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
        $actorId = [guid]::Parse($claims.oid).ToString()
    } catch { throw 'Azure CLI Graph token has no usable tenant/actor claims.' }
    if ($claims.tid -ne $tenant) { throw 'Microsoft Graph token belongs to the wrong tenant.' }
    if (-not $ReadOnly -and -not $claims.scp) {
        throw 'Creation requires a delegated Azure CLI administrator session. Graph v1.0 cannot reliably verify service-principal group owners.'
    }
}

function Invoke-Graph {
    param([string]$Method, [string]$Path, [object]$Body, [switch]$AllowNotFound)
    $request = @{
        Method = $Method
        Uri = "https://graph.microsoft.com/v1.0/$Path"
        ErrorAction = 'Stop'
    }
    if (-not $ResetCredentials) { $request.Headers = @{ Authorization = "Bearer $token" } }
    if ($null -ne $Body) {
        $request.ContentType = 'application/json'
        $request.Body = $Body | ConvertTo-Json -Depth 8 -Compress
    }
    try {
        if ($ResetCredentials) { Invoke-MgGraphRequest @request -OutputType PSObject }
        else { Invoke-RestMethod @request }
    }
    catch {
        $failure = $_
        $status = 'unknown'
        if ($failure.Exception.Response) { $status = [int]$failure.Exception.Response.StatusCode }
        if ($AllowNotFound -and $status -eq 404) { return $null }
        if ($ResetCredentials) {
            throw "Microsoft Graph $Method $Path failed: HTTP $status. Inspect the Entra audit log; response bodies are withheld."
        }
        $details = $null
        try {
            $raw = $failure.ErrorDetails.Message
            if (-not $raw -and $failure.Exception.Response.Content) {
                $raw = $failure.Exception.Response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            }
            if ($raw) { $details = $raw | ConvertFrom-Json -ErrorAction Stop }
        } catch {
            # Unparseable diagnostics are not success; the original call still fails.
            $details = $null
        }
        if (-not $details -and $failure.Exception.Response.Content) {
            try {
                $details = $failure.Exception.Response.Content.ReadAsStringAsync().GetAwaiter().GetResult() |
                    ConvertFrom-Json -ErrorAction Stop
            } catch { $details = $null }
        }
        $code = $details.error.code
        $message = $details.error.message
        if ($code -isnot [string] -or $code -notmatch '^[A-Za-z0-9_.-]{1,80}$') { $code = 'unavailable' }
        if ($message -isnot [string]) { $message = 'No structured Graph error message was returned.' }
        $sensitive = @($token, $actorId, $password, $Body.passwordProfile.password,
            $claims.name, $claims.upn, $claims.email, $claims.unique_name, $claims.preferred_username)
        foreach ($value in $sensitive) {
            if ($value -is [string] -and $value.Length) {
                $code = $code.Replace($value, '[redacted]')
                $message = $message.Replace($value, '[redacted]')
            }
        }
        # Never echo structured request/claim dumps, bearer tokens, IDs, or addresses.
        $message = $message -replace '(?s)\{.*\}', '[structured details omitted]'
        $message = $message -replace '(?i)Bearer\s+[A-Za-z0-9._~+/\-=]+', 'Bearer [redacted]'
        $message = $message -replace '\beyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b', '[token redacted]'
        $code = $code -replace '(?i)\b[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\b', '[id redacted]'
        $message = $message -replace '(?i)\b[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\b', '[id redacted]'
        $message = $message -replace '(?i)\b(?!owners@odata\.bind\b|members@odata\.bind\b)[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b', '[address redacted]'
        $message = ($message -replace '[\x00-\x1f\x7f]', ' ').Trim()
        if ($message.Length -gt 1000) { $message = $message.Substring(0, 1000) + ' [truncated]' }
        throw "Microsoft Graph $Method https://graph.microsoft.com/v1.0/$Path failed: HTTP $status; error.code=$code; error.message=$message"
    }
}

# All existing-object checks happen before any directory mutation.
$filter = [Uri]::EscapeDataString("displayName eq '$groupName'")
$groups = Invoke-Graph GET "groups?`$filter=$filter&`$select=id,displayName,description,securityEnabled,mailEnabled,isAssignableToRole"
if ($groups.nextLink -or $groups.'@odata.nextLink' -or @($groups.value).Count -gt 1) {
    throw 'Ambiguous workshop group name; audit existing groups manually.'
}
$group = @($groups.value) | Select-Object -First 1
$members = @()
if ($group) {
    if ($group.description -ne $groupDescription -or -not $group.securityEnabled -or $group.mailEnabled -or $group.isAssignableToRole) {
        throw 'Existing group is not the marked, non-role-assignable workshop security group. Do not adopt it automatically.'
    }
    $owners = Invoke-Graph GET "groups/$($group.id)/owners?`$select=id"
    if ($owners.'@odata.nextLink' -or @($owners.value).Count -eq 0) { throw 'Existing group ownership cannot be verified.' }
    if (-not $ReadOnly -and $actorId -notin @($owners.value.id)) {
        throw 'The signed-in actor does not own the existing workshop group; no changes made.'
    }
    $memberResponse = Invoke-Graph GET "groups/$($group.id)/members?`$select=id"
    if ($memberResponse.'@odata.nextLink') { throw 'Unexpected paginated workshop membership; audit manually.' }
    $members = @($memberResponse.value | ForEach-Object { $_.id })
}
if (($ReadOnly -or $ResetCredentials) -and -not $group) {
    throw 'Workshop group is missing; verification and reset modes never create it.'
}

$existing = @{}
foreach ($key in $participants.Keys) {
    $upn = "$($participants[$key])@$domain"
    $encoded = [Uri]::EscapeDataString($upn)
    $user = Invoke-Graph GET "users/$encoded`?`$select=id,userPrincipalName,displayName,userType,onPremisesSyncEnabled" -AllowNotFound
    if ($user -and ($user.userPrincipalName -ne $upn -or $user.userType -ne 'Member' -or $user.onPremisesSyncEnabled)) {
        throw "Existing identity $upn is not an eligible cloud-only member; no changes made."
    }
    if (($ReadOnly -or $ResetCredentials) -and -not $user) {
        throw "Participant $upn is missing; verification and reset modes never create users."
    }
    $existing[$key] = $user
}
$allowedIds = @($existing.Values | Where-Object { $_ } | ForEach-Object { $_.id })
if ($ResetCredentials -and $actorId -in $allowedIds) {
    throw 'Use a separate organizer administrator, not one of the workshop accounts.'
}
if (@($members | Where-Object { $_ -notin $allowedIds }).Count) {
    throw 'Existing group contains unrelated members; no changes made.'
}
if (($ReadOnly -or $ResetCredentials) -and $members.Count -ne 7) {
    throw 'Verification and reset modes require all seven group memberships.'
}

$methodPaths = @{
    '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' = 'microsoftAuthenticatorMethods'
    '#microsoft.graph.phoneAuthenticationMethod' = 'phoneMethods'
    '#microsoft.graph.softwareOathAuthenticationMethod' = 'softwareOathMethods'
    '#microsoft.graph.fido2AuthenticationMethod' = 'fido2Methods'
    '#microsoft.graph.windowsHelloForBusinessAuthenticationMethod' = 'windowsHelloForBusinessMethods'
    '#microsoft.graph.emailAuthenticationMethod' = 'emailMethods'
    '#microsoft.graph.temporaryAccessPassAuthenticationMethod' = 'temporaryAccessPassMethods'
    '#microsoft.graph.platformCredentialAuthenticationMethod' = 'platformCredentialMethods'
}
$authenticationMethods = @{}
if ($ResetCredentials) {
    foreach ($key in $participants.Keys) {
        $response = Invoke-Graph GET "users/$($existing[$key].id)/authentication/methods"
        if ($response.'@odata.nextLink' -or $null -eq $response.value) {
            throw 'Cannot verify the complete authentication method inventory; no changes made.'
        }
        $authenticationMethods[$key] = @($response.value)
        foreach ($method in $authenticationMethods[$key]) {
            if ($method.'@odata.type' -ne '#microsoft.graph.passwordAuthenticationMethod' -and
                -not $methodPaths.ContainsKey($method.'@odata.type')) {
                throw 'Unsupported authentication method found; no changes made. Review it in the Entra admin center.'
            }
            if (-not [guid]::TryParse([string]$method.id, [ref]([guid]::Empty))) {
                throw 'Invalid authentication method identifier; no changes made.'
            }
        }
    }
}

# Hold an exclusive local file handle. This is a credential export, not state.
# A private parent protects a newly opened file before its mode is set to 0600.
$resetLock = $null
$stream = $null
try {
    if ($ResetCredentials) {
        $lockPath = Join-Path $directory '.identity-reset.lock'
        if ([IO.File]::Exists($lockPath) -and
            ([IO.File]::GetAttributes($lockPath) -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Reset lock must not be a symbolic link.'
        }
        $resetLock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        [IO.File]::SetUnixFileMode($lockPath, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite)
    }
    $fileMode = if ($ResetCredentials) { [IO.FileMode]::CreateNew } else { [IO.FileMode]::OpenOrCreate }
    $stream = [IO.File]::Open($OutputFile, $fileMode, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    [IO.File]::SetUnixFileMode($OutputFile, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite)
    $previous = $null
    if ($stream.Length) {
        try {
            $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8, $true, 1024, $true)
            $previous = $reader.ReadToEnd() | ConvertFrom-Json
            $reader.Dispose()
        } catch { throw 'Existing private credential file is invalid JSON; it has not been overwritten.' }
        if ($previous.tenant_id -ne $tenant -or ($previous.group_id -and $previous.group_id -ne $group.id)) {
            throw 'Private credential file belongs to another tenant/group; it has not been overwritten.'
        }
    }
    $export = [ordered]@{
        tenant_id = $tenant; group_id = $group.id
        user_object_ids = [ordered]@{}; user_principal_names = [ordered]@{}
        users = [ordered]@{}
    }
    function Save-Export {
        $bytes = [Text.Encoding]::UTF8.GetBytes(($export | ConvertTo-Json -Depth 8))
        if ($ResetCredentials) {
            $temporary = "$OutputFile.$([guid]::NewGuid()).tmp"
            $snapshot = $null
            try {
                $snapshot = [IO.File]::Open($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                [IO.File]::SetUnixFileMode($temporary, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite)
                $snapshot.Write($bytes, 0, $bytes.Length)
                $snapshot.Flush($true)
                $snapshot.Dispose()
                [IO.File]::Move($temporary, $OutputFile, $true)
            } finally {
                if ($snapshot) { $snapshot.Dispose() }
                if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
            }
            return
        }
        $stream.Position = 0
        $stream.SetLength(0)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }

    if ($ResetCredentials) {
        $stream.Dispose()
        $export.operation = 'reset-credentials'
        $export.started_at = [DateTime]::UtcNow.ToString('o')
        $export.status = 'in-progress'
        foreach ($key in $participants.Keys) {
            $user = $existing[$key]
            $export.user_object_ids[$key] = $user.id
            $export.user_principal_names[$key] = $user.userPrincipalName
            $export.users[$key] = [ordered]@{
                object_id = $user.id; username = $participants[$key]
                user_principal_name = $user.userPrincipalName; display_name = $user.displayName
                password = $null; password_status = 'not-started'
                mfa_status = 'not-started'; sessions_status = 'not-started'
            }
        }
        Save-Export
        foreach ($key in $participants.Keys) {
            $entry = $export.users[$key]
            $userPath = "users/$($entry.object_id)"
            $step = 'password_status'
            try {
                $password = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(24)) + 'aA7!'
                $entry.password = $password
                $entry.password_status = 'unconfirmed'
                Save-Export
                Invoke-Graph PATCH $userPath @{
                    passwordProfile = @{ password = $password; forceChangePasswordNextSignIn = $true }
                } | Out-Null
                $entry.password_status = 'temporary-password-set'
                Save-Export
                $step = 'mfa_status'
                $entry.mfa_status = 'in-progress'
                Save-Export
                # Alternate phone numbers must be deleted before the primary mobile number.
                $methods = $authenticationMethods[$key] | Sort-Object { if ($_.phoneType -eq 'alternateMobile') { 0 } else { 1 } }
                foreach ($method in $methods) {
                    if ($method.'@odata.type' -eq '#microsoft.graph.passwordAuthenticationMethod') { continue }
                    $collection = $methodPaths[$method.'@odata.type']
                    Invoke-Graph DELETE "$userPath/authentication/$collection/$($method.id)" | Out-Null
                }
                $remaining = Invoke-Graph GET "$userPath/authentication/methods"
                if ($null -eq $remaining.value -or $remaining.'@odata.nextLink' -or
                    @($remaining.value | Where-Object { $_.'@odata.type' -ne '#microsoft.graph.passwordAuthenticationMethod' }).Count) {
                    throw 'Authentication methods remain; MFA reset is not complete.'
                }
                $entry.mfa_status = 'methods-cleared'
                Save-Export
                $step = 'sessions_status'
                $entry.sessions_status = 'unconfirmed'
                Save-Export
                $revoked = Invoke-Graph POST "$userPath/revokeSignInSessions"
                if ($revoked.value -ne $true) { throw 'Microsoft Graph did not confirm session revocation.' }
                $entry.sessions_status = 'revoked'
                Save-Export
                Write-Host "$($entry.username): temporary password set, authentication methods cleared, Entra sessions revoked."
            } catch {
                $entry[$step] = 'failed-or-unconfirmed'
                $export.status = 'failed'
                Save-Export
                throw "Reset stopped for $($entry.username) at $step. Preserve the private export; completed operations are not rolled back. $($_.Exception.Message)"
            }
        }
        $export.status = 'completed'
        $export.completed_at = [DateTime]::UtcNow.ToString('o')
        Save-Export
        Write-Host 'Seven workshop accounts reset. Private export saved; no credentials printed.'
        return
    }

    if (-not $group) {
        $group = Invoke-Graph POST 'groups' @{
            displayName = $groupName; description = $groupDescription
            mailEnabled = $false; mailNickname = $groupName; securityEnabled = $true
            'owners@odata.bind' = @("https://graph.microsoft.com/v1.0/directoryObjects/$actorId")
        }
        $export.group_id = $group.id
        Save-Export
    }
    foreach ($key in $participants.Keys) {
        $username = $participants[$key]
        $upn = "$username@$domain"
        $user = $existing[$key]
        $entry = [ordered]@{
            object_id = $user.id; username = $username; user_principal_name = $upn
            display_name = $user.displayName; password = $null; password_status = 'unavailable-existing'
        }
        if ($user -and $previous.users.$key.object_id -eq $user.id) {
            $entry.password = $previous.users.$key.password
            $entry.password_status = $previous.users.$key.password_status
        }
        $export.users[$key] = $entry
        if (-not $user) {
            $password = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(24)) + 'aA7!'
            $entry.password = $password
            $entry.password_status = 'creation-unconfirmed'
            Save-Export
            $user = Invoke-Graph POST 'users' @{
                accountEnabled = $true; displayName = "MicroHack User $([int]$key)"
                givenName = 'MicroHack'; surname = "User $([int]$key)"
                mailNickname = $username; userPrincipalName = $upn
                passwordProfile = @{ password = $password; forceChangePasswordNextSignIn = $true }
            }
            $entry.object_id = $user.id
            $entry.display_name = $user.displayName
            $entry.password_status = 'initial-created'
        }
        $export.user_object_ids[$key] = $user.id
        $export.user_principal_names[$key] = $user.userPrincipalName
        Save-Export
        if (-not $ReadOnly -and $user.id -notin $members) {
            Invoke-Graph POST "groups/$($group.id)/members/`$ref" @{
                '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($user.id)"
            } | Out-Null
        }
        Write-Host "$username verified; existing passwords are never reset."
    }
    Write-Host 'Seven fixed participants verified. Private export saved; no credentials printed.'
} finally {
    if ($stream) { $stream.Dispose() }
    if ($resetLock) { $resetLock.Dispose() }
}

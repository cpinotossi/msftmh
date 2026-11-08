# Stateless Microsoft Graph v1.0 provisioning. The directory is authoritative.
# Passwords go only to the caller's private file, never stdout or CLI arguments.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OutputFile,
    [switch]$ReadOnly
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
$PSNativeCommandUseErrorActionPreference = $false
$tenant = '8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5'
$domain = 'mngenvmcap956455.onmicrosoft.com'
$groupName = 'mh-workshop-participants'
$groupDescription = "msftmh fixed seven workshop participants; tenant $tenant"
$participants = [ordered]@{
    '01' = 'mhuser1'; '02' = 'mhuser2'; '03' = 'mhuser3'; '04' = 'mhuser4'
    '05' = 'mhuser5'; '06' = 'mhuser6'; '07' = 'mhuser7'
}

# Deliberately Unix-only: explicit private directory and file permissions.
if (-not ($IsLinux -or $IsMacOS)) { throw 'Use PowerShell 7 on Linux or macOS.' }
if (-not [IO.Path]::IsPathFullyQualified($OutputFile)) { throw 'OutputFile must be an absolute private path.' }
$OutputFile = [IO.Path]::GetFullPath($OutputFile)
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$relative = [IO.Path]::GetRelativePath($workspace, $OutputFile)
if (-not $relative.StartsWith("../")) { throw 'Credentials must be saved outside the workspace.' }
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

function Invoke-Graph {
    param([string]$Method, [string]$Path, [object]$Body, [switch]$AllowNotFound)
    $request = @{
        Method = $Method
        Uri = "https://graph.microsoft.com/v1.0/$Path"
        Headers = @{ Authorization = "Bearer $token" }
        ErrorAction = 'Stop'
    }
    if ($null -ne $Body) {
        $request.ContentType = 'application/json'
        $request.Body = $Body | ConvertTo-Json -Depth 8 -Compress
    }
    try { Invoke-RestMethod @request }
    catch {
        $failure = $_
        $status = 'unknown'
        if ($failure.Exception.Response) { $status = [int]$failure.Exception.Response.StatusCode }
        if ($AllowNotFound -and $status -eq 404) { return $null }
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
if ($ReadOnly -and -not $group) { throw 'Workshop group is missing; read-only mode never creates it.' }

$existing = @{}
foreach ($key in $participants.Keys) {
    $upn = "$($participants[$key])@$domain"
    $encoded = [Uri]::EscapeDataString($upn)
    $user = Invoke-Graph GET "users/$encoded`?`$select=id,userPrincipalName,displayName,userType,onPremisesSyncEnabled" -AllowNotFound
    if ($user -and ($user.userPrincipalName -ne $upn -or $user.userType -ne 'Member' -or $user.onPremisesSyncEnabled)) {
        throw "Existing identity $upn is not an eligible cloud-only member; no changes made."
    }
    if ($ReadOnly -and -not $user) { throw "Participant $upn is missing; read-only mode never creates users." }
    $existing[$key] = $user
}
$allowedIds = @($existing.Values | Where-Object { $_ } | ForEach-Object { $_.id })
if (@($members | Where-Object { $_ -notin $allowedIds }).Count) {
    throw 'Existing group contains unrelated members; no changes made.'
}
if ($ReadOnly -and $members.Count -ne 7) { throw 'Read-only verification requires all seven group memberships.' }

# Hold an exclusive local file handle. This is a credential export, not state.
# A private parent protects a newly opened file before its mode is set to 0600.
$stream = [IO.File]::Open($OutputFile, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
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
        $stream.Position = 0
        $stream.SetLength(0)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
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
} finally { $stream.Dispose() }

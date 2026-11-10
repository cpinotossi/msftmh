# Offline only: no Azure login or Microsoft Graph request leaves this process.
$ErrorActionPreference = 'Stop'
$global:ResetTenant = '8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5'
$global:ResetActor = [guid]::NewGuid().ToString()
$global:ResetToken = 'offline-sdk-token-never-exposed'
$global:ResetScopes = @(
    'User.Read.All', 'Group.Read.All', 'User-PasswordProfile.ReadWrite.All'
    'UserAuthenticationMethod.ReadWrite.All', 'User.RevokeSessions.All'
)
$global:ResetContext = @{
    TenantId = $global:ResetTenant; AuthType = 'Delegated'
    ContextScope = 'Process'; Scopes = $global:ResetScopes
}
$global:ResetUsers = @{}
$global:ResetMethods = @{}
$global:ResetWrites = [Collections.Generic.List[string]]::new()
$global:ResetFail = ''
$global:ResetUnconfirmed = $false
$global:ResetOutput = ''
$global:ResetCandidate = ''
$global:ResetGroup = [guid]::NewGuid().ToString()
foreach ($number in 1..7) {
    $id = [guid]::NewGuid().ToString()
    $global:ResetUsers["mhuser$number@cptdemo.org"] = @{
        id = $id; userPrincipalName = "mhuser$number@cptdemo.org"
        displayName = "MicroHack User $number"; userType = 'Member'; onPremisesSyncEnabled = $false
    }
}
function Initialize-Methods {
    foreach ($user in $global:ResetUsers.Values) {
        $global:ResetMethods[$user.id] = @(
            @{ id = [guid]::NewGuid().ToString(); '@odata.type' = '#microsoft.graph.passwordAuthenticationMethod' }
            @{ id = [guid]::NewGuid().ToString(); '@odata.type' = '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' }
            @{ id = [guid]::NewGuid().ToString(); '@odata.type' = '#microsoft.graph.fido2AuthenticationMethod' }
            @{ id = [guid]::NewGuid().ToString(); '@odata.type' = '#microsoft.graph.softwareOathAuthenticationMethod' }
            @{ id = [guid]::NewGuid().ToString(); '@odata.type' = '#microsoft.graph.windowsHelloForBusinessAuthenticationMethod' }
            @{ id = [guid]::NewGuid().ToString(); '@odata.type' = '#microsoft.graph.emailAuthenticationMethod' }
            @{ id = [guid]::NewGuid().ToString(); '@odata.type' = '#microsoft.graph.temporaryAccessPassAuthenticationMethod' }
            @{ id = [guid]::NewGuid().ToString(); '@odata.type' = '#microsoft.graph.platformCredentialAuthenticationMethod' }
            @{ id = [guid]::NewGuid().ToString(); '@odata.type' = '#microsoft.graph.phoneAuthenticationMethod'; phoneType = 'mobile' }
            @{ id = [guid]::NewGuid().ToString(); '@odata.type' = '#microsoft.graph.phoneAuthenticationMethod'; phoneType = 'alternateMobile' }
        )
    }
}
function az {
    throw 'Reset must not use Azure CLI authentication.'
}
function Invoke-RestMethod {
    throw 'Reset must use the authenticated Microsoft Graph SDK request.'
}
function Connect-MgGraph {
    param($TenantId, $Scopes, $ContextScope, [switch]$UseDeviceCode, [switch]$NoWelcome, $ErrorAction)
    if ($TenantId -ne $global:ResetTenant -or $ContextScope -ne 'Process' -or
        -not $UseDeviceCode -or -not $NoWelcome -or
        @(Compare-Object $Scopes $global:ResetScopes).Count) {
        throw 'Reset login must request explicit scopes, device login, and process-only context.'
    }
    'OFFLINE: device-code instructions must remain visible'
}
function Get-MgContext { return $global:ResetContext }
function Invoke-MgGraphRequest {
    param($Method, $Uri, $ContentType, $Body, $OutputType, $ErrorAction)
    if ($OutputType -ne 'PSObject') { throw 'Graph requests must return PSObject results.' }
    $path = $Uri.Split('/v1.0/')[1]
    if ($Method -eq 'GET') {
        if ($path -eq 'me?$select=id') { return @{ id = $global:ResetActor } }
        if ($path.StartsWith('groups?')) {
            return @{ value = @(@{
                id = $global:ResetGroup; displayName = 'mh-workshop-participants'
                description = "msftmh fixed seven workshop participants; tenant $global:ResetTenant"
                securityEnabled = $true; mailEnabled = $false; isAssignableToRole = $false
            }) }
        }
        if ($path.Contains('/owners?')) { return @{ value = @(@{ id = $global:ResetActor }) } }
        if ($path.Contains('/members?')) {
            return @{ value = @($global:ResetUsers.Values | ForEach-Object { @{ id = $_.id } }) }
        }
        if ($path.EndsWith('/authentication/methods')) {
            return @{ value = @($global:ResetMethods[$path.Split('/')[1]]) }
        }
        if ($path.StartsWith('users/')) {
            return $global:ResetUsers[[Uri]::UnescapeDataString($path.Split('?')[0].Substring(6))]
        }
        throw "Unexpected GET $path."
    }
    $id = $path.Split('/')[1]
    $user = @($global:ResetUsers.Values | Where-Object { $_.id -eq $id })[0]
    if (-not $user) { throw 'Mutation targeted an unrelated user.' }
    $key = '{0:d2}' -f [int]($user.userPrincipalName -replace '^mhuser(\d+)@.*$', '$1')
    $saved = [IO.File]::ReadAllText($global:ResetOutput) | ConvertFrom-Json
    if ($Method -eq 'PATCH') {
        $data = $Body | ConvertFrom-Json
        $global:ResetCandidate = $data.passwordProfile.password
        if (-not $data.passwordProfile.forceChangePasswordNextSignIn -or
            $global:ResetCandidate.Length -lt 24 -or
            $saved.users.$key.password -ne $global:ResetCandidate -or
            $saved.users.$key.password_status -ne 'unconfirmed') {
            throw 'Temporary password must be strong, force a change, and be saved before the request.'
        }
    }
    if ($Method -eq $global:ResetFail) {
        throw "Mock HTTP failure containing $global:ResetCandidate and $global:ResetToken"
    }
    $global:ResetWrites.Add("$Method $path")
    if ($Method -eq 'PATCH') { return }
    if ($Method -eq 'DELETE') {
        $methodId = $path.Split('/')[-1]
        $method = @($global:ResetMethods[$id] | Where-Object { $_.id -eq $methodId })[0]
        if ($method.'@odata.type' -eq '#microsoft.graph.passwordAuthenticationMethod') { throw 'Password method must not be deleted.' }
        $collection = switch ($method.'@odata.type') {
            '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' { 'microsoftAuthenticatorMethods' }
            '#microsoft.graph.phoneAuthenticationMethod' { 'phoneMethods' }
            '#microsoft.graph.softwareOathAuthenticationMethod' { 'softwareOathMethods' }
            '#microsoft.graph.fido2AuthenticationMethod' { 'fido2Methods' }
            '#microsoft.graph.windowsHelloForBusinessAuthenticationMethod' { 'windowsHelloForBusinessMethods' }
            '#microsoft.graph.emailAuthenticationMethod' { 'emailMethods' }
            '#microsoft.graph.temporaryAccessPassAuthenticationMethod' { 'temporaryAccessPassMethods' }
            '#microsoft.graph.platformCredentialAuthenticationMethod' { 'platformCredentialMethods' }
        }
        if ($path.Split('/')[-2] -ne $collection) { throw 'Incorrect authentication method endpoint.' }
        if ($method.phoneType -eq 'mobile' -and @($global:ResetMethods[$id] | Where-Object { $_.phoneType -eq 'alternateMobile' }).Count) {
            throw 'Alternate mobile must be deleted first.'
        }
        $global:ResetMethods[$id] = @($global:ResetMethods[$id] | Where-Object { $_.id -ne $methodId })
        return
    }
    if ($Method -eq 'POST' -and $path.EndsWith('/revokeSignInSessions')) {
        if ($Body) { throw 'Session revocation must not send a request body.' }
        return @{ value = (-not $global:ResetUnconfirmed) }
    }
    throw "Unexpected mutation $Method $path."
}
function Assert-Rejected {
    param([scriptblock]$Operation, [string]$Pattern)
    $count = $global:ResetWrites.Count
    $rejected = $false
    try { & $Operation | Out-Null }
    catch { $rejected = $_.Exception.Message -match $Pattern }
    if (-not $rejected -or $global:ResetWrites.Count -ne $count) {
        throw "Expected rejection before mutations: $Pattern"
    }
}
$target = Join-Path $PSScriptRoot '../provision.ps1'
$directory = Join-Path ([IO.Path]::GetTempPath()) "msftmh-reset-test-$([guid]::NewGuid())"
[IO.Directory]::CreateDirectory($directory) | Out-Null
[IO.File]::SetUnixFileMode($directory, [IO.UnixFileMode]448)
try {
    Initialize-Methods
    $global:ResetOutput = Join-Path $directory 'completed.json'
    Assert-Rejected { & $target -ResetCredentials -OutputFile $global:ResetOutput } 'ConfirmReset'
    Assert-Rejected { & $target -ResetCredentials -ConfirmReset -ReadOnly -OutputFile $global:ResetOutput } 'ReadOnly'
    Assert-Rejected { & $target -ConfirmReset -OutputFile $global:ResetOutput } 'requires ResetCredentials'
    $global:ResetContext.AuthType = 'AppOnly'
    Assert-Rejected { & $target -ResetCredentials -ConfirmReset -OutputFile $global:ResetOutput } 'delegated Microsoft Graph'
    $global:ResetContext.AuthType = 'Delegated'
    $global:ResetContext.TenantId = [guid]::NewGuid().ToString()
    Assert-Rejected { & $target -ResetCredentials -ConfirmReset -OutputFile $global:ResetOutput } 'fixed tenant'
    $global:ResetContext.TenantId = $global:ResetTenant
    $global:ResetContext.ContextScope = 'CurrentUser'
    Assert-Rejected { & $target -ResetCredentials -ConfirmReset -OutputFile $global:ResetOutput } 'process-only'
    $global:ResetContext.ContextScope = 'Process'
    $global:ResetContext.Scopes = @('User.Read.All', 'Group.Read.All')
    Assert-Rejected { & $target -ResetCredentials -ConfirmReset -OutputFile $global:ResetOutput } 'missing required scopes'
    $global:ResetContext.Scopes = $global:ResetScopes
    $seventh = $global:ResetUsers['mhuser7@cptdemo.org']
    $global:ResetUsers.Remove('mhuser7@cptdemo.org')
    Assert-Rejected { & $target -ResetCredentials -ConfirmReset -OutputFile $global:ResetOutput } 'missing'
    $global:ResetUsers['mhuser7@cptdemo.org'] = $seventh
    $global:ResetMethods[$seventh.id] += @{ id = [guid]::NewGuid().ToString(); '@odata.type' = '#microsoft.graph.unknownMethod' }
    Assert-Rejected { & $target -ResetCredentials -ConfirmReset -OutputFile $global:ResetOutput } 'Unsupported authentication'
    Initialize-Methods
    $messages = @(& $target -ResetCredentials -ConfirmReset -OutputFile $global:ResetOutput 6>&1) | Out-String
    $completed = [IO.File]::ReadAllText($global:ResetOutput) | ConvertFrom-Json
    if (-not $messages.Contains('OFFLINE: device-code instructions must remain visible')) {
        throw 'The login instructions were suppressed.'
    }
    if ($completed.status -ne 'completed' -or @($completed.users.PSObject.Properties).Count -ne 7 -or
        $global:ResetWrites.Count -ne 77) { throw 'Expected seven complete password/method/session resets.' }
    foreach ($user in $completed.users.PSObject.Properties.Value) {
        if ($user.password_status -ne 'temporary-password-set' -or $user.mfa_status -ne 'methods-cleared' -or
            $user.sessions_status -ne 'revoked' -or $messages.Contains($user.password)) {
            throw 'Success statuses are incomplete or a password leaked.'
        }
    }
    if ([int][IO.File]::GetUnixFileMode($global:ResetOutput) -ne 384) { throw 'Export is not mode 0600.' }
    $originalExport = [IO.File]::ReadAllText($global:ResetOutput)
    Assert-Rejected { & $target -ResetCredentials -ConfirmReset -OutputFile $global:ResetOutput } 'new OutputFile'
    if ([IO.File]::ReadAllText($global:ResetOutput) -ne $originalExport) { throw 'Existing export changed.' }
    $held = [IO.File]::Open((Join-Path $directory '.identity-reset.lock'), 'Open', 'ReadWrite', 'None')
    try {
        Assert-Rejected { & $target -ResetCredentials -ConfirmReset -OutputFile (Join-Path $directory 'locked.json') } 'being used by another process'
    } finally { $held.Dispose() }
    foreach ($failure in @('PATCH', 'DELETE', 'POST', 'unconfirmed')) {
        Initialize-Methods
        $global:ResetOutput = Join-Path $directory "$failure.json"
        $global:ResetFail = $failure
        $global:ResetUnconfirmed = $failure -eq 'unconfirmed'
        $errorText = ''
        try { & $target -ResetCredentials -ConfirmReset -OutputFile $global:ResetOutput | Out-Null }
        catch { $errorText = $_.Exception.Message }
        $failed = [IO.File]::ReadAllText($global:ResetOutput) | ConvertFrom-Json
        $first = $failed.users.'01'
        $step = switch ($failure) { 'PATCH' { 'password_status' }; 'DELETE' { 'mfa_status' }; default { 'sessions_status' } }
        if ($failed.status -ne 'failed' -or $first.$step -ne 'failed-or-unconfirmed' -or
            $failed.users.'02'.password_status -ne 'not-started' -or -not $first.password -or
            -not $errorText.Contains('Reset stopped') -or $errorText.Contains($first.password) -or
            $errorText.Contains($global:ResetToken)) { throw "Unsafe partial failure handling: $failure" }
        if ($failure -ne 'PATCH' -and $first.password_status -ne 'temporary-password-set') {
            throw 'A completed password reset lost its status.'
        }
    }
    if (@([IO.Directory]::GetFiles($directory, '*.tmp')).Count) { throw 'Temporary snapshots were not cleaned up.' }
    'PASS: seven fixed accounts, forced password change, MFA/passkey removal, phone order, session revocation, private durable export'
    'PASS: SDK-only device login with explicit scopes; wrong tenant, app-only, persistent context and missing consent rejected'
    'PASS: confirmation, read-only/missing-user/unknown-method/concurrency guards, no overwrite, partial failure and secret redaction'
} finally {
    [IO.Directory]::Delete($directory, $true)
}

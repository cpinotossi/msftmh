# Offline only: Azure CLI and every HTTP request are mocked.
$ErrorActionPreference = 'Stop'
$global:IdentityTestTenant = '8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5'
$global:IdentityTestActor = [guid]::NewGuid().ToString()
$claims = @{tid=$global:IdentityTestTenant; oid=$global:IdentityTestActor; scp='offline-mock-delegated'} | ConvertTo-Json -Compress
$payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($claims)).TrimEnd('=').Replace('+','-').Replace('/','_')
$global:IdentityTestToken = "e30.$payload.e30"
$global:IdentityTestUsers = @{}
$global:IdentityTestGroup = $null
$global:IdentityTestMembers = [Collections.Generic.List[string]]::new()
$global:IdentityTestOwner = $global:IdentityTestActor
$global:IdentityTestWrites = 0
$global:IdentityTestFailPath = $null
$global:IdentityTestDiagnosticPassword = $null

function az {
    $global:LASTEXITCODE = 0
    if ($args[1] -eq 'show') { return $global:IdentityTestTenant }
    return $global:IdentityTestToken
}
function Invoke-RestMethod {
    param($Method, $Uri, $Headers, $ContentType, $Body, $ErrorAction)
    $path = $Uri.Split('/v1.0/')[1]
    if ($Method -eq 'GET' -and $path.StartsWith('groups?')) {
        $values = @()
        if ($global:IdentityTestGroup) { $values = @($global:IdentityTestGroup) }
        return @{value=$values}
    }
    if ($Method -eq 'GET' -and $path.Contains('/owners?')) {
        return @{value=@(@{id=$global:IdentityTestOwner})}
    }
    if ($Method -eq 'GET' -and $path.Contains('/members?')) {
        return @{value=@($global:IdentityTestMembers | ForEach-Object { @{id=$_} })}
    }
    if ($Method -eq 'GET' -and $path.StartsWith('users/')) {
        $upn = [Uri]::UnescapeDataString($path.Split('?')[0].Substring(6))
        return $global:IdentityTestUsers[$upn]
    }
    if ($Method -ne 'POST') { throw 'Unexpected request in offline test.' }
    if ($path -eq $global:IdentityTestFailPath) {
        $data = $Body | ConvertFrom-Json
        $global:IdentityTestDiagnosticPassword = $data.passwordProfile.password
        $response = [Net.Http.HttpResponseMessage]::new([Net.HttpStatusCode]::BadRequest)
        $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new('offline HTTP error', $response)
        $record = [Management.Automation.ErrorRecord]::new($exception, 'offlineGraphFailure', [Management.Automation.ErrorCategory]::InvalidOperation, $null)
        $diagnostic = @{
            error = @{
                code = 'Request_BadRequest'
                message = "Operation denied; Group.ReadWrite.All required; owners@odata.bind invalid; password=$($data.passwordProfile.password); token=$global:IdentityTestToken; actor=$global:IdentityTestActor; raw=$Body"
                innerError = @{token=$global:IdentityTestToken; actor=$global:IdentityTestActor}
            }
        } | ConvertTo-Json -Depth 8
        $record.ErrorDetails = [Management.Automation.ErrorDetails]::new($diagnostic)
        throw $record
    }
    $global:IdentityTestWrites++
    $data = $Body | ConvertFrom-Json
    if ($path -eq 'groups') {
        if ($global:IdentityTestGroup) { throw 'Duplicate group creation.' }
        $global:IdentityTestGroup = @{
            id=[guid]::NewGuid().ToString(); description=$data.description
            displayName=$data.displayName; securityEnabled=$data.securityEnabled
            mailEnabled=$data.mailEnabled; isAssignableToRole=$false
        }
        return $global:IdentityTestGroup
    }
    if ($path -eq 'users') {
        if ($global:IdentityTestUsers.ContainsKey($data.userPrincipalName)) { throw 'Duplicate user creation.' }
        $number = $data.mailNickname -replace '^mhuser', ''
        if ($data.userPrincipalName -ne "mhuser$number@cptdemo.org" -or
            $data.givenName -ne 'MicroHack' -or $data.surname -ne "User $number") {
            throw 'Workshop users must use cptdemo.org and have SCIM-compatible names.'
        }
        $password = $data.passwordProfile.password
        if ($password.Length -lt 24 -or $password -cnotmatch '[A-Z]' -or
            $password -cnotmatch '[a-z]' -or $password -notmatch '\d' -or
            $password -notmatch '[^A-Za-z0-9]' -or -not $data.passwordProfile.forceChangePasswordNextSignIn) {
            throw 'Password strength or forced-change requirement failed.'
        }
        $user = @{
            id=[guid]::NewGuid().ToString(); userPrincipalName=$data.userPrincipalName
            displayName=$data.displayName; userType='Member'; onPremisesSyncEnabled=$false
        }
        $global:IdentityTestUsers[$data.userPrincipalName] = $user
        return $user
    }
    if ($path.Contains('/members/$ref')) {
        $global:IdentityTestMembers.Add($data.'@odata.id'.Split('/')[-1])
        return
    }
    throw 'Unexpected POST path.'
}

$directory = Join-Path ([IO.Path]::GetTempPath()) "msftmh-identity-test-$([guid]::NewGuid())"
[IO.Directory]::CreateDirectory($directory) | Out-Null
[IO.File]::SetUnixFileMode($directory, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute)
$target = Join-Path $PSScriptRoot '../provision.ps1'
$output = Join-Path $directory 'user_credentials.json'
try {
    $messages = @(& $target -OutputFile $output 6>&1)
    $first = [IO.File]::ReadAllText($output) | ConvertFrom-Json
    if ($global:IdentityTestWrites -ne 15 -or $global:IdentityTestUsers.Count -ne 7 -or $global:IdentityTestMembers.Count -ne 7) {
        throw 'First run must create one group, seven users, and seven memberships.'
    }
    foreach ($user in $first.users.PSObject.Properties.Value) {
        if (($messages | Out-String).Contains($user.password)) { throw 'Password leaked into output.' }
    }
    if ([int][IO.File]::GetUnixFileMode($output) -ne 384) { throw 'Credential file must have mode 0600.' }
    & $target -OutputFile $output | Out-Null
    $second = [IO.File]::ReadAllText($output) | ConvertFrom-Json
    if ($global:IdentityTestWrites -ne 15) { throw 'Rerun must perform no writes or resets.' }
    foreach ($key in $first.users.PSObject.Properties.Name) {
        if ($first.users.$key.password -ne $second.users.$key.password) { throw 'Existing password export was not preserved.' }
    }
    $testWorkspace = Join-Path $directory 'workspace'
    $testScripts = Join-Path $testWorkspace 'infra/identity'
    $testSecrets = Join-Path $testWorkspace '.workshop-secrets'
    [IO.Directory]::CreateDirectory($testScripts) | Out-Null
    [IO.Directory]::CreateDirectory($testSecrets) | Out-Null
    [IO.File]::SetUnixFileMode($testSecrets, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute)
    git init --quiet $testWorkspace
    if ($LASTEXITCODE -ne 0) { throw 'Cannot initialize offline Git fixture.' }
    $testTarget = Join-Path $testScripts 'provision.ps1'
    [IO.File]::Copy($target, $testTarget)
    $ignoreFile = Join-Path $testWorkspace '.gitignore'
    [IO.File]::WriteAllText($ignoreFile, ".workshop-secrets/`n")
    $testOutput = Join-Path $testSecrets 'user_credentials.json'
    & $testTarget -ReadOnly -OutputFile $testOutput | Out-Null
    if (-not [IO.File]::Exists($testOutput) -or $global:IdentityTestWrites -ne 15) {
        throw 'Ignored workspace credentials were not accepted read-only.'
    }
    [IO.File]::WriteAllText($ignoreFile, '')
    $rejected = $false
    try { & $testTarget -ReadOnly -OutputFile $testOutput | Out-Null }
    catch { $rejected = $_.Exception.Message -match 'Git-ignored' }
    if (-not $rejected) { throw 'Unignored workspace credentials were accepted.' }
    [IO.File]::WriteAllText($ignoreFile, ".workshop-secrets/`n")
    git -C $testWorkspace add -f -- $testOutput
    if ($LASTEXITCODE -ne 0) { throw 'Cannot stage offline credential fixture.' }
    $rejected = $false
    try { & $testTarget -ReadOnly -OutputFile $testOutput | Out-Null }
    catch { $rejected = $_.Exception.Message -match 'Git-tracked' }
    if (-not $rejected) { throw 'Git-tracked workspace credentials were accepted.' }
    $delegatedToken = $global:IdentityTestToken
    $appClaims = @{tid=$global:IdentityTestTenant; oid=$global:IdentityTestActor} | ConvertTo-Json -Compress
    $appPayload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($appClaims)).TrimEnd('=').Replace('+','-').Replace('/','_')
    $global:IdentityTestToken = "e30.$appPayload.e30"
    $rejected = $false
    try { & $target -OutputFile $output | Out-Null }
    catch { $rejected = $_.Exception.Message -match 'delegated Azure CLI' }
    if (-not $rejected -or $global:IdentityTestWrites -ne 15) { throw 'App-only creation must fail before writes.' }
    & $target -ReadOnly -OutputFile (Join-Path $directory 'app-read-only.json') | Out-Null
    if ($global:IdentityTestWrites -ne 15) { throw 'App-only read-only verification performed a mutation.' }
    $global:IdentityTestToken = $delegatedToken
    $originalDescription = $global:IdentityTestGroup.description
    $global:IdentityTestGroup.description = 'unmarked unrelated group'
    $rejected = $false
    try { & $target -OutputFile $output | Out-Null }
    catch { $rejected = $_.Exception.Message -match 'not the marked' }
    if (-not $rejected -or $global:IdentityTestWrites -ne 15) { throw 'Unmarked group must abort before writes.' }
    $global:IdentityTestGroup.description = $originalDescription
    $global:IdentityTestOwner = [guid]::NewGuid().ToString()
    $rejected = $false
    try { & $target -OutputFile $output | Out-Null }
    catch { $rejected = $_.Exception.Message -match 'does not own' }
    if (-not $rejected -or $global:IdentityTestWrites -ne 15) { throw 'Unowned group must abort before writes.' }
    & $target -ReadOnly -OutputFile (Join-Path $directory 'identities.json') | Out-Null
    if ($global:IdentityTestWrites -ne 15) { throw 'Read-only mode performed a mutation.' }
    $global:IdentityTestUsers.Remove('mhuser7@cptdemo.org')
    $rejected = $false
    try { & $target -ReadOnly -OutputFile (Join-Path $directory 'incomplete.json') | Out-Null }
    catch { $rejected = $_.Exception.Message -match 'missing' }
    if (-not $rejected -or $global:IdentityTestWrites -ne 15) { throw 'Read-only mode must reject a missing participant without creating it.' }
    $rejected = $false
    try { & $target -OutputFile (Join-Path $PSScriptRoot 'forbidden.json') | Out-Null }
    catch { $rejected = $_.Exception.Message -match 'inside .workshop-secrets' }
    if (-not $rejected -or [IO.File]::Exists((Join-Path $PSScriptRoot 'forbidden.json'))) { throw 'Workspace credential path was not rejected.' }
    $global:IdentityTestGroup = $null
    $global:IdentityTestUsers = @{}
    $global:IdentityTestMembers.Clear()
    $global:IdentityTestOwner = $global:IdentityTestActor
    $global:IdentityTestFailPath = 'users'
    $failureMessage = $null
    try { & $target -OutputFile (Join-Path $directory 'diagnostic.json') | Out-Null }
    catch {
        $failureMessage = $_.Exception.Message
        $failureOutput = @($_.ToString(), $_.ErrorDetails.Message, $_.Exception.Message) -join "`n"
    }
    if (-not $failureMessage -or $failureMessage -notmatch 'POST https://graph.microsoft.com/v1.0/users' -or
        $failureMessage -notmatch 'HTTP 400' -or $failureMessage -notmatch 'error.code=Request_BadRequest' -or
        $failureMessage -notmatch 'Group.ReadWrite.All required' -or $failureMessage -notmatch 'owners@odata.bind invalid') {
        throw 'Failure diagnostic lost its exact operation, HTTP status, code, or useful permission message.'
    }
    foreach ($secret in @($global:IdentityTestDiagnosticPassword, $global:IdentityTestToken, $global:IdentityTestActor)) {
        if ($failureOutput.Contains($secret)) { throw 'Secret or actor identity leaked through a Graph diagnostic.' }
    }
    if ($failureMessage.Contains('passwordProfile') -or $failureMessage.Contains('innerError')) {
        throw 'Request body or unselected response details leaked through a Graph diagnostic.'
    }
    if ($global:IdentityTestUsers.Count -ne 0) { throw 'Graph failure was incorrectly treated as success.' }
    'PASS: fixed seven, strong passwords, forced change, no secret logs, mode 0600, idempotency, delegated-only creation, ownership, app read-only and missing-user guards'
    'PASS: exact Graph operation, HTTP/code/message diagnostics, secret/actor/body redaction, no success fallback'
} finally {
    [IO.Directory]::Delete($directory, $true)
}

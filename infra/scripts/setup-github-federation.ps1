[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param([switch]$EnableParticipantEnvironments)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$tenant = '8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5'
$workshop = 'aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483'
$oracle = '4ce5b5cc-e869-451f-98fc-f50448849ee0'
$template = Join-Path $PSScriptRoot '../deployments/00-github-identity.bicep'

function Invoke-AzJson {
    param([string[]]$Arguments)
    $response = & az @Arguments --output json
    if ($LASTEXITCODE -ne 0) { throw "Azure CLI command failed: $($Arguments[0])" }
    ($response -join "`n") | ConvertFrom-Json
}

foreach ($subscription in @($workshop, $oracle)) {
    $account = Invoke-AzJson @('account', 'show', '--subscription', $subscription)
    if ($account.tenantId -ne $tenant) { throw 'Both subscriptions must belong to the fixed new tenant.' }
}

if ($EnableParticipantEnvironments) {
    foreach ($name in 1..7 | ForEach-Object { "mhuser$_" }) {
        $endpoint = "repos/cpinotossi/msftmh/environments/$name"
        $raw = & gh api $endpoint
        if ($LASTEXITCODE -ne 0) { throw "Cannot verify GitHub environment $name; no environment trust enabled." }
        $environment = ($raw -join "`n") | ConvertFrom-Json
        if (-not $environment.deployment_branch_policy.custom_branch_policies -or $environment.deployment_branch_policy.protected_branches) {
            throw "GitHub environment $name must use a custom main-only branch policy."
        }
        $raw = & gh api "$endpoint/deployment-branch-policies"
        if ($LASTEXITCODE -ne 0) { throw "Cannot verify branch policies for $name." }
        $policies = ($raw -join "`n") | ConvertFrom-Json
        if ($policies.total_count -ne 1 -or $policies.branch_policies[0].name -ne 'main' -or $policies.branch_policies[0].type -ne 'branch') {
            throw "GitHub environment $name must allow only branch main, with no tag or wildcard policies."
        }
    }
}

if ($WhatIfPreference) {
    & az deployment sub what-if --subscription $workshop --location francecentral `
        --name workshop-00-github-identity --template-file $template `
        --parameters "participantEnvironmentsReady=$($EnableParticipantEnvironments.IsPresent.ToString().ToLowerInvariant())"
    if ($LASTEXITCODE -ne 0) { throw 'CI identity what-if failed.' }
    return
}
if (-not $PSCmdlet.ShouldProcess($tenant, 'Configure CI identity, verified GitHub trusts, subscription Contributor/UAA and two read-only Graph grants')) {
    throw 'CI identity bootstrap was not authorized.'
}

$deployment = Invoke-AzJson @(
    'deployment', 'sub', 'create', '--subscription', $workshop,
    '--location', 'francecentral', '--name', 'workshop-00-github-identity',
    '--template-file', $template, '--parameters',
    "participantEnvironmentsReady=$($EnableParticipantEnvironments.IsPresent.ToString().ToLowerInvariant())"
)
if ($deployment.properties.provisioningState -ne 'Succeeded') { throw 'CI identity deployment is not Succeeded.' }
if (-not $EnableParticipantEnvironments) {
    $credentials = @(Invoke-AzJson @(
        'identity', 'federated-credential', 'list', '--subscription', $workshop,
        '--resource-group', 'rg-workshop-ci', '--identity-name', 'id-workshop-github'
    ))
    foreach ($name in 1..7 | ForEach-Object { "mhuser$_" }) {
        $credential = @($credentials | Where-Object { $_.name -eq "github-$name" })
        if ($credential.Count) {
            if ($credential.Count -ne 1 -or $credential[0].subject -ne "repo:cpinotossi/msftmh:environment:$name") {
                throw "Unexpected credential for $name; review manually."
            }
            & az identity federated-credential delete --subscription $workshop `
                --resource-group rg-workshop-ci --identity-name id-workshop-github --name "github-$name" --yes
            if ($LASTEXITCODE -ne 0) { throw "Failed to revoke unverified environment trust for $name." }
        }
    }
}
$principal = $deployment.properties.outputs.principalId.value
if ($deployment.properties.outputs.tenantId.value -ne $tenant) { throw 'CI identity has the wrong tenant.' }
$graph = Invoke-AzJson @('ad', 'sp', 'show', '--id', '00000003-0000-0000-c000-000000000000')
$url = "https://graph.microsoft.com/v1.0/servicePrincipals/$principal/appRoleAssignments"
$grants = Invoke-AzJson @('rest', '--method', 'GET', '--url', $url)
if ($grants.'@odata.nextLink') { throw 'Unexpected paginated CI grants; review manually.' }
foreach ($permission in @('User.Read.All', 'Group.Read.All')) {
    $roles = @($graph.appRoles | Where-Object { $_.value -eq $permission -and 'Application' -in $_.allowedMemberTypes })
    if ($roles.Count -ne 1 -or -not $roles[0].isEnabled) { throw "Graph permission metadata invalid: $permission" }
    $role = $roles[0].id
    if (-not @($grants.value | Where-Object { $_.resourceId -eq $graph.id -and $_.appRoleId -eq $role }).Count) {
        $body = @{ principalId = $principal; resourceId = $graph.id; appRoleId = $role } | ConvertTo-Json -Compress
        Invoke-AzJson @('rest', '--method', 'POST', '--url', $url, '--body', $body) | Out-Null
    }
}
$verified = Invoke-AzJson @('rest', '--method', 'GET', '--url', $url)
$expected = @($graph.appRoles | Where-Object { $_.value -in @('User.Read.All', 'Group.Read.All') } | ForEach-Object id)
$actual = @($verified.value | Where-Object { $_.resourceId -eq $graph.id } | ForEach-Object appRoleId)
if ($verified.'@odata.nextLink' -or $actual.Count -ne 2 -or @($expected | Where-Object { $_ -notin $actual }).Count) {
    throw 'CI Graph grants do not match the two approved read-only permissions.'
}
Write-Host "CI identity and read-only Graph grants verified. Set repository AZURE_CLIENT_ID=$($deployment.properties.outputs.clientId.value)"

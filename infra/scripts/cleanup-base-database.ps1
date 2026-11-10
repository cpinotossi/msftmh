<#
.SYNOPSIS
Delete explicitly owned Oracle Base Database@Azure DB systems.
.DESCRIPTION
Requires Azure CLI login and a full repository checkout (tests/base_database.py).
Only DB systems in rg-odaa-shared in the fixed ODAA subscription tagged workshop=odaa
and managed-by=workshop-base-db are eligible.
DB systems are deleted and verified absent. No network anchors are enumerated or deleted.
Shared/in-use/unowned anchors, resource anchors, VNets, subnets, legacy Autonomous
Databases and all OCI networking are untouched. API errors stop cleanup.
This script does not tear down infrastructure, rotate credentials or remove the
fixed seven VMs. Those are separate organizer operations.
.PARAMETER SubscriptionId
Explicit Azure subscription ID; never inferred from an interactive account.
.PARAMETER Owner
Optional automation-owner tag constraint, e.g. a specific GitHub run ID/attempt.
.EXAMPLE
./cleanup-base-database.ps1 -SubscriptionId '<subscription>' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,
    [Parameter()]
    [string]$Owner
)

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot '../../tests/base_database.py'
if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
    throw 'Full repository checkout required: tests/base_database.py is missing.'
}
$arguments = @($script, 'cleanup', '--subscription', $SubscriptionId)
if ($Owner) { $arguments += @('--owner', $Owner) }
if ($WhatIfPreference) {
    & python3 @arguments --dry-run
} elseif ($PSCmdlet.ShouldProcess($SubscriptionId, 'Delete owned Base DB systems only; preserve all central anchors and DNS')) {
    & python3 @arguments
} else {
    throw 'Cleanup not authorized; no deletion success claimed.'
}
if ($LASTEXITCODE -ne 0) {
    throw "Base DB cleanup failed with exit code $LASTEXITCODE."
}

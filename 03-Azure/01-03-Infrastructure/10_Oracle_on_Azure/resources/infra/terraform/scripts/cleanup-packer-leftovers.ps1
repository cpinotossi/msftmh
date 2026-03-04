<#
.SYNOPSIS
  Cleans up leftover Packer (pkr*) resources from a resource group.

.DESCRIPTION
  Packer Azure ARM builds create temporary resources named pkr* (VM, NIC, VNet, NSG, Public IP, disks, etc.).
  If a build is interrupted or cleanup fails, these can remain.

  This script deletes:
    - All VMs in the RG whose name starts with 'pkr'
    - All remaining resources in the RG whose name starts with 'pkr'

  It does NOT touch Compute Gallery resources (gal_*).

.PARAMETER Subscription
  Azure subscription ID or name to target.

.PARAMETER ResourceGroup
  Resource group to clean up (default: rg-shared-workshop).

.PARAMETER Apply
  Actually perform deletions. Without -Apply it will only print what it would delete.
#>

param(
  [Parameter(Mandatory = $false)]
  [string]$Subscription,

  [Parameter(Mandatory = $false)]
  [string]$ResourceGroup = "rg-shared-workshop",

  [Parameter(Mandatory = $false)]
  [switch]$Apply
)

$ErrorActionPreference = "Stop"

function Invoke-Az {
  param(
    [Parameter(Mandatory = $true)][string]$Message,
    [Parameter(Mandatory = $true)][ScriptBlock]$Command
  )
  & $Command | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "WARN: $Message (exit=$LASTEXITCODE)" -ForegroundColor DarkYellow
    $global:LASTEXITCODE = 0
    return $false
  }
  return $true
}

if ($Subscription) {
  & az account set --subscription $Subscription | Out-Null
}

$sub = (& az account show --query id -o tsv).Trim()
Write-Host "Using subscription: $sub" -ForegroundColor Green
Write-Host "Target resource group: $ResourceGroup" -ForegroundColor Green
Write-Host "Mode: $([string]::Join('', @($(if ($Apply) { 'APPLY' } else { 'DRY-RUN' }))))" -ForegroundColor Yellow

# 1) Delete Packer VMs first (they keep NIC/disks attached)
$vmJson = & az vm list -g $ResourceGroup -o json
$vms = @()
if ($vmJson) {
  $vms = $vmJson | ConvertFrom-Json
}

$pkrVms = @($vms | Where-Object { $_.name -like "pkr*" } | Select-Object -ExpandProperty name)
if ($pkrVms.Count -eq 0) {
  Write-Host "No pkr* VMs found." -ForegroundColor Green
} else {
  Write-Host ("Found {0} pkr* VM(s): {1}" -f $pkrVms.Count, ($pkrVms -join ", ")) -ForegroundColor Yellow
  foreach ($vm in $pkrVms) {
    if (-not $vm) { continue }
    if ($Apply) {
      $ok = Invoke-Az -Message "Failed to delete VM $vm" -Command { az vm delete -g $ResourceGroup -n $vm --yes }
      if ($ok) {
        Write-Host "Deleted VM: $vm" -ForegroundColor Green
      }
    } else {
      Write-Host "Would delete VM: $vm" -ForegroundColor DarkYellow
    }
  }
}

# 2) Delete all remaining pkr* resources (in multiple passes for dependencies)
for ($pass = 1; $pass -le 10; $pass++) {
  $resourceJson = & az resource list -g $ResourceGroup -o json
  $allResources = @()
  if ($resourceJson) {
    $allResources = $resourceJson | ConvertFrom-Json
  }

  $resources = @($allResources |
    Where-Object { $_.name -like "pkr*" } |
    Select-Object -Property id, name, type)

  if ($resources.Count -eq 0) {
    if ($pass -eq 1) {
      Write-Host "No remaining pkr* resources found." -ForegroundColor Green
    } else {
      Write-Host "No remaining pkr* resources found after pass $pass." -ForegroundColor Green
    }
    break
  }

  Write-Host ("Pass {0}: found {1} pkr* resource(s) to delete" -f $pass, $resources.Count) -ForegroundColor Yellow

  # Heuristic order: delete network + compute attachments before VNets
  $typeOrder = @(
    "Microsoft.Compute/virtualMachines",
    "Microsoft.Compute/virtualMachineScaleSets",
    "Microsoft.Compute/disks",
    "Microsoft.Network/networkInterfaces",
    "Microsoft.Network/publicIPAddresses",
    "Microsoft.Network/networkSecurityGroups",
    "Microsoft.Network/virtualNetworks",
    "Microsoft.OperationalInsights/workspaces",
    "Microsoft.Insights/.*"
  )

  $sorted = $resources | Sort-Object -Property @{ Expression = {
    $t = $_.type
    $idx = 999
    for ($i = 0; $i -lt $typeOrder.Count; $i++) {
      if ($t -match ("^" + $typeOrder[$i] + "$")) { $idx = $i; break }
      if ($t -match $typeOrder[$i]) { $idx = $i; break }
    }
    $idx
  } }, type, name

  foreach ($r in $sorted) {
    if ($Apply) {
      $ok = Invoke-Az -Message "Failed to delete $($r.type) $($r.name)" -Command { az resource delete --ids $r.id }
      if ($ok) {
        Write-Host "Deleted: $($r.type) $($r.name)" -ForegroundColor Green
      } else {
        Write-Host "Will retry next pass: $($r.type) $($r.name)" -ForegroundColor DarkYellow
      }
    } else {
      Write-Host "Would delete: $($r.type) $($r.name)" -ForegroundColor DarkYellow
    }
  }

  if (-not $Apply) {
    break
  }
}

Write-Host "Done." -ForegroundColor Green

$global:LASTEXITCODE = 0
exit 0

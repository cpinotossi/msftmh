[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$SubscriptionId,

  [Parameter(Mandatory = $true)]
  [string[]]$ResourceGroups,

  [switch]$Wait,
  [int]$TimeoutMinutes = 20,
  [int]$IntervalSeconds = 20
)

$ErrorActionPreference = 'Continue'

$resourceGroupsUnique = $ResourceGroups | Where-Object { $_ -and $_.Trim() -ne '' } | ForEach-Object { $_.Trim() } | Sort-Object -Unique

$started = @()
$skipped = @()
$failed = @()

$acctOut = (az account set --subscription $SubscriptionId) 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host "[FATAL] az account set failed for subscription: $SubscriptionId" -ForegroundColor Red
  $acctOut | Out-String | Write-Host
  exit 1
}

foreach ($rg in $resourceGroupsUnique) {
  $exists = (az group exists --subscription $SubscriptionId --name $rg -o tsv) 2>&1
  if ($LASTEXITCODE -ne 0) {
    $failed += [pscustomobject]@{ SubscriptionId=$SubscriptionId; ResourceGroup=$rg; Step='exists'; Error=($exists -join "`n") }
    Write-Host "[ERROR] exists check failed: $SubscriptionId / $rg" -ForegroundColor Red
    continue
  }

  if (($exists | Select-Object -Last 1) -ne 'true') {
    $skipped += $rg
    Write-Host "[SKIP ] not found: $SubscriptionId / $rg" -ForegroundColor DarkGray
    continue
  }

  Write-Host "[DEL  ] $SubscriptionId / $rg" -ForegroundColor Yellow
  $delOut = (az group delete --subscription $SubscriptionId --name $rg --yes --no-wait) 2>&1
  if ($LASTEXITCODE -ne 0) {
    $failed += [pscustomobject]@{ SubscriptionId=$SubscriptionId; ResourceGroup=$rg; Step='delete'; Error=($delOut -join "`n") }
    Write-Host "[ERROR] delete failed: $SubscriptionId / $rg" -ForegroundColor Red
  } else {
    $started += $rg
  }
}

Write-Host ""
Write-Host ("Started deletes: {0} | Not found: {1} | Failed: {2}" -f $started.Count, $skipped.Count, $failed.Count)

if ($failed.Count -gt 0) {
  Write-Host ""
  Write-Host "Failures:" -ForegroundColor Red
  $failed | Format-List | Out-String | Write-Host
}

if (-not $Wait) { exit 0 }

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
Write-Host ""
Write-Host "Waiting up to $TimeoutMinutes minutes for deletions to complete..." -ForegroundColor Cyan

while ($true) {
  $remaining = @()
  foreach ($rg in $started) {
    $exists = (az group exists --subscription $SubscriptionId --name $rg -o tsv) 2>&1
    if ($LASTEXITCODE -ne 0) { $remaining += $rg; continue }
    if (($exists | Select-Object -Last 1) -eq 'true') { $remaining += $rg }
  }

  if ($remaining.Count -eq 0) {
    Write-Host "All started deletions are completed." -ForegroundColor Green
    break
  }

  if ((Get-Date) -ge $deadline) {
    Write-Host "Timeout reached; still remaining:" -ForegroundColor Yellow
    $remaining | Sort-Object | ForEach-Object { Write-Host "- $_" }
    break
  }

  Write-Host ("Remaining: {0} ..." -f $remaining.Count) -ForegroundColor Cyan
  Start-Sleep -Seconds $IntervalSeconds
}

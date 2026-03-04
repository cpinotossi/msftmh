[CmdletBinding()]
param(
  [switch]$Wait,
  [int]$TimeoutMinutes = 20,
  [int]$IntervalSeconds = 20
)

$ErrorActionPreference = 'Continue'

$map = @{
  '09808f31-065f-4231-914d-776c2d6bbe34' = @(
    'aks-user00','aks-user05',
    'MC_aks-user00_aks-user00','MC_aks-user05_aks-user05',
    'Default-ActivityLogAlerts','DefaultResourceGroup-DEWC','DefaultResourceGroup-PAR','NetworkWatcherRG'
  )
  'a0844269-41ae-442c-8277-415f1283d422' = @(
    'aks-user01','aks-user06',
    'MC_aks-user01_aks-user01','MC_aks-user06_aks-user06',
    'Default-ActivityLogAlerts','DefaultResourceGroup-PAR','NetworkWatcherRG'
  )
  'b1658f1f-33e5-4e48-9401-f66ba5e64cce' = @(
    'aks-user02','aks-user07',
    'MC_aks-user02_aks-user02','MC_aks-user07_aks-user07',
    'Default-ActivityLogAlerts','DefaultResourceGroup-PAR','NetworkWatcherRG'
  )
  '9aa72379-2067-4948-b51c-de59f4005d04' = @(
    'aks-user03','aks-user08',
    'MC_aks-user03_aks-user03','MC_aks-user08_aks-user08',
    'Default-ActivityLogAlerts','DefaultResourceGroup-PAR','NetworkWatcherRG'
  )
  '98525264-1eb4-493f-983d-16a330caa7f6' = @(
    'aks-user04','aks-user09',
    'MC_aks-user04_aks-user04','MC_aks-user09_aks-user09',
    'Default-ActivityLogAlerts','DefaultResourceGroup-PAR','NetworkWatcherRG'
  )
}

$targets = foreach ($sub in ($map.Keys | Sort-Object)) {
  foreach ($rg in ($map[$sub] | Sort-Object -Unique)) {
    [pscustomobject]@{ SubscriptionId = $sub; ResourceGroup = $rg }
  }
}

try {
  $started = @()
  $skipped = @()
  $failed = @()

  foreach ($t in $targets) {
    $sub = $t.SubscriptionId
    $rg  = $t.ResourceGroup

    $acctOut = (az account set --subscription $sub) 2>&1
    if ($LASTEXITCODE -ne 0) {
      $failed += [pscustomobject]@{ SubscriptionId=$sub; ResourceGroup=$rg; Step='account-set'; Error=($acctOut -join "`n") }
      Write-Host "[ERROR] account set failed: $sub" -ForegroundColor Red
      continue
    }

    $exists = (az group exists --subscription $sub --name $rg -o tsv) 2>&1
    if ($LASTEXITCODE -ne 0) {
      $failed += [pscustomobject]@{ SubscriptionId=$sub; ResourceGroup=$rg; Step='exists'; Error=($exists -join "`n") }
      Write-Host "[ERROR] exists check failed: $sub / $rg" -ForegroundColor Red
      continue
    }

    if (($exists | Select-Object -Last 1) -ne 'true') {
      $skipped += $t
      Write-Host "[SKIP ] not found: $sub / $rg" -ForegroundColor DarkGray
      continue
    }

    Write-Host "[DEL  ] $sub / $rg" -ForegroundColor Yellow
    $delOut = (az group delete --subscription $sub --name $rg --yes --no-wait) 2>&1
    if ($LASTEXITCODE -ne 0) {
      $failed += [pscustomobject]@{ SubscriptionId=$sub; ResourceGroup=$rg; Step='delete'; Error=($delOut -join "`n") }
      Write-Host "[ERROR] delete failed: $sub / $rg" -ForegroundColor Red
    } else {
      $started += $t
    }
  }

  Write-Host "" 
  Write-Host ("Started deletes: {0} | Not found: {1} | Failed: {2}" -f $started.Count, $skipped.Count, $failed.Count)

  if ($failed.Count -gt 0) {
    Write-Host "" 
    Write-Host "First failures:" -ForegroundColor Red
    $failed | Select-Object -First 10 | Format-List | Out-String | Write-Host
  }

  if (-not $Wait) {
    exit 0
  }

  $deadline = (Get-Date).AddMinutes($TimeoutMinutes)

  function Test-AnyExists {
    param([object[]]$Started)
    $remaining = @()

    foreach ($t in $Started) {
      $sub = $t.SubscriptionId
      $rg  = $t.ResourceGroup

      $exists = (az group exists --subscription $sub --name $rg -o tsv) 2>&1
      if ($LASTEXITCODE -ne 0) {
        $remaining += $t
        continue
      }
      if (($exists | Select-Object -Last 1) -eq 'true') {
        $remaining += $t
      }
    }

    return $remaining
  }

  Write-Host "" 
  Write-Host "Waiting up to $TimeoutMinutes minutes for deletions to complete..." -ForegroundColor Cyan

  while ($true) {
    $remaining = Test-AnyExists -Started $started
    if ($remaining.Count -eq 0) {
      Write-Host "All started deletions are completed." -ForegroundColor Green
      break
    }

    if ((Get-Date) -ge $deadline) {
      Write-Host "Timeout reached; still remaining:" -ForegroundColor Yellow
      $remaining | Format-Table SubscriptionId, ResourceGroup | Out-String | Write-Host
      break
    }

    Write-Host ("Remaining: {0} ..." -f $remaining.Count) -ForegroundColor Cyan
    Start-Sleep -Seconds $IntervalSeconds
  }
} catch {
  Write-Host "[FATAL] Unhandled exception:" -ForegroundColor Red
  $_ | Format-List -Force | Out-String | Write-Host
  exit 1
}


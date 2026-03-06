#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy/destroy Oracle on Azure workshop infrastructure with safe parallelism.

.DESCRIPTION
    Wraps terraform plan + apply with:
    - Reduced parallelism (-parallelism=5) to avoid Azure API race conditions
      during resource destruction. Azure's async API can return success before
      a resource is fully disassociated (e.g., NSG → Subnet, NIC → Public IP),
      causing subsequent deletes to fail with "resource in use" errors.
    - Automatic retry logic: if apply fails due to Azure eventual consistency,
      the script waits 30s and retries with a fresh plan (up to MaxRetries).

.PARAMETER Destroy
    If set, runs terraform destroy instead of apply.

.PARAMETER PlanOnly
    If set, only runs terraform plan without applying.

.PARAMETER AutoApprove
    If set, skips confirmation prompts (uses -auto-approve for destroy).

.PARAMETER Parallelism
    Max concurrent Terraform operations. Default: 5.
    Lower values are safer for destroy but slower for create.

.PARAMETER MaxRetries
    Max retry attempts if apply fails. Default: 3.

.EXAMPLE
    # Normal deployment
    .\scripts\deploy.ps1

.EXAMPLE
    # Destroy all user resources (user_count=0 in tfvars)
    .\scripts\deploy.ps1 -AutoApprove

.EXAMPLE
    # Full destroy of everything
    .\scripts\deploy.ps1 -Destroy -AutoApprove

.EXAMPLE
    # Plan only
    .\scripts\deploy.ps1 -PlanOnly
#>

[CmdletBinding()]
param(
    [switch]$Destroy,
    [switch]$PlanOnly,
    [switch]$AutoApprove,
    [int]$Parallelism = 5,
    [int]$MaxRetries = 3
)

$ErrorActionPreference = "Stop"
$TerraformRoot = Split-Path $PSScriptRoot -Parent

Push-Location $TerraformRoot
try {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Terraform Deploy Script" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Working dir:  $TerraformRoot"
    Write-Host "Parallelism:  $Parallelism"
    Write-Host "Max retries:  $MaxRetries"
    Write-Host "Mode:         $(if ($Destroy) { 'DESTROY' } elseif ($PlanOnly) { 'PLAN ONLY' } else { 'APPLY' })"
    Write-Host ""

    # --- Init (if needed) ---
    if (-not (Test-Path ".terraform")) {
        Write-Host "[0/2] Initializing terraform..." -ForegroundColor Yellow
        terraform init -no-color
        if ($LASTEXITCODE -ne 0) { throw "terraform init failed" }
    }

    # --- Plan ---
    Write-Host "[1/2] Running terraform plan..." -ForegroundColor Yellow

    $planArgs = @("-out=tfplan", "-parallelism=$Parallelism", "-no-color")
    if ($Destroy) { $planArgs += "-destroy" }

    terraform plan @planArgs
    if ($LASTEXITCODE -ne 0) { throw "terraform plan failed" }

    # Check plan summary
    $planSummary = terraform show -no-color tfplan 2>&1 | Select-String "Plan:|No changes"
    $planSummary | ForEach-Object { Write-Host "  $($_.Line)" -ForegroundColor Cyan }

    $noChanges = $planSummary | Select-String "No changes"
    if ($noChanges) {
        Write-Host "`nNo changes needed. Infrastructure is up to date." -ForegroundColor Green
        return
    }

    $hasDestroys = terraform show -no-color tfplan 2>&1 | Select-String "will be destroyed"
    if ($hasDestroys) {
        Write-Host "`n  WARNING: Resources will be DESTROYED." -ForegroundColor Red
        Write-Host "  Using parallelism=$Parallelism with retry logic for safe destruction.`n" -ForegroundColor Yellow
    }

    if ($PlanOnly) {
        Write-Host "Plan-only mode. Run without -PlanOnly to apply." -ForegroundColor Yellow
        return
    }

    # --- Apply with retry ---
    Write-Host "[2/2] Running terraform apply..." -ForegroundColor Yellow

    $attempt = 0
    $success = $false

    while ($attempt -lt $MaxRetries -and -not $success) {
        $attempt++
        Write-Host "`n--- Attempt $attempt of $MaxRetries ---" -ForegroundColor Cyan

        if ($attempt -eq 1) {
            # First attempt: use the saved plan file
            terraform apply -parallelism=$Parallelism -no-color tfplan
        }
        else {
            # Retry: generate a fresh plan (state changed from previous attempt)
            Write-Host "Generating fresh plan for retry..." -ForegroundColor Yellow
            $retryPlanArgs = @("-out=tfplan", "-parallelism=$Parallelism", "-no-color")
            if ($Destroy) { $retryPlanArgs += "-destroy" }

            terraform plan @retryPlanArgs
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Plan failed on retry $attempt" -ForegroundColor Red
                continue
            }

            # Check if there's still work to do
            $retryNoChanges = terraform show -no-color tfplan 2>&1 | Select-String "No changes"
            if ($retryNoChanges) {
                Write-Host "No more changes needed. Previous attempt completed all work." -ForegroundColor Green
                $success = $true
                break
            }

            terraform show -no-color tfplan 2>&1 | Select-String "Plan:" |
                ForEach-Object { Write-Host "  Remaining: $($_.Line)" -ForegroundColor Yellow }

            terraform apply -parallelism=$Parallelism -no-color tfplan
        }

        if ($LASTEXITCODE -eq 0) {
            $success = $true
        }
        else {
            Write-Host "`nAttempt $attempt had errors. Azure API may need time to propagate." -ForegroundColor Yellow
            if ($attempt -lt $MaxRetries) {
                $wait = 30
                Write-Host "Waiting $($wait)s before retry..." -ForegroundColor Yellow
                Start-Sleep -Seconds $wait
            }
        }
    }

    if ($success) {
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host " Terraform apply completed successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
    }
    else {
        Write-Host "`n========================================" -ForegroundColor Red
        Write-Host " Terraform apply failed after $MaxRetries attempts!" -ForegroundColor Red
        Write-Host " Try: terraform apply -parallelism=1" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        exit 1
    }
}
finally {
    Pop-Location
}

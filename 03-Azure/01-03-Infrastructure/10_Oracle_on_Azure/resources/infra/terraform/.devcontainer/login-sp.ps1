#!/usr/bin/env pwsh
# Login script for Azure Service Principal
# Single source of truth: terraform.tfvars

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Logging in Azure CLI as Service Principal" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Parse terraform.tfvars (single source of truth)
$tfvarsPath = Join-Path $PSScriptRoot ".." "terraform.tfvars"
if (-not (Test-Path $tfvarsPath)) {
    Write-Host "ERROR: terraform.tfvars not found at $tfvarsPath" -ForegroundColor Red
    exit 1
}

Write-Host "Loading credentials from terraform.tfvars..."
$tfvars = @{}
Get-Content $tfvarsPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith('#') -and -not $line.StartsWith('//')) {
        # Strip inline comments
        $line = ($line -split '\s+#', 2)[0].Trim()
        if ($line -match '^([A-Za-z0-9_]+)\s*=\s*"([^"]*)"') {
            $tfvars[$Matches[1]] = $Matches[2]
        }
    }
}

$clientId     = $tfvars['client_id']
$clientSecret = $tfvars['client_secret']
$tenantId     = $tfvars['tenant_id']
$subscriptionId = $tfvars['vm_subscription_id']

if (-not $clientId -or -not $clientSecret -or -not $tenantId) {
    Write-Host "ERROR: Missing required fields in terraform.tfvars!" -ForegroundColor Red
    Write-Host "  Required: client_id, client_secret, tenant_id" -ForegroundColor Yellow
    exit 1
}

# Set ARM_* env vars for Terraform provider
[Environment]::SetEnvironmentVariable("ARM_CLIENT_ID", $clientId, "Process")
[Environment]::SetEnvironmentVariable("ARM_CLIENT_SECRET", $clientSecret, "Process")
[Environment]::SetEnvironmentVariable("ARM_TENANT_ID", $tenantId, "Process")
if ($subscriptionId) {
    [Environment]::SetEnvironmentVariable("ARM_SUBSCRIPTION_ID", $subscriptionId, "Process")
}

# Login as service principal
az login --service-principal `
    --username $clientId `
    --password $clientSecret `
    --tenant $tenantId `
    --output none

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Azure login failed!" -ForegroundColor Red
    exit 1
}

# Set subscription
if ($subscriptionId) {
    az account set --subscription $subscriptionId
}

Write-Host ""
Write-Host "Logged in as Service Principal:" -ForegroundColor Green
az account show --query "{name:name, user:user.name, type:user.type}" -o table

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Dev Container Ready!" -ForegroundColor Cyan
Write-Host "Use 'tf' as shortcut for 'terraform'" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Cyan

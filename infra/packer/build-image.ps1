<#
.SYNOPSIS
    Builds the Oracle Workshop VM image using Packer and publishes to Azure Compute Gallery.

.DESCRIPTION
    This script builds a fully configured Ubuntu 24.04 VM image with Oracle tools
    pre-installed and publishes it to the Azure Compute Gallery.

.PARAMETER Version
    Image version to create (semver format, e.g., "1.0.0")

.PARAMETER Validate
    Only validate the Packer template without building

.PARAMETER Debug
    Enable Packer debug mode

.EXAMPLE
    .\build-image.ps1 -Version "1.0.0"
    
.EXAMPLE
    .\build-image.ps1 -Validate
#>

param (
    [Parameter()]
    [string]$Version = "1.1.0",
    
    [Parameter()]
    [switch]$Validate,
    
    [Parameter()]
    [switch]$PackerDebug
)

$ErrorActionPreference = "Stop"

# =============================================================================
# Configuration
# =============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VarsFile = Join-Path $ScriptDir "variables.auto.pkrvars.hcl"
$VarsExample = Join-Path $ScriptDir "variables.pkrvars.hcl.example"

# =============================================================================
# Pre-flight Checks
# =============================================================================

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Oracle Workshop Image Builder" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Check Packer
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

$packer = Get-Command packer -ErrorAction SilentlyContinue
if (-not $packer) {
    Write-Host "ERROR: Packer is not installed." -ForegroundColor Red
    Write-Host "Install via: choco install packer" -ForegroundColor Yellow
    Write-Host "Or download from: https://www.packer.io/downloads" -ForegroundColor Yellow
    exit 1
}

$packerVersion = & packer version
if ($packerVersion -notmatch 'Packer v([0-9]+\.[0-9]+\.[0-9]+)' -or
    [version]$matches[1] -lt [version]'1.16.2') {
    throw "Install Packer 1.16.2 or newer; older installers cannot fetch the pinned Azure plugin from HashiCorp releases."
}
Write-Host "  Packer: $packerVersion" -ForegroundColor Green

# Ansible runs on the temporary build VM, not the local build machine.
# Validation does not require Azure login; builds use the active Azure CLI session.

# Check variables file
if (-not (Test-Path $VarsFile)) {
    Write-Host ""
    Write-Host "ERROR: Variables file not found: $VarsFile" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please create it from the example:" -ForegroundColor Yellow
    Write-Host "  Copy-Item '$VarsExample' '$VarsFile'" -ForegroundColor Cyan
    Write-Host "  Then review $VarsFile for the target subscription and gallery." -ForegroundColor Yellow
    exit 1
}

Write-Host "  Variables: $VarsFile" -ForegroundColor Green
Write-Host ""

# =============================================================================
# Initialize Packer Plugins
# =============================================================================

Write-Host "Initializing Packer plugins..." -ForegroundColor Yellow
Push-Location $ScriptDir
try {
    & packer init .
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Packer init failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Plugins initialized successfully" -ForegroundColor Green
}
finally {
    Pop-Location
}
Write-Host ""

# =============================================================================
# Validate Template
# =============================================================================

Write-Host "Validating Packer template..." -ForegroundColor Yellow
Push-Location $ScriptDir
try {
    & packer validate -var "image_version=$Version" .
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Packer validation failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Template validated successfully" -ForegroundColor Green
}
finally {
    Pop-Location
}
Write-Host ""

if ($Validate) {
    Write-Host "Validation complete (build skipped with -Validate flag)" -ForegroundColor Green
    exit 0
}

# =============================================================================
# Build Image
# =============================================================================

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Building Image Version: $Version" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""
Write-Host "This will:" -ForegroundColor Yellow
Write-Host "  1. Create a temporary VM in Azure" -ForegroundColor White
Write-Host "  2. Run Ansible to install Oracle tools" -ForegroundColor White
Write-Host "  3. Generalize the VM" -ForegroundColor White
Write-Host "  4. Capture to Azure Compute Gallery" -ForegroundColor White
Write-Host "The gallery definition must already exist in rg-workshop-images (x64, Gen2, generalized)." -ForegroundColor Yellow
Write-Host "The separate rg-packer-build resource group must already exist in France Central." -ForegroundColor Yellow
Write-Host ""
Write-Host "Estimated time: 15-25 minutes" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Continue? (y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "Build cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Starting build..." -ForegroundColor Green
Write-Host ""

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI is required for the build. Install it and run az login."
}
$account = & az account show -o json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "Azure CLI login is required before building."
}
if ($account.id -ne "aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483" -or
    $account.tenantId -ne "8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5") {
    throw "Select the approved workshop subscription and tenant before building."
}

$python = Get-Command python3 -ErrorAction Stop
& $python.Source (Join-Path $ScriptDir "check_vm_prerequisites.py") build
if ($LASTEXITCODE -ne 0) {
    throw "The fixed v7/NVMe image prerequisites are not satisfied."
}

$buildArgs = @(
    "build"
    "-var", "image_version=$Version"
)

if ($PackerDebug) {
    $buildArgs += "-debug"
}

$buildArgs += "."

Push-Location $ScriptDir
try {
    $startTime = Get-Date
    
    & packer @buildArgs
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "=" * 80 -ForegroundColor Red
        Write-Host "BUILD FAILED" -ForegroundColor Red
        Write-Host "=" * 80 -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host "BUILD SUCCESSFUL" -ForegroundColor Green
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host ""
    Write-Host "Duration: $($duration.Minutes) minutes $($duration.Seconds) seconds" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Image Details:" -ForegroundColor Yellow
    Write-Host "  Gallery:     gal_oracle_workshop" -ForegroundColor White
    Write-Host "  Image:       oracle-workshop-vm" -ForegroundColor White
    Write-Host "  Version:     $Version" -ForegroundColor White
    Write-Host ""
    Write-Host "To use this image in Terraform, set:" -ForegroundColor Yellow
    Write-Host "  vm_image_version = `"$Version`"" -ForegroundColor Cyan
    Write-Host ""
}
finally {
    Pop-Location
}

<#
.SYNOPSIS
    Manage workshop user credentials: rotate passwords and/or reset MFA.

.DESCRIPTION
    Combined script for workshop user lifecycle management:
    - rotate-passwords: Generate new random passwords via Azure CLI (no Terraform needed)
    - reset-mfa: Remove all MFA methods (except password) via Microsoft Graph API
    - reset-all: Both operations in one run

    Reads user list from user_credentials.json and updates it with new passwords.

    Required permissions:
    - az ad user update: User Administrator or Password Administrator role
    - MFA reset: UserAuthenticationMethod.ReadWrite.All (Application permission)
      or Authentication Administrator role

.PARAMETER Action
    What to do: "rotate-passwords", "reset-mfa", or "reset-all" (both).

.PARAMETER CredentialsFile
    Path to user_credentials.json. Default: auto-detect from script location.

.PARAMETER PasswordLength
    Length of generated passwords. Default: 16. Minimum: 12.

.PARAMETER ForceChangeOnLogin
    Force users to change password on next login. Default: true.

.PARAMETER EventName
    Optional event name stored in user_credentials.json metadata.

.PARAMETER WhatIf
    Preview what would happen without making changes.

.EXAMPLE
    # Before a new workshop: new passwords + clear MFA
    .\manage-users.ps1 -Action reset-all -EventName "workshop-march-2026"

.EXAMPLE
    # Only rotate passwords
    .\manage-users.ps1 -Action rotate-passwords

.EXAMPLE
    # Only reset MFA (keep existing passwords)
    .\manage-users.ps1 -Action reset-mfa

.EXAMPLE
    # Preview changes without applying
    .\manage-users.ps1 -Action reset-all -WhatIf

.EXAMPLE
    # Custom credentials file location
    .\manage-users.ps1 -Action rotate-passwords -CredentialsFile "C:\path\to\user_credentials.json"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('rotate-passwords', 'reset-mfa', 'reset-all')]
    [string]$Action,

    [string]$CredentialsFile,

    [string]$OutputFile,  # Output file for rotated credentials (default: auto-generated)

    [ValidateRange(1, 25)]
    [int]$UserCount = 0,  # 0 = all users

    [ValidateRange(12, 128)]
    [int]$PasswordLength = 16,

    [bool]$ForceChangeOnLogin = $true,

    [string]$EventName
)

$ErrorActionPreference = 'Stop'

# ═══════════════════════════════════════════════════════════════════════════════
# Resolve credentials file
# ═══════════════════════════════════════════════════════════════════════════════

if (-not $CredentialsFile) {
    # Single source of truth: lab-env/user_credentials.json
    $scriptDir = $PSScriptRoot
    $CredentialsFile = Join-Path $scriptDir "..\lab-env\user_credentials.json"
    
    if (-not (Test-Path $CredentialsFile)) {
        throw "user_credentials.json not found at: $CredentialsFile`nRun identity/ terraform first to create users."
    }
    $CredentialsFile = (Resolve-Path $CredentialsFile).Path
}

if (-not (Test-Path $CredentialsFile)) {
    throw "Credentials file not found: $CredentialsFile"
}

# Load credentials
$credentials = Get-Content $CredentialsFile -Raw | ConvertFrom-Json
$allUsers = @($credentials.users.PSObject.Properties)

if ($allUsers.Count -eq 0) {
    throw "No users found in $CredentialsFile"
}

# Filter users by UserCount if specified
if ($UserCount -gt 0) {
    # Sort by user index (user00, user01, ...) and take first N
    $users = $allUsers | Sort-Object { [int]($_.Name -replace '\D', '') } | Select-Object -First $UserCount
} else {
    $users = $allUsers
}

# ═══════════════════════════════════════════════════════════════════════════════
# Banner
# ═══════════════════════════════════════════════════════════════════════════════

$actionLabel = switch ($Action) {
    'rotate-passwords' { 'ROTATE PASSWORDS' }
    'reset-mfa'        { 'RESET MFA' }
    'reset-all'        { 'ROTATE PASSWORDS + RESET MFA' }
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  USER MANAGEMENT - $($actionLabel.PadRight(38))║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Users:            $($users.Count)" -ForegroundColor White
Write-Host "  Credentials file: $CredentialsFile" -ForegroundColor White
if ($EventName) {
    Write-Host "  Event:            $EventName" -ForegroundColor White
}
if ($WhatIfPreference) {
    Write-Host "  Mode:             DRY RUN (no changes)" -ForegroundColor Yellow
}
Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# Verify Azure CLI login
# ═══════════════════════════════════════════════════════════════════════════════

try {
    $account = az account show 2>&1 | ConvertFrom-Json
    Write-Host "  Logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host ""
} catch {
    throw "Not logged in to Azure CLI. Run 'az login' first."
}

# ═══════════════════════════════════════════════════════════════════════════════
# Microsoft Graph SDK login for MFA reset
# ═══════════════════════════════════════════════════════════════════════════════

$doPasswords = $Action -in @('rotate-passwords', 'reset-all')
$doMfa       = $Action -in @('reset-mfa', 'reset-all')

if ($doMfa) {
    try {
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
            throw "Microsoft.Graph.Authentication module is not installed. Install with: Install-Module Microsoft.Graph -Scope CurrentUser"
        }

        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

        $requiredScopes = @()
        if ($doMfa) {
            $requiredScopes += 'UserAuthenticationMethod.ReadWrite.All'
        }
        $mgContext = Get-MgContext -ErrorAction SilentlyContinue
        $hasRequiredScopes = $false

        if ($mgContext -and $mgContext.Scopes) {
            $missingScopes = $requiredScopes | Where-Object { $_ -notin $mgContext.Scopes }
            $hasRequiredScopes = $missingScopes.Count -eq 0
        }

        if (-not $hasRequiredScopes) {
            Write-Host "  Device Code Login fuer Microsoft Graph wird gestartet..." -ForegroundColor Yellow
            Write-Host "  Falls angezeigt: Code im Browser auf https://microsoft.com/devicelogin eingeben." -ForegroundColor Yellow
            Connect-MgGraph -Scopes $requiredScopes -UseDeviceCode -ContextScope Process | Out-Null
        }

        Write-Host "  Microsoft Graph context ready" -ForegroundColor Green
        Write-Host ""
    } catch {
        throw "Unable to initialize Microsoft Graph context. $($_.Exception.Message)"
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Password Generation
# ═══════════════════════════════════════════════════════════════════════════════

function New-SecurePassword {
    param([int]$Length = 16)

    # Character sets ensuring Entra ID requirements (3 of 4 categories)
    $upper   = 'ABCDEFGHJKLMNPQRSTUVWXYZ'       # No I, O (avoid confusion)
    $lower   = 'abcdefghjkmnpqrstuvwxyz'         # No i, l, o
    $digits  = '23456789'                         # No 0, 1
    $special = '@#*+-='

    # Guarantee at least one from each category
    $password = @(
        $upper[$script:rng.Next($upper.Length)]
        $lower[$script:rng.Next($lower.Length)]
        $digits[$script:rng.Next($digits.Length)]
        $special[$script:rng.Next($special.Length)]
    )

    # Fill remaining length from all characters
    $allChars = $upper + $lower + $digits + $special
    for ($i = $password.Count; $i -lt $Length; $i++) {
        $password += $allChars[$script:rng.Next($allChars.Length)]
    }

    # Shuffle using Fisher-Yates
    $arr = [char[]]$password
    for ($i = $arr.Length - 1; $i -gt 0; $i--) {
        $j = $script:rng.Next($i + 1)
        $tmp = $arr[$i]; $arr[$i] = $arr[$j]; $arr[$j] = $tmp
    }

    return -join $arr
}

# Initialize RNG
$script:rng = [System.Random]::new()

# ═══════════════════════════════════════════════════════════════════════════════
# MFA Reset Logic
# ═══════════════════════════════════════════════════════════════════════════════

function Reset-UserMfa {
    param([string]$Upn)

    try {
        $encodedUpn = [System.Uri]::EscapeDataString($Upn)
        $methods = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$encodedUpn/authentication/methods"
        $mfaMethods = $methods.value | Where-Object {
            $_.'@odata.type' -ne '#microsoft.graph.passwordAuthenticationMethod'
        }

        if ($mfaMethods.Count -eq 0) {
            Write-Host "    No MFA methods registered" -ForegroundColor Gray
            return $true
        }

        Write-Host "    Found $($mfaMethods.Count) MFA method(s)" -ForegroundColor Yellow

        foreach ($method in $mfaMethods) {
            $methodType = $method.'@odata.type' -replace '#microsoft.graph.', ''
            $methodId = $method.id

            $deleteUri = switch ($methodType) {
                "phoneAuthenticationMethod"                    { "https://graph.microsoft.com/v1.0/users/$Upn/authentication/phoneMethods/$methodId" }
                "microsoftAuthenticatorAuthenticationMethod"   { "https://graph.microsoft.com/v1.0/users/$Upn/authentication/microsoftAuthenticatorMethods/$methodId" }
                "softwareOathAuthenticationMethod"             { "https://graph.microsoft.com/v1.0/users/$Upn/authentication/softwareOathMethods/$methodId" }
                "fido2AuthenticationMethod"                    { "https://graph.microsoft.com/v1.0/users/$Upn/authentication/fido2Methods/$methodId" }
                "windowsHelloForBusinessAuthenticationMethod"  { "https://graph.microsoft.com/v1.0/users/$Upn/authentication/windowsHelloForBusinessMethods/$methodId" }
                "emailAuthenticationMethod"                    { "https://graph.microsoft.com/v1.0/users/$Upn/authentication/emailMethods/$methodId" }
                "temporaryAccessPassAuthenticationMethod"      { "https://graph.microsoft.com/v1.0/users/$Upn/authentication/temporaryAccessPassMethods/$methodId" }
                default { $null }
            }

            if ($deleteUri) {
                if (-not $WhatIfPreference) {
                    try {
                        Invoke-MgGraphRequest -Method DELETE -Uri $deleteUri | Out-Null
                        Write-Host "    Removed: $methodType" -ForegroundColor Green
                    } catch {
                        Write-Host "    Failed to remove: $methodType - $($_.Exception.Message)" -ForegroundColor Red
                    }
                } else {
                    Write-Host "    [WhatIf] Would remove: $methodType" -ForegroundColor DarkYellow
                }
            }
        }
        return $true
    } catch {
        Write-Host "    ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main Processing Loop
# ═══════════════════════════════════════════════════════════════════════════════

$stats = @{
    PasswordSuccess = 0; PasswordError = 0
    MfaSuccess = 0; MfaNoMfa = 0; MfaError = 0
}

# Track new passwords for credentials update
$newPasswords = @{}

foreach ($userProp in $users) {
    $userKey = $userProp.Name
    $userData = $userProp.Value
    $upn = $userData.user_principal_name

    Write-Host "  [$userKey] $upn" -ForegroundColor Cyan

    # --- Password Rotation ---
    if ($doPasswords) {
        $newPwd = New-SecurePassword -Length $PasswordLength

        if ($WhatIfPreference) {
            Write-Host "    [WhatIf] Would set new password ($PasswordLength chars)" -ForegroundColor DarkYellow
            $stats.PasswordSuccess++
        } else {
            try {
                # Use az rest with JSON body via temp file to avoid shell escaping issues
                $bodyObj = @{
                    passwordProfile = @{
                        password                      = $newPwd
                        forceChangePasswordNextSignIn = $ForceChangeOnLogin
                    }
                }
                $tempPassword = $newPwd.Replace('"', '\"')
                $result = az ad user update `
                    --id $upn `
                    --password "$tempPassword" `
                    --force-change-password-next-sign-in $ForceChangeOnLogin 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    Password rotated" -ForegroundColor Green
                    $newPasswords[$userKey] = $newPwd
                    $stats.PasswordSuccess++
                } else {
                    Write-Host "    ERROR: Password update failed - $result" -ForegroundColor Red
                    $stats.PasswordError++
                }
            } catch {
                Write-Host "    ERROR: Password update failed - $($_.Exception.Message)" -ForegroundColor Red
                $stats.PasswordError++
            }
        }
    }

    # --- MFA Reset ---
    if ($doMfa) {
        $mfaResult = Reset-UserMfa -Upn $upn
        if ($mfaResult) {
            $stats.MfaSuccess++
        } else {
            $stats.MfaError++
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Write output file with rotated passwords (input file remains unchanged)
# ═══════════════════════════════════════════════════════════════════════════════

if ($doPasswords -and $newPasswords.Count -gt 0 -and -not $WhatIfPreference) {
    # Create a copy for output
    $output = $credentials | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    
    foreach ($userKey in $newPasswords.Keys) {
        $output.users.$userKey.password = $newPasswords[$userKey]
    }

    # Update metadata
    $output.generated_at = (Get-Date -Format "o")
    if ($EventName) {
        $output | Add-Member -NotePropertyName "event_name" -NotePropertyValue $EventName -Force
    }
    $output | Add-Member -NotePropertyName "last_action" -NotePropertyValue $Action -Force

    # Determine output file path
    if (-not $OutputFile) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($CredentialsFile)
        $dir = [System.IO.Path]::GetDirectoryName($CredentialsFile)
        $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
        $OutputFile = Join-Path $dir "${baseName}_${timestamp}.json"
    }

    $output | ConvertTo-Json -Depth 10 | Set-Content $OutputFile -Encoding UTF8
    Write-Host ""
    Write-Host "  ✓ Created $OutputFile" -ForegroundColor Green
    Write-Host "  ✓ Input file unchanged: $CredentialsFile" -ForegroundColor Gray
}

# ═══════════════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  ════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "  ════════════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($doPasswords) {
    Write-Host "  Passwords rotated:  $($stats.PasswordSuccess)" -ForegroundColor $(if ($stats.PasswordSuccess -gt 0) { "Green" } else { "Gray" })
    Write-Host "  Password errors:    $($stats.PasswordError)" -ForegroundColor $(if ($stats.PasswordError -gt 0) { "Red" } else { "Gray" })
}
if ($doMfa) {
    Write-Host "  MFA reset:          $($stats.MfaSuccess)" -ForegroundColor $(if ($stats.MfaSuccess -gt 0) { "Green" } else { "Gray" })
    Write-Host "  MFA errors:         $($stats.MfaError)" -ForegroundColor $(if ($stats.MfaError -gt 0) { "Red" } else { "Gray" })
}
Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# Display new credentials table (if passwords were rotated)
# ═══════════════════════════════════════════════════════════════════════════════

if ($doPasswords -and $newPasswords.Count -gt 0) {
    Write-Host "  New Credentials:" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    foreach ($userKey in ($newPasswords.Keys | Sort-Object)) {
        $upn = $credentials.users.$userKey.user_principal_name
        $pwd = $newPasswords[$userKey]
        Write-Host "  $upn  →  $pwd" -ForegroundColor White
    }
    Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
}

# Exit with error if any failures
if ($stats.PasswordError -gt 0 -or $stats.MfaError -gt 0) {
    Write-Host "  ⚠️  Some operations failed. Check output above." -ForegroundColor Yellow
    Write-Host ""

    if ($stats.MfaError -gt 0) {
        Write-Host "  MFA reset requires:" -ForegroundColor Yellow
        Write-Host "    - UserAuthenticationMethod.ReadWrite.All delegated Graph scope" -ForegroundColor White
        Write-Host "    - Or run as Authentication Administrator" -ForegroundColor White
    }
    if ($stats.PasswordError -gt 0) {
        Write-Host "  Password rotation requires:" -ForegroundColor Yellow
        Write-Host "    - User Administrator or Password Administrator role" -ForegroundColor White
    }
    Write-Host ""
    exit 1
}

Write-Host "  ✅ Done!" -ForegroundColor Green
Write-Host ""

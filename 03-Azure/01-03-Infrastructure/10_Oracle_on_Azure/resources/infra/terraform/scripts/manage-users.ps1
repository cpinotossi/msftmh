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
    # Auto-detect: look relative to script location
    $scriptDir = $PSScriptRoot
    $candidates = @(
        (Join-Path $scriptDir "..\user_credentials.json"),
        (Join-Path $scriptDir "..\identity\user_credentials.json")
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $CredentialsFile = (Resolve-Path $candidate).Path
            break
        }
    }
    if (-not $CredentialsFile) {
        throw "user_credentials.json not found. Searched:`n  $($candidates -join "`n  ")`nUse -CredentialsFile to specify the path."
    }
}

if (-not (Test-Path $CredentialsFile)) {
    throw "Credentials file not found: $CredentialsFile"
}

# Load credentials
$credentials = Get-Content $CredentialsFile -Raw | ConvertFrom-Json
$users = $credentials.users.PSObject.Properties

if ($users.Count -eq 0) {
    throw "No users found in $CredentialsFile"
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
        $methodsJson = az rest --method GET `
            --uri "https://graph.microsoft.com/v1.0/users/$Upn/authentication/methods" `
            --output json 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "    ERROR: Failed to get auth methods" -ForegroundColor Red
            return $false
        }

        $methods = $methodsJson | ConvertFrom-Json
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
                    az rest --method DELETE --uri $deleteUri 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "    Removed: $methodType" -ForegroundColor Green
                    } else {
                        Write-Host "    Failed to remove: $methodType" -ForegroundColor Red
                    }
                } else {
                    Write-Host "    [WhatIf] Would remove: $methodType" -ForegroundColor DarkYellow
                }
            }
        }
        return $true
    } catch {
        Write-Host "    ERROR: $_" -ForegroundColor Red
        return $false
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main Processing Loop
# ═══════════════════════════════════════════════════════════════════════════════

$doPasswords = $Action -in @('rotate-passwords', 'reset-all')
$doMfa       = $Action -in @('reset-mfa', 'reset-all')

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
                $bodyFile = [System.IO.Path]::GetTempFileName()
                $bodyObj | ConvertTo-Json -Depth 5 | Set-Content $bodyFile -Encoding UTF8
                $result = az rest --method PATCH `
                    --uri "https://graph.microsoft.com/v1.0/users/$upn" `
                    --body "@$bodyFile" `
                    --headers "Content-Type=application/json" 2>&1
                $exitCode = $LASTEXITCODE
                Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
                if ($exitCode -eq 0) {
                    Write-Host "    Password rotated" -ForegroundColor Green
                    $newPasswords[$userKey] = $newPwd
                    $stats.PasswordSuccess++
                } else {
                    Write-Host "    ERROR: Password update failed - $result" -ForegroundColor Red
                    $stats.PasswordError++
                }
            } catch {
                Write-Host "    ERROR: $_" -ForegroundColor Red
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
# Update user_credentials.json with new passwords
# ═══════════════════════════════════════════════════════════════════════════════

if ($doPasswords -and $newPasswords.Count -gt 0 -and -not $WhatIfPreference) {
    foreach ($userKey in $newPasswords.Keys) {
        $credentials.users.$userKey.password = $newPasswords[$userKey]
    }

    # Update metadata
    $credentials.generated_at = (Get-Date -Format "o")
    if ($EventName) {
        $credentials | Add-Member -NotePropertyName "last_event" -NotePropertyValue $EventName -Force
    }
    $credentials | Add-Member -NotePropertyName "last_action" -NotePropertyValue $Action -Force

    $credentials | ConvertTo-Json -Depth 10 | Set-Content $CredentialsFile -Encoding UTF8
    Write-Host ""
    Write-Host "  ✓ Updated $CredentialsFile" -ForegroundColor Green
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
        Write-Host "    - UserAuthenticationMethod.ReadWrite.All permission on service principal" -ForegroundColor White
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

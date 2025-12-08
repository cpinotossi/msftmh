#Requires -Version 5.1
<#
.SYNOPSIS
    Deploys and runs Oracle ADB performance tests from AKS

.DESCRIPTION
    This script automates the deployment and execution of performance tests against ODAA ADB.
    It handles all the manual steps from the original walkthrough:
    - Connects to AKS cluster
    - Deploys adbping performance test job
    - Runs the tests and displays results
    - Optionally runs connping for additional metrics

.PARAMETER UserName
    Your assigned username (e.g., user01, user02)

.PARAMETER ADBPassword
    Password for the ODAA ADB instance

.PARAMETER ADBConnectionString
    TNS connection string for your ODAA ADB instance

.PARAMETER AKSResourceGroup
    Name of the AKS resource group (default: auto-detected from username)

.PARAMETER AKSClusterName
    Name of the AKS cluster (default: auto-detected from username)

.PARAMETER Subscription
    Azure subscription name for AKS (default: auto-detected)

.PARAMETER SkipAKSConnection
    Skip AKS connection (use if already connected)

.PARAMETER TestType
    Type of test to run: 'adbping', 'connping', or 'both' (default: 'adbping')

.PARAMETER TestDuration
    Duration of the test in seconds (default: 90)

.PARAMETER Threads
    Number of concurrent threads for adbping (default: 3)

.PARAMETER Cleanup
    Remove test jobs after completion

.EXAMPLE
    .\Deploy-PerfTest.ps1 -UserName "user01" -ADBPassword "Welcome1234#" -ADBConnectionString "(description= ...)"

.EXAMPLE
    .\Deploy-PerfTest.ps1 -UserName "user01" -ADBPassword "Welcome1234#" -ADBConnectionString "(description= ...)" -TestType "both"

.NOTES
    Author: ODAA MicroHack Team
    This script simplifies Challenge 5: Performance Testing
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Your assigned username (e.g., user01)")]
    [string]$UserName,
    
    [Parameter(Mandatory = $true, HelpMessage = "Password for ODAA ADB instance")]
    [string]$ADBPassword,
    
    [Parameter(Mandatory = $true, HelpMessage = "TNS connection string for ODAA ADB")]
    [string]$ADBConnectionString,
    
    [Parameter(Mandatory = $false)]
    [string]$AKSResourceGroup = "",
    
    [Parameter(Mandatory = $false)]
    [string]$AKSClusterName = "",
    
    [Parameter(Mandatory = $false)]
    [string]$Subscription = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipAKSConnection,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("adbping", "connping", "both")]
    [string]$TestType = "both",
    
    [Parameter(Mandatory = $false)]
    [int]$TestDuration = 90,
    
    [Parameter(Mandatory = $false)]
    [int]$Threads = 3,
    
    [Parameter(Mandatory = $false)]
    [switch]$Cleanup
)

# ============================================================================
# Configuration
# ============================================================================
$ErrorActionPreference = "Stop"
$Namespace = "adb-perf-test"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Step {
    param([string]$Message, [string]$Icon = "🔄")
    Write-Host "`n$Icon $Message" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor DarkGray
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor White
}

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Test-Prerequisites {
    Write-Step "Checking Prerequisites" "🔍"
    
    $required = @("az", "kubectl")
    $missing = @()
    
    foreach ($cmd in $required) {
        if (Test-Command $cmd) {
            Write-Success "$cmd is installed"
        }
        else {
            Write-ErrorMsg "$cmd is NOT installed"
            $missing += $cmd
        }
    }
    
    if ($missing.Count -gt 0) {
        throw "Missing prerequisites: $($missing -join ', '). Please install them first."
    }
}

function Connect-ToAKS {
    param(
        [string]$ResourceGroup,
        [string]$ClusterName,
        [string]$SubscriptionName
    )
    
    Write-Step "Connecting to AKS Cluster" "⚓"
    
    if ($SubscriptionName) {
        Write-Info "Setting subscription to: $SubscriptionName"
        az account set --subscription $SubscriptionName
    }
    
    Write-Info "Getting AKS credentials for cluster: $ClusterName"
    az aks get-credentials -g $ResourceGroup -n $ClusterName --overwrite-existing
    
    $namespaces = kubectl get namespaces --no-headers 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to connect to AKS cluster"
    }
    
    Write-Success "Connected to AKS cluster: $ClusterName"
}

function Initialize-Namespace {
    Write-Step "Setting up Namespace" "📦"
    
    $existingNs = kubectl get namespace $Namespace --ignore-not-found -o name 2>&1
    if (-not $existingNs) {
        Write-Info "Creating namespace: $Namespace"
        kubectl create namespace $Namespace
    }
    else {
        Write-Info "Namespace already exists: $Namespace"
    }
    
    Write-Success "Namespace ready: $Namespace"
}

function Remove-ExistingJobs {
    Write-Step "Cleaning up existing jobs" "🧹"
    
    kubectl delete job adbping-performance-test -n $Namespace --ignore-not-found 2>&1 | Out-Null
    kubectl delete job connping-performance-test -n $Namespace --ignore-not-found 2>&1 | Out-Null
    
    Write-Success "Existing jobs cleaned up"
}

function Deploy-ADBPingTest {
    param(
        [string]$Password,
        [string]$TNSString,
        [int]$Duration,
        [int]$ThreadCount
    )
    
    Write-Step "Deploying ADBPing Performance Test" "🚀"
    
    # Generate job YAML inline (no external template dependency)
    $jobYaml = @"
apiVersion: batch/v1
kind: Job
metadata:
  name: adbping-performance-test
  namespace: $Namespace
spec:
  template:
    spec:
      containers:
      - name: adbping-tester
        image: odaamh.azurecr.io/adb-nettest:v2.1
        command: ["/bin/bash"]
        args:
        - -c
        - |
          echo "Oracle ADB Performance Test"
          echo "=============================="
          adbping -u "admin" -p "$Password" -o -l "$TNSString" -c java -t $ThreadCount -d $Duration
          echo ""
          echo "Performance test completed!"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      restartPolicy: Never
  backoffLimit: 3
"@
    
    # Create a temporary job file (cross-platform temp path)
    $tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
    $tempJobFile = Join-Path $tempDir "adbping-job-temp.yaml"
    $jobYaml | Set-Content $tempJobFile -Encoding UTF8
    
    Write-Info "Deploying adbping job..."
    kubectl apply -f $tempJobFile -n $Namespace
    
    # Clean up temp file
    Remove-Item $tempJobFile -Force
    
    Write-Success "ADBPing job deployed"
}

function Deploy-ConnPingTest {
    param(
        [string]$Password,
        [string]$TNSString,
        [int]$Duration
    )
    
    Write-Step "Deploying ConnPing Performance Test" "🚀"
    
    # Generate job YAML inline (no external template dependency)
    $jobYaml = @"
apiVersion: batch/v1
kind: Job
metadata:
  name: connping-performance-test
  namespace: $Namespace
spec:
  template:
    spec:
      containers:
      - name: connping-tester
        image: odaamh.azurecr.io/connping:v1.2
        command: ["/bin/bash"]
        args:
        - -c
        - |
          echo "Oracle ADB Connping Performance Test"
          echo "=============================="
          connping -ss -l "admin/$Password@$TNSString" --period=$Duration
          echo ""
          echo "Connping test completed!"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      restartPolicy: Never
  backoffLimit: 3
"@
    
    # Create a temporary job file (cross-platform temp path)
    $tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
    $tempJobFile = Join-Path $tempDir "connping-job-temp.yaml"
    $jobYaml | Set-Content $tempJobFile -Encoding UTF8
    
    Write-Info "Deploying connping job..."
    kubectl apply -f $tempJobFile -n $Namespace
    
    # Clean up temp file
    Remove-Item $tempJobFile -Force
    
    Write-Success "ConnPing job deployed"
}

function Wait-ForJobCompletion {
    param(
        [string]$JobName,
        [int]$TimeoutSeconds = 300
    )
    
    Write-Step "Waiting for $JobName to complete" "⏳"
    
    $startTime = Get-Date
    $completed = $false
    
    while (-not $completed) {
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        if ($elapsed -gt $TimeoutSeconds) {
            throw "Job $JobName timed out after $TimeoutSeconds seconds"
        }
        
        $status = kubectl get job $JobName -n $Namespace -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>&1
        $failed = kubectl get job $JobName -n $Namespace -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>&1
        
        if ($status -eq "True") {
            $completed = $true
            Write-Success "$JobName completed successfully"
        }
        elseif ($failed -eq "True") {
            throw "Job $JobName failed"
        }
        else {
            Write-Info "Job running... (elapsed: $([math]::Round($elapsed))s)"
            Start-Sleep -Seconds 10
        }
    }
}

function Get-JobResults {
    param([string]$JobName)
    
    Write-Step "Retrieving $JobName Results" "📊"
    
    $logs = kubectl logs job/$JobName -n $Namespace 2>&1
    
    Write-Host "`n" -NoNewline
    Write-Host "=" * 60 -ForegroundColor Yellow
    Write-Host "  RAW OUTPUT: $JobName" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Yellow
    Write-Host $logs
    Write-Host "=" * 60 -ForegroundColor Yellow
    
    # Return logs for parsing
    return $logs
}

function Parse-ADBPingResults {
    param([string]$Logs)
    
    $results = @{
        Pass = "N/A"
        Fail = "N/A"
        AvgLatency = "N/A"
        MedianLatency = "N/A"
        P95Latency = "N/A"
        P99Latency = "N/A"
        MinLatency = "N/A"
        MaxLatency = "N/A"
    }
    
    # Parse "Pass: 341760 Fail: 0"
    if ($Logs -match "Pass:\s*(\d+)\s+Fail:\s*(\d+)") {
        $results.Pass = $Matches[1]
        $results.Fail = $Matches[2]
    }
    
    # Parse "SQL Execution Time(ms) : Min:0.543 Max:89.571 Avg:0.747 Median:0.653 Perc90:0.762 Perc95:0.778 Perc99:0.891"
    if ($Logs -match "SQL Execution Time\(ms\)\s*:\s*Min:([\d.]+)\s+Max:([\d.]+)\s+Avg:([\d.]+)\s+Median:([\d.]+).*Perc95:([\d.]+)\s+Perc99:([\d.]+)") {
        $results.MinLatency = $Matches[1]
        $results.MaxLatency = $Matches[2]
        $results.AvgLatency = $Matches[3]
        $results.MedianLatency = $Matches[4]
        $results.P95Latency = $Matches[5]
        $results.P99Latency = $Matches[6]
    }
    
    return $results
}

function Parse-ConnPingResults {
    param([string]$Logs)
    
    $results = @{
        ConnectMean = "N/A"
        OciPingMean = "N/A"
        DualPingMean = "N/A"
    }
    
    # Parse "connect mean=111.78"
    if ($Logs -match "connect\s+mean=([\d.]+)") {
        $results.ConnectMean = $Matches[1]
    }
    
    # Parse "ociping mean=0.95"
    if ($Logs -match "ociping\s+mean=([\d.]+)") {
        $results.OciPingMean = $Matches[1]
    }
    
    # Parse "dualping mean=1.00"
    if ($Logs -match "dualping\s+mean=([\d.]+)") {
        $results.DualPingMean = $Matches[1]
    }
    
    return $results
}

function Show-FormattedSummary {
    param(
        [hashtable]$ADBPingResults,
        [hashtable]$ConnPingResults,
        [string]$TestType
    )
    
    $line = "─" * 68
    
    Write-Host ""
    Write-Host $line -ForegroundColor Cyan
    Write-Host "                    PERFORMANCE TEST SUMMARY" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
    
    if ($ADBPingResults) {
        Write-Host "ADBPING RESULTS" -ForegroundColor White
        Write-Host $line -ForegroundColor Cyan
        Write-Host "  Requests:        $($ADBPingResults.Pass) pass / $($ADBPingResults.Fail) fail"
        Write-Host "  Avg Latency:     $($ADBPingResults.AvgLatency) ms"
        Write-Host "  Median Latency:  $($ADBPingResults.MedianLatency) ms"
        Write-Host "  P95 Latency:     $($ADBPingResults.P95Latency) ms"
        Write-Host "  P99 Latency:     $($ADBPingResults.P99Latency) ms"
        Write-Host "  Min/Max:         $($ADBPingResults.MinLatency) / $($ADBPingResults.MaxLatency) ms"
        Write-Host $line -ForegroundColor Cyan
    }
    
    if ($ConnPingResults) {
        Write-Host "CONNPING RESULTS" -ForegroundColor White
        Write-Host $line -ForegroundColor Cyan
        Write-Host "  OCI Ping:        $($ConnPingResults.OciPingMean) ms"
        Write-Host "  Dual Ping:       $($ConnPingResults.DualPingMean) ms"
        Write-Host "  Connect Time:    $($ConnPingResults.ConnectMean) ms"
        Write-Host $line -ForegroundColor Cyan
    }
    
    Write-Host "BENCHMARKS: OCI/SQL < 2ms = Good | Connect < 150ms = Good" -ForegroundColor DarkGray
    Write-Host $line -ForegroundColor Cyan
}

function Remove-TestJobs {
    Write-Step "Cleaning up test jobs" "🧹"
    
    kubectl delete job adbping-performance-test -n $Namespace --ignore-not-found 2>&1 | Out-Null
    kubectl delete job connping-performance-test -n $Namespace --ignore-not-found 2>&1 | Out-Null
    
    Write-Success "Test jobs removed"
}

# ============================================================================
# Main Script
# ============================================================================

try {
    Write-Host "`n" -NoNewline
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║     ODAA Performance Test Deployment Script              ║" -ForegroundColor Magenta
    Write-Host "║     Challenge 5: Measure Network Performance             ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    
    # Check prerequisites
    Test-Prerequisites
    
    # Auto-detect resource group and cluster name if not provided
    if (-not $AKSResourceGroup) {
        $AKSResourceGroup = "aks-$UserName"
        Write-Info "Auto-detected AKS Resource Group: $AKSResourceGroup"
    }
    
    if (-not $AKSClusterName) {
        $AKSClusterName = "aks-$UserName"
        Write-Info "Auto-detected AKS Cluster Name: $AKSClusterName"
    }
    
    # Connect to AKS if not skipped
    if (-not $SkipAKSConnection) {
        Connect-ToAKS -ResourceGroup $AKSResourceGroup -ClusterName $AKSClusterName -SubscriptionName $Subscription
    }
    else {
        Write-Info "Skipping AKS connection (assuming already connected)"
    }
    
    # Initialize namespace
    Initialize-Namespace
    
    # Clean up existing jobs
    Remove-ExistingJobs
    
    # Variables to store results for summary
    $adbpingResults = $null
    $connpingResults = $null
    
    # Run tests based on TestType
    if ($TestType -eq "adbping" -or $TestType -eq "both") {
        Deploy-ADBPingTest -Password $ADBPassword -TNSString $ADBConnectionString -Duration $TestDuration -ThreadCount $Threads
        Wait-ForJobCompletion -JobName "adbping-performance-test" -TimeoutSeconds 300
        $adbpingLogs = Get-JobResults -JobName "adbping-performance-test"
        $adbpingResults = Parse-ADBPingResults -Logs $adbpingLogs
    }
    
    if ($TestType -eq "connping" -or $TestType -eq "both") {
        Deploy-ConnPingTest -Password $ADBPassword -TNSString $ADBConnectionString -Duration $TestDuration
        Wait-ForJobCompletion -JobName "connping-performance-test" -TimeoutSeconds 600
        $connpingLogs = Get-JobResults -JobName "connping-performance-test"
        $connpingResults = Parse-ConnPingResults -Logs $connpingLogs
    }
    
    # Show formatted summary
    Show-FormattedSummary -ADBPingResults $adbpingResults -ConnPingResults $connpingResults -TestType $TestType
    
    # Cleanup if requested
    if ($Cleanup) {
        Remove-TestJobs
    }
    
    Write-Host "`n" -NoNewline
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║     ✅ Performance Tests Completed Successfully!         ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
}
catch {
    Write-Host "`n" -NoNewline
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║     ❌ Deployment Failed                                 ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host "`nError: $_" -ForegroundColor Red
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify you're logged into Azure: az login" -ForegroundColor White
    Write-Host "  2. Verify AKS connection: kubectl get nodes" -ForegroundColor White
    Write-Host "  3. Check if adb-perf-test namespace exists: kubectl get ns" -ForegroundColor White
    Write-Host "  4. Check job status: kubectl get jobs -n adb-perf-test" -ForegroundColor White
    exit 1
}

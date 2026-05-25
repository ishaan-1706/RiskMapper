# RiskMapper - Main Entry Point
# Comprehensive TCP port scanner with parallel execution, logging, and risk analysis

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$IP = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Ports = "common",
    
    [Parameter(Mandatory=$false)]
    [string]$Format = "CSV"
)

# Set up script root and load configuration
$scriptRoot = $PSScriptRoot
. "$scriptRoot\config.ps1"

# Load all modules
. "$scriptRoot\modules\InputHandler.ps1"
. "$scriptRoot\modules\ScannerEngine.ps1"
. "$scriptRoot\modules\ParallelScanner.ps1"
. "$scriptRoot\modules\ResultAggregator.ps1"
. "$scriptRoot\modules\Exporter.ps1"
. "$scriptRoot\modules\Logger.ps1"
. "$scriptRoot\modules\SeverityTagger.ps1"

function Invoke-PortManagerScan {
    param(
        [string]$TargetIP,
        [string]$PortsInput,
        [string]$ExportFormat
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  RiskMapper" -ForegroundColor Cyan
    Write-Host "  TCP Port Scanner" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Initialize logging if enabled
    $logger = $null
    if ($Config.EnableLogging) {
        $logger = Initialize-Logger -LogDir $Config.LogsDir
        Remove-OldLogs -LogDir $Config.LogsDir -RetentionDays $Config.LogRetentionDays
    }
    
    $scanStartTime = Get-Date
    
    try {
        # Determine execution mode and validate input
        if ([string]::IsNullOrWhiteSpace($TargetIP)) {
            # Interactive mode
            $userInput = Get-UserInput -Config $Config
            $targetIP = $userInput.IP
            $portList = $userInput.Ports
        }
        else {
            # Parameter mode - validate format
            try {
                Write-Host "Validating parameters..." -ForegroundColor Gray
                Write-Host "  Target IP: $TargetIP" -ForegroundColor White
                Write-Host "  Ports: $PortsInput" -ForegroundColor White
                
                $targetIP = Get-ValidIP $TargetIP
                $portList = Get-ValidPorts -PortInput $PortsInput -Config $Config
                
                if ($ExportFormat -ne "CSV" -and $ExportFormat -ne "JSON") {
                    throw "Invalid export format: '$ExportFormat'. Must be 'CSV' or 'JSON'"
                }
                Write-Host "Parameters validated successfully" -ForegroundColor Green
            }
            catch {
                throw "Parameter validation failed: $_"
            }
        }
        
        # Log scan start
        if ($logger) {
            Start-ScanLog -LogFile $logger.LogFile -Target $targetIP -PortCount $portList.Count
        }
        
        # Run the scan (parallel or sequential based on thread count)
        try {
            Write-Host "Initiating port scan..." -ForegroundColor Cyan
            
            if ($Config.DefaultThreadCount -gt 1) {
                Write-Host "Mode: Parallel (max $($Config.DefaultThreadCount) concurrent)" -ForegroundColor Gray
                $rawResults = Invoke-PortScanParallel -IP $targetIP -Ports $portList -Timeout $Config.DefaultTimeout -MaxConcurrent $Config.DefaultThreadCount -RetryCount $Config.DefaultRetryCount -Logger $logger -ErrorAction Stop
            }
            else {
                Write-Host "Mode: Sequential" -ForegroundColor Gray
                $rawResults = Invoke-PortScan -IP $targetIP -Ports $portList -Timeout $Config.DefaultTimeout -RetryCount $Config.DefaultRetryCount -Logger $logger -ErrorAction Stop
            }
        }
        catch {
            throw "Port scanning failed: $_"
        }
        
        # Format results
        $results = Format-ScanResults -RawResults $rawResults
        
        # Add severity tags if enabled
        if ($Config.EnableSeverityAnalysis) {
            $results = Add-SeverityToResults -Results $results -CriticalPorts $Config.CriticalPorts
        }
        
        # Show summary
        $summary = Get-ScanSummary -Results $results
        Show-ScanSummary -Summary $summary
        
        # Show severity analysis if enabled
        if ($Config.EnableSeverityAnalysis) {
            Show-SeverityAnalysis -Results $results
            $riskScore = Get-RiskScore -Results $results
            $riskLevel = Get-RiskLevel -Score $riskScore
            Write-Host "Overall Risk Level: $riskLevel (Score: $riskScore/100)" -ForegroundColor Cyan
        }
        
        # Log scan end with duration
        if ($logger) {
            $scanEndTime = Get-Date
            $duration = [int]($scanEndTime - $scanStartTime).TotalSeconds
            Stop-ScanLog -LogFile $logger.LogFile -Target $targetIP -OpenPorts $summary.OpenPorts -ClosedPorts $summary.ClosedPorts -DurationSeconds $duration
        }
        
        # Export results
        try {
            Write-Host "Exporting results..." -ForegroundColor Gray
            $exportSuccess = Export-ScanResults -Results $results `
                                               -IP $targetIP `
                                               -ResultsDir $Config.ResultsDir `
                                               -Format $ExportFormat
        }
        catch {
            $exportSuccess = $false
            if ($logger) {
                Write-ScanError -LogFile $logger.LogFile -Target $targetIP -ErrorMessage "Export failed: $_"
            }
            throw "Export failed: $_"
        }
        
        if ($exportSuccess) {
            Write-Host "[SUCCESS] Scan completed successfully" -ForegroundColor Green
            Write-Host "Summary: $($summary.OpenPorts) open, $($summary.ClosedPorts) closed" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "[WARNING] Scan completed but export was unsuccessful" -ForegroundColor Yellow
            if ($logger) {
                Write-ScanError -LogFile $logger.LogFile -Target $targetIP -ErrorMessage "Export returned false"
            }
            return $false
        }
    }
    catch {
        Write-Host "`nError: $_" -ForegroundColor Red
        if ($logger) {
            Write-ScanError -LogFile $logger.LogFile -Target $targetIP -ErrorMessage $_
        }
        return $false
    }
}

# Main execution
$success = Invoke-PortManagerScan -TargetIP $IP -PortsInput $Ports -ExportFormat $Format

if (-not $success) {
    exit 1
}

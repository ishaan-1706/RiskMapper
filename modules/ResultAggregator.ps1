# ResultAggregator Module
#
# Purpose: Formats and aggregates scan results into readable summaries
#
# This module provides result formatting:
# - Converts raw scan data into structured objects
# - Generates summary statistics (open, closed, timeout counts)
# - Displays formatted output to console
# - Prepares results for export to CSV/JSON
#
# Functions:
#   Format-ScanResults - Convert raw results to formatted objects
#   Get-ScanSummary - Calculate summary statistics
#   Show-ScanSummary - Display summary to console

function New-ScanResult {
    <#
    .SYNOPSIS
    Creates a structured scan result object.
    #>
    param(
        [string]$IP,
        [int]$Port,
        [string]$Status,
        [string]$Timestamp
    )
    
    return [PSCustomObject]@{
        IP = $IP
        Port = $Port
        Status = $Status
        Timestamp = $Timestamp
    }
}

function Format-ScanResults {
    <#
    .SYNOPSIS
    Takes raw scan results and formats them for display/export.
    #>
    param([array]$RawResults)
    
    $formattedResults = @()
    
    foreach ($result in $RawResults) {
        $formattedResults += New-ScanResult -IP $result.IP -Port $result.Port `
                                             -Status $result.Status -Timestamp $result.Timestamp
    }
    
    return $formattedResults
}

function Get-ScanSummary {
    <#
    .SYNOPSIS
    Generates a summary of scan results.
    #>
    param([array]$Results)
    
    $openPorts = @($Results | Where-Object { $_.Status -eq 'OPEN' })
    $closedPorts = @($Results | Where-Object { $_.Status -eq 'CLOSED' })
    
    $summary = @{
        TotalScanned = $Results.Count
        OpenPorts = $openPorts.Count
        ClosedPorts = $closedPorts.Count
        OpenPortList = ($openPorts.Port | Sort-Object) -join ', '
    }
    
    return $summary
}

function Show-ScanSummary {
    <#
    .SYNOPSIS
    Displays summary in console with severity breakdown.
    #>
    param([hashtable]$Summary)
    
    Write-Host "`n=== Scan Summary ===" -ForegroundColor Cyan
    Write-Host "Total ports scanned: $($Summary.TotalScanned)" -ForegroundColor White
    Write-Host "Open ports: $($Summary.OpenPorts)" -ForegroundColor Green
    Write-Host "Closed ports: $($Summary.ClosedPorts)" -ForegroundColor Gray
    
    if ($Summary.OpenPorts -gt 0) {
        Write-Host "Open port(s): $($Summary.OpenPortList)" -ForegroundColor Green
    }
    Write-Host ""
}

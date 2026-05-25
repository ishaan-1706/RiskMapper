# Exporter Module
#
# Purpose: Saves scan results to files (CSV and JSON formats)
#
# This module provides data export functionality:
# - Export to CSV (Excel-compatible format)
# - Export to JSON (programmatic access)
# - Automatic filename generation with timestamps
# - Creates output directories as needed
# - Preserves all result metadata including severity
#
# Functions:
#   Export-ToCSV - Export results to CSV file
#   Export-ToJSON - Export results to JSON file
#   Export-ScanResults - Main export orchestration function
#   Get-ExportFilename - Generate timestamped filenames

function Export-ToCSV {
    <#
    .SYNOPSIS
    Exports scan results to CSV file with severity tags.
    
    .PARAMETER Results
    Array of scan result objects
    
    .PARAMETER OutputPath
    Path to save CSV file
    #>
    param(
        [array]$Results,
        [string]$OutputPath
    )
    
    try {
        # Ensure severity is included if it exists
        $exportData = $Results | Select-Object -Property IP, Port, Status, Severity, Timestamp
        $exportData | Export-Csv -Path $OutputPath -NoTypeInformation -Force
        Write-Host "Results exported to CSV: $OutputPath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error exporting to CSV: $_" -ForegroundColor Red
        return $false
    }
}

function Export-ToJSON {
    <#
    .SYNOPSIS
    Exports scan results to JSON file.
    
    .PARAMETER Results
    Array of scan result objects
    
    .PARAMETER OutputPath
    Path to save JSON file
    #>
    param(
        [array]$Results,
        [string]$OutputPath
    )
    
    try {
        $Results | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Force
        Write-Host "Results exported to JSON: $OutputPath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error exporting to JSON: $_" -ForegroundColor Red
        return $false
    }
}

function Get-ExportFilename {
    <#
    .SYNOPSIS
    Generates a timestamped filename for export.
    
    .PARAMETER IP
    Target IP address
    
    .PARAMETER Format
    Export format (CSV, JSON)
    #>
    param(
        [string]$IP,
        [string]$Format = 'CSV'
    )
    
    $timestamp = (Get-Date -Format "yyyyMMdd_HHmmss")
    $ipClean = $IP -replace '\W', '_'
    
    $ext = if ($Format -eq 'JSON') { 'json' } else { 'csv' }
    
    return "scan_${ipClean}_${timestamp}.${ext}"
}

function Export-ScanResults {
    <#
    .SYNOPSIS
    Main export function - saves results based on format preference.
    
    .PARAMETER Results
    Array of scan results
    
    .PARAMETER IP
    Target IP (for filename)
    
    .PARAMETER ResultsDir
    Directory to save results
    
    .PARAMETER Format
    Export format (CSV or JSON)
    #>
    param(
        [array]$Results,
        [string]$IP,
        [string]$ResultsDir,
        [string]$Format = 'CSV'
    )
    
    if (-not (Test-Path $ResultsDir)) {
        New-Item -Path $ResultsDir -ItemType Directory -Force | Out-Null
    }
    
    $filename = Get-ExportFilename -IP $IP -Format $Format
    $outputPath = Join-Path $ResultsDir $filename
    
    if ($Format -eq 'JSON') {
        return Export-ToJSON -Results $Results -OutputPath $outputPath
    }
    else {
        return Export-ToCSV -Results $Results -OutputPath $outputPath
    }
}

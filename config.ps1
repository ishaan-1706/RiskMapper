# RiskMapper Configuration
# Settings for port scanning, logging, and risk analysis

# Default settings
$script:Config = @{
    # Scanning
    DefaultTimeout = 2000           # milliseconds per port
    DefaultThreadCount = 10         # concurrent threads for parallel scanning
    DefaultRetryCount = 1           # retry attempts on timeout/failure
    
    # Port presets
    CommonPorts = @(21, 22, 25, 53, 80, 110, 143, 443, 445, 3306, 3389, 5432, 8080, 8443)
    CriticalPorts = @(22, 445, 3389, 1433, 3306)  # ports that require immediate attention
    
    # Output
    DefaultExportFormat = 'CSV'     # CSV, JSON
    ResultsDir = "$PSScriptRoot\results\scans"
    LogsDir = "$PSScriptRoot\results\logs"
    
    # Logging
    EnableLogging = $true           # enable detailed scan logging
    LogFile = "$PSScriptRoot\results\logs\scan_log.txt"
    LogRetentionDays = 30           # keep logs for 30 days
    
    # Severity Analysis
    EnableSeverityAnalysis = $true  # enable port risk classification
}

# Ensure output directories exist
if (-not (Test-Path $Config.ResultsDir)) {
    New-Item -Path $Config.ResultsDir -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path $Config.LogsDir)) {
    New-Item -Path $Config.LogsDir -ItemType Directory -Force | Out-Null
}

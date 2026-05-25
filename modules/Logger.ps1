# Logger Module
#
# Purpose: Comprehensive audit logging of all scanning activities
#
# This module provides detailed logging:
# - Records scan start/end events with timestamps
# - Logs individual port results as scanned
# - Logs errors and timeouts for troubleshooting
# - Automatic cleanup of logs older than retention period
# - Searchable log file with consistent format
# - No external dependencies (uses native PowerShell)
#
# Functions:
#   Initialize-Logger - Create logging directory and log file
#   Write-LogEntry - Core logging function
#   Start-ScanLog - Record scan initiation
#   Stop-ScanLog - Record scan completion
#   Write-PortResult - Record individual port result
#   Write-ScanError - Record error events
#   Remove-OldLogs - Remove aged logs

function Initialize-Logger {
    <#
    .SYNOPSIS
    Sets up the logger and ensures log directory exists.
    
    .PARAMETER LogDir
    Directory where log files will be stored
    #>
    param([string]$LogDir)
    
    if (-not (Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    
    return @{
        LogDir = $LogDir
        LogFile = (Join-Path $LogDir "scan_log.txt")
        CurrentScanID = (New-Guid).Guid.Substring(0, 8)
    }
}

function Get-LogTimestamp {
    <#
    .SYNOPSIS
    Returns formatted timestamp for logging.
    #>
    return (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

function Write-LogEntry {
    <#
    .SYNOPSIS
    Writes a single log entry to the log file.
    
    .PARAMETER LogFile
    Path to log file
    
    .PARAMETER EventType
    Type of event: SCAN_START, SCAN_END, PORT_SCANNED, ERROR, TIMEOUT, INFO
    
    .PARAMETER Target
    Target IP being scanned
    
    .PARAMETER Port
    Port number (if applicable)
    
    .PARAMETER Status
    Result status (OPEN, CLOSED, ERROR, TIMEOUT)
    
    .PARAMETER Message
    Additional context or error message
    #>
    param(
        [string]$LogFile,
        [string]$EventType,
        [string]$Target,
        [int]$Port = $null,
        [string]$Status = "",
        [string]$Message = ""
    )
    
    try {
        $timestamp = Get-LogTimestamp
        
        $logEntry = "[${timestamp}] [${EventType}]"
        
        if ($Target) { $logEntry += " IP=$Target" }
        if ($Port) { $logEntry += " PORT=$Port" }
        if ($Status) { $logEntry += " STATUS=$Status" }
        if ($Message) { $logEntry += " MSG=$Message" }
        
        Add-Content -Path $LogFile -Value $logEntry -Force
    }
    catch {
        Write-Host "[LOG ERROR] Failed to write log: $_" -ForegroundColor Red
    }
}

function Start-ScanLog {
    <#
    .SYNOPSIS
    Logs the start of a scan session.
    #>
    param(
        [string]$LogFile,
        [string]$Target,
        [int]$PortCount
    )
    
    $message = "Starting scan of $Target for $PortCount port(s)"
    Write-LogEntry -LogFile $LogFile -EventType "SCAN_START" -Target $Target -Message $message
}

function Stop-ScanLog {
    <#
    .SYNOPSIS
    Logs the end of a scan session with summary.
    #>
    param(
        [string]$LogFile,
        [string]$Target,
        [int]$OpenPorts,
        [int]$ClosedPorts,
        [int]$DurationSeconds
    )
    
    $message = "Completed. Open: $OpenPorts, Closed: $ClosedPorts, Duration: ${DurationSeconds}s"
    Write-LogEntry -LogFile $LogFile -EventType "SCAN_END" -Target $Target -Message $message
}

function Write-PortResult {
    <#
    .SYNOPSIS
    Logs individual port scan results.
    #>
    param(
        [string]$LogFile,
        [string]$Target,
        [int]$Port,
        [string]$Status
    )
    
    Write-LogEntry -LogFile $LogFile -EventType "PORT_SCANNED" -Target $Target -Port $Port -Status $Status
}

function Write-ScanError {
    <#
    .SYNOPSIS
    Logs scan errors.
    #>
    param(
        [string]$LogFile,
        [string]$Target,
        [string]$ErrorMessage
    )
    
    Write-LogEntry -LogFile $LogFile -EventType "ERROR" -Target $Target -Message $ErrorMessage
}

function Write-Timeout {
    <#
    .SYNOPSIS
    Logs port timeout events.
    #>
    param(
        [string]$LogFile,
        [string]$Target,
        [int]$Port,
        [int]$TimeoutMS
    )
    
    $message = "Timeout after ${TimeoutMS}ms"
    Write-LogEntry -LogFile $LogFile -EventType "TIMEOUT" -Target $Target -Port $Port -Message $message
}

function Remove-OldLogs {
    <#
    .SYNOPSIS
    Removes log files older than retention days.
    
    .PARAMETER LogDir
    Directory containing logs
    
    .PARAMETER RetentionDays
    How many days to keep logs (default: 30)
    #>
    param(
        [string]$LogDir,
        [int]$RetentionDays = 30
    )
    
    if (-not (Test-Path $LogDir)) { return }
    
    try {
        $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
        $oldLogs = Get-ChildItem -Path $LogDir -Filter "*.txt" | Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        foreach ($log in $oldLogs) {
            Remove-Item -Path $log.FullName -Force
        }
    }
    catch {
        Write-Host "[LOG CLEANUP ERROR] $_" -ForegroundColor Red
    }
}

function Get-ScanLog {
    <#
    .SYNOPSIS
    Retrieves log entries (optionally filtered).
    
    .PARAMETER LogFile
    Path to log file
    
    .PARAMETER Target
    Optional: filter by target IP
    
    .PARAMETER EventType
    Optional: filter by event type
    #>
    param(
        [string]$LogFile,
        [string]$Target = "",
        [string]$EventType = ""
    )
    
    if (-not (Test-Path $LogFile)) {
        return @()
    }
    
    $entries = @(Get-Content -Path $LogFile)
    
    if ($Target) {
        $entries = $entries | Where-Object { $_ -like "*IP=$Target*" }
    }
    
    if ($EventType) {
        $entries = $entries | Where-Object { $_ -like "*[$EventType]*" }
    }
    
    return $entries
}

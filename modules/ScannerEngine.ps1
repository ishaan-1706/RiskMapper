# ScannerEngine Module
#
# Purpose: Performs TCP port scanning using .NET Socket connections
#
# This module provides serial (non-parallel) port scanning:
# - Uses .NET TcpClient for TCP connection testing
# - Supports configurable timeouts per port
# - Implements automatic retry logic on failure
# - Returns detailed status for each port (OPEN, CLOSED, TIMEOUT)
#
# Functions:
#   Test-Port - Tests a single port on target host
#   Invoke-PortScan - Scans multiple ports sequentially

function Test-Port {
    <#
    .SYNOPSIS
    Tests if a single port is open on target IP.
    
    .PARAMETER IP
    Target IP address
    
    .PARAMETER Port
    Target port number
    
    .PARAMETER Timeout
    Timeout in milliseconds
    
    .PARAMETER Retry
    Number of retries on failure (default: 0)
    
    .PARAMETER Logger
    Optional logger for retry logging
    #>
    param(
        [string]$IP,
        [int]$Port,
        [int]$Timeout = 2000,
        [int]$Retry = 0,
        [hashtable]$Logger = $null
    )
    
    $attempts = 0
    $maxAttempts = 1 + $Retry
    
    while ($attempts -lt $maxAttempts) {
        $attempts++
        
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.ReceiveTimeout = $Timeout
            $tcpClient.SendTimeout = $Timeout
            
            # Try to connect
            $result = $tcpClient.BeginConnect($IP, $Port, $null, $null)
            
            # Wait for connection attempt
            $success = $result.AsyncWaitHandle.WaitOne($Timeout, $false)
            
            if ($success) {
                try {
                    $tcpClient.EndConnect($result)
                    $isOpen = $true
                }
                catch {
                    $isOpen = $false
                }
            }
            else {
                $isOpen = $false
            }
            
            $tcpClient.Close()
            
            # If successful on first try or any attempt, return
            if ($isOpen) {
                if ($attempts -gt 1 -and $Logger) {
                    # Log successful retry
                }
                return $isOpen
            }
            
            # If this wasn't the last attempt, retry
            if ($attempts -lt $maxAttempts) {
                if ($Logger -and $Logger.LogFile) {
                    $message = "Port $port timeout, retry attempt $attempts/$maxAttempts"
                }
                Start-Sleep -Milliseconds 100
                continue
            }
            
            return $isOpen
        }
        catch {
            if ($attempts -lt $maxAttempts) {
                Start-Sleep -Milliseconds 100
                continue
            }
            return $false
        }
    }
    
    return $false
}

function Invoke-PortScan {
    <#
    .SYNOPSIS
    Scans multiple ports on target IP with optional retry logic.
    
    .PARAMETER IP
    Target IP address
    
    .PARAMETER Ports
    Array of ports to scan
    
    .PARAMETER Timeout
    Timeout per port in milliseconds
    
    .PARAMETER RetryCount
    Number of retries on timeout (default: 0)
    
    .PARAMETER Logger
    Optional logger object for logging results
    #>
    param(
        [string]$IP,
        [int[]]$Ports,
        [int]$Timeout = 2000,
        [int]$RetryCount = 0,
        [hashtable]$Logger = $null
    )
    
    $results = @()
    $totalPorts = $Ports.Count
    $scanned = 0
    
    Write-Host "`nScanning $IP on $totalPorts port(s)..." -ForegroundColor Cyan
    
    foreach ($port in $Ports) {
        $scanned++
        Write-Host -NoNewline "`r[${scanned}/${totalPorts}] Scanning port $port... "
        
        $isOpen = Test-Port -IP $IP -Port $Port -Timeout $Timeout -Retry $RetryCount -Logger $Logger
        
        $status = if ($isOpen) { "OPEN" } else { "CLOSED" }
        $color = if ($isOpen) { "Green" } else { "Gray" }
        
        Write-Host $status -ForegroundColor $color
        
        # Log individual port result if logger is provided
        if ($Logger -and $Logger.LogFile) {
            Write-PortResult -LogFile $Logger.LogFile -Target $IP -Port $port -Status $status
        }
        
        $results += @{
            IP = $IP
            Port = $port
            Status = $status
            Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
    }
    
    Write-Host ""
    return $results
}

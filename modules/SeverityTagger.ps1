# SeverityTagger Module
#
# Purpose: Classifies ports by security risk level and calculates overall risk
#
# This module provides port risk assessment:
# - Classifies individual ports into severity tiers (CRITICAL, HIGH, MEDIUM, LOW)
# - Calculates numerical risk score (0-100 scale)
# - Generates risk level text (SAFE, LOW, MEDIUM, HIGH, CRITICAL)
# - Displays risk analysis focused on open ports only
# - Includes severity in CSV/JSON exports
# - Helps prioritize remediation efforts
#
# Functions:
#   Get-PortSeverity - Classify single port by risk
#   Add-SeverityToResults - Add severity to all results
#   Get-SeverityColor - Color for console display
#   Format-SeverityBadge - Text badge for severity
#   Show-SeverityAnalysis - Display risk analysis
#   Get-RiskScore - Calculate numerical risk score
#   Get-RiskLevel - Convert score to text level

function Get-PortSeverity {
    <#
    .SYNOPSIS
    Determines the severity level of a port.
    
    .PARAMETER Port
    Port number to classify
    
    .PARAMETER CriticalPorts
    Array of critical port numbers
    #>
    param(
        [int]$Port,
        [int[]]$CriticalPorts = @(22, 445, 3389, 1433, 3306)
    )
    
    # Critical ports - direct access to system
    if ($Port -in $CriticalPorts) {
        return "CRITICAL"
    }
    
    # High-risk ports - common attack vectors
    $highRiskPorts = @(
        # File Transfer
        20, 21,                    # FTP
        115,                       # SFTP
        445,                       # SMB/CIFS (also critical, included for reference)
        
        # Terminal Access
        23,                        # Telnet (unencrypted)
        
        # Email
        25, 109, 110, 143, 587,    # SMTP, POP2, POP3, IMAP, SMTP-TLS
        993, 995,                  # IMAPS, POP3S
        
        # Directory Services
        135, 139, 389, 636,        # RPC, NetBIOS, LDAP, LDAPS
        
        # Databases
        1433, 1521, 5432, 5984,    # SQL Server, Oracle, PostgreSQL, CouchDB
        6379, 27017, 27018, 28017  # Redis, MongoDB
        
        # Remote Access
        3389, 5800, 5900,          # RDP, VNC
        
        # Web Services (Alternative)
        8080, 8443, 8888, 9000     # HTTP/HTTPS alternatives, Jupyter
        
        # Search & Indexing
        9200, 9300,                # Elasticsearch
        
        # Development Tools
        9500, 10000                # Java debug, networking
    )

    
    if ($Port -in $highRiskPorts) {
        return "HIGH"
    }
    
    # Medium-risk ports - services with exposure
    $mediumRiskPorts = @(
        # DNS
        53,                        # DNS query/response
        
        # Web Services
        80, 443,                   # HTTP, HTTPS
        8000, 8001, 8002, 8003,    # Django, Flask, development
        8008, 8009,                # HTTP alternative, Tomcat
        
        # Development Frameworks
        3000, 3001, 3100, 3500,    # Node.js development ports
        5000, 5001, 5005,          # Flask, Python development
        5173, 5174, 5175,          # Vite dev server
        
        # Container & Virtualization
        2375, 2376,                # Docker daemon
        5555,                      # Android Debug Bridge
        
        # Databases (read-only or less critical)
        3306,                      # MySQL
        5432,                      # PostgreSQL (also high, included)
        
        # Network Services
        67, 68,                    # DHCP
        123,                       # NTP (time sync)
        161, 162,                  # SNMP
        
        # VPN & Proxy
        1194, 1723, 500, 4500,     # OpenVPN, PPTP, IPSec, IPSec NAT-T
        8118, 3128,                # Proxy services
        
        # Miscellaneous Services
        9000, 9001, 9005,          # PHP-FPM, various services
        10000, 10001               # WebMin, Webmin SSL
    )
    
    if ($Port -in $mediumRiskPorts) {
        return "MEDIUM"
    }
    
    # Everything else is low risk
    return "LOW"
}

function Add-SeverityToResults {
    <#
    .SYNOPSIS
    Adds severity tags to scan results.
    
    .PARAMETER Results
    Array of scan result objects
    
    .PARAMETER CriticalPorts
    Array of critical port numbers
    #>
    param(
        [array]$Results,
        [int[]]$CriticalPorts = @(22, 445, 3389, 1433, 3306)
    )
    
    foreach ($result in $Results) {
        $severity = Get-PortSeverity -Port $result.Port -CriticalPorts $CriticalPorts
        $result | Add-Member -MemberType NoteProperty -Name "Severity" -Value $severity -Force
    }
    
    return $Results
}

function Get-SeverityColor {
    <#
    .SYNOPSIS
    Returns console color for severity level.
    #>
    param([string]$Severity)
    
    switch ($Severity) {
        "CRITICAL" { return "Red" }
        "HIGH"     { return "Yellow" }
        "MEDIUM"   { return "Cyan" }
        "LOW"      { return "Gray" }
        default    { return "White" }
    }
}

function Format-SeverityBadge {
    <#
    .SYNOPSIS
    Formats severity for console display.
    #>
    param([string]$Severity)
    
    switch ($Severity) {
        "CRITICAL" { return "[!!!]" }
        "HIGH"     { return "[!!]" }
        "MEDIUM"   { return "[!]" }
        "LOW"      { return "[-]" }
        default    { return "[?]" }
    }
}

function Show-SeverityAnalysis {
    <#
    .SYNOPSIS
    Displays severity breakdown of scan results showing only OPEN ports.
    #>
    param([array]$Results)
    
    # Filter only OPEN ports
    $openResults = @($Results | Where-Object { $_.Status -eq "OPEN" })
    
    $critical = @($openResults | Where-Object { $_.Severity -eq "CRITICAL" })
    $high = @($openResults | Where-Object { $_.Severity -eq "HIGH" })
    $medium = @($openResults | Where-Object { $_.Severity -eq "MEDIUM" })
    $low = @($openResults | Where-Object { $_.Severity -eq "LOW" })
    
    Write-Host "`n=== Risk Analysis (Open Ports) ===" -ForegroundColor Cyan
    
    if ($critical.Count -gt 0) {
        Write-Host "CRITICAL open ports: $($critical.Count)" -ForegroundColor Red
        Write-Host "  Ports: $(($critical.Port | Sort-Object) -join ', ')" -ForegroundColor Red
    }
    
    if ($high.Count -gt 0) {
        Write-Host "HIGH risk open ports: $($high.Count)" -ForegroundColor Yellow
        Write-Host "  Ports: $(($high.Port | Sort-Object) -join ', ')" -ForegroundColor Yellow
    }
    
    if ($medium.Count -gt 0) {
        Write-Host "MEDIUM risk open ports: $($medium.Count)" -ForegroundColor Cyan
        Write-Host "  Ports: $(($medium.Port | Sort-Object) -join ', ')" -ForegroundColor Cyan
    }
    
    if ($low.Count -gt 0) {
        Write-Host "LOW risk open ports: $($low.Count)" -ForegroundColor Gray
        Write-Host "  Ports: $(($low.Port | Sort-Object) -join ', ')" -ForegroundColor Gray
    }
    
    if ($critical.Count -eq 0 -and $high.Count -eq 0) {
        Write-Host "No critical or high-risk open ports detected" -ForegroundColor Green
    }
    elseif ($critical.Count -gt 0) {
        Write-Host "`n[ALERT] CRITICAL ports are open - immediate action required" -ForegroundColor Red
    }
    elseif ($high.Count -gt 0) {
        Write-Host "`n[WARNING] HIGH-risk ports are open - review access controls" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

function Get-RiskScore {
    <#
    .SYNOPSIS
    Calculates overall risk score for the scan.
    Score: 0 (safe) to 100 (very dangerous)
    #>
    param([array]$Results)
    
    $critical = @($Results | Where-Object { $_.Severity -eq "CRITICAL" -and $_.Status -eq "OPEN" })
    $high = @($Results | Where-Object { $_.Severity -eq "HIGH" -and $_.Status -eq "OPEN" })
    $medium = @($Results | Where-Object { $_.Severity -eq "MEDIUM" -and $_.Status -eq "OPEN" })
    
    $score = 0
    $score += $critical.Count * 35  # Critical = 35 points each
    $score += $high.Count * 15      # High = 15 points each
    $score += $medium.Count * 5     # Medium = 5 points each
    
    return [Math]::Min($score, 100)
}

function Get-RiskLevel {
    <#
    .SYNOPSIS
    Returns text risk level based on score.
    #>
    param([int]$Score)
    
    if ($Score -ge 70) { return "CRITICAL" }
    elseif ($Score -ge 50) { return "HIGH" }
    elseif ($Score -ge 25) { return "MEDIUM" }
    elseif ($Score -gt 0) { return "LOW" }
    else { return "SAFE" }
}

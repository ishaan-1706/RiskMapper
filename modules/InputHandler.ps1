# InputHandler Module
# 
# Purpose: Validates and parses user input for target IP addresses and port ranges
#
# This module provides functions to:
# - Validate IP address format and reserved address detection
# - Parse and validate port specifications (ranges, lists, single ports)
# - Provide helpful error messages for invalid input
#
# Functions:
#   Get-ValidIP - Validates IP address format and values
#   Get-ValidPorts - Parses and validates port specifications
#   Get-UserInput - Interactive prompts for IP and port input

function Get-ValidIP {
    <#
    .SYNOPSIS
    Validates and returns a single IP address.
    
    .PARAMETER IPAddress
    The IP address to validate (e.g., "192.168.1.1")
    #>
    param([string]$IPAddress)
    
    if ([string]::IsNullOrWhiteSpace($IPAddress)) {
        throw "IP address cannot be empty"
    }
    
    try {
        $ip = [ipaddress]$IPAddress
        # Validate it's not reserved or invalid
        if ($ip.Address -eq 0 -or $ip.Address -eq 4294967295) {
            throw "Invalid IP address: $IPAddress (reserved address)"
        }
        return $IPAddress
    }
    catch [System.FormatException] {
        throw "Invalid IP address format: '$IPAddress'. Expected format: 192.168.1.1"
    }
    catch {
        throw "IP validation error: $_"
    }
}

function Get-ValidPorts {
    <#
    .SYNOPSIS
    Validates and parses port input.
    
    .PARAMETER PortInput
    Can be:
      - Single port: "80"
      - Range: "80-443"
      - Comma-separated: "22,80,443"
      - Preset: "common" (uses config presets)
    #>
    param([string]$PortInput, [hashtable]$Config)
    
    if ([string]::IsNullOrWhiteSpace($PortInput)) {
        throw "Port input cannot be empty. Specify a port, range (80-443), list (22,80,443), or preset (common)"
    }
    
    $ports = @()
    
    # Check for presets
    if ($PortInput -eq 'common') {
        return $Config.CommonPorts | Sort-Object
    }
    elseif ($PortInput -match '^(\d+)-(\d+)$') {
        # Range: "80-443"
        $start = [int]$matches[1]
        $end = [int]$matches[2]
        
        if ($start -lt 1 -or $end -gt 65535) {
            throw "Invalid port range: $PortInput. Ports must be between 1 and 65535"
        }
        if ($start -gt $end) {
            throw "Invalid port range: $PortInput. Start port ($start) is greater than end port ($end)"
        }
        
        $portCount = $end - $start + 1
        if ($portCount -gt 1000) {
            Write-Host "[WARNING] Large port range detected ($portCount ports). This may take a long time." -ForegroundColor Yellow
        }
        
        return @($start..$end)
    }
    elseif ($PortInput -match ',') {
        # Comma-separated: "22,80,443"
        $portList = $PortInput -split ',' | ForEach-Object { $_.Trim() }
        foreach ($p in $portList) {
            if ([string]::IsNullOrWhiteSpace($p)) {
                throw "Invalid port list: empty port specified"
            }
            if (-not ($p -match '^\d+$')) {
                throw "Invalid port in list: '$p' (must be a number)"
            }
            $portNum = [int]$p
            if ($portNum -lt 1 -or $portNum -gt 65535) {
                throw "Invalid port: $portNum (must be between 1 and 65535)"
            }
            $ports += $portNum
        }
        return $ports | Sort-Object -Unique
    }
    else {
        # Single port
        if (-not ($PortInput -match '^\d+$')) {
            throw "Invalid port: '$PortInput' (must be a number)"
        }
        $portNum = [int]$PortInput
        if ($portNum -lt 1 -or $portNum -gt 65535) {
            throw "Invalid port: $PortInput (must be between 1 and 65535)"
        }
        return @($portNum)
    }
}

function Get-UserInput {
    <#
    .SYNOPSIS
    Prompts user for target IP and port range.
    #>
    param([hashtable]$Config)
    
    Write-Host "`n=== Port Manager - Input ===" -ForegroundColor Cyan
    
    # Get target IP
    do {
        $ip = Read-Host "Enter target IP (e.g., 192.168.1.1)"
        try {
            $ip = Get-ValidIP $ip
            break
        }
        catch {
            Write-Host "Error: $_" -ForegroundColor Red
        }
    } while ($true)
    
    # Get port range
    do {
        Write-Host "Port input options:"
        Write-Host "  - Single: '80'"
        Write-Host "  - Range: '80-443'"
        Write-Host "  - List: '22,80,443'"
        Write-Host "  - Preset: 'common' (standard ports)"
        
        $portInput = Read-Host "Enter port range or preset"
        try {
            $ports = Get-ValidPorts -PortInput $portInput -Config $Config
            break
        }
        catch {
            Write-Host "Error: $_" -ForegroundColor Red
        }
    } while ($true)
    
    Write-Host "Ready to scan $ip on $($ports.Count) port(s)" -ForegroundColor Green
    
    return @{
        IP = $ip
        Ports = $ports
    }
}

# RiskMapper - TCP Port Scanner

A comprehensive PowerShell-based TCP port scanner with parallel execution, comprehensive logging, and security risk analysis. Built for network diagnostics and vulnerability assessment.

## Overview

RiskMapper is not just a port scanner—it's a security-aware scanning tool that goes beyond identifying open ports. It classifies ports by risk level, maintains detailed audit logs, and uses intelligent parallel execution for 5-6x performance improvement over serial scanning.

### Key Differentiators

- **Risk-Aware**: Classifies ports as CRITICAL, HIGH, MEDIUM, or LOW based on security implications
- **Parallel by Default**: 10 concurrent threads provide 5-6x speedup vs sequential scanning
- **Audit-Ready**: Comprehensive logging with timestamps, event types, and 30-day retention
- **Smart Retries**: Automatic retry logic improves accuracy on unreliable networks
- **Modular Architecture**: 7 independent modules for scanning, logging, analysis, and export
- **Flexible Export**: CSV and JSON formats for integration with other tools

## Features

- **Fast Scanning**: Parallel port scanning (default 10 concurrent threads) - 5-6x faster than sequential
- **Reliable**: Automatic retry logic on timeout or failure  
- **Comprehensive Logging**: Detailed audit trail of all scanning activities with 30-day retention
- **Security Analysis**: Port risk classification (CRITICAL, HIGH, MEDIUM, LOW) with risk scoring
- **Export Options**: Save results to CSV or JSON for analysis and archiving
- **User-Friendly**: Interactive or parameter-based modes for different workflows
- **Flexible Configuration**: Customize timeouts, thread count, ports, and logging behavior

## Architecture

### Module Organization

RiskMapper is built as a modular pipeline:

```
Input Validation → Port Scanning → Result Aggregation → Risk Analysis → Export → Logging
   (InputHandler)   (Scanner)      (Aggregator)      (SeverityTagger)  (Exporter) (Logger)
```

### Core Modules

#### 1. **scanner.ps1** (Orchestrator)
The main entry point that coordinates all operations.

**Responsibilities:**
- Parse command-line parameters or prompt for interactive input
- Initialize the logging system
- Validate user inputs through InputHandler
- Execute scan (serial or parallel based on config)
- Aggregate and display results
- Calculate risk scores and severity analysis
- Export results to files
- Log completion events

**Flow:**
1. Validate parameters
2. Initialize logger
3. Call scanner (Invoke-PortScan or Invoke-PortScanParallel)
4. Aggregate results
5. Apply severity tags
6. Display summary and risk analysis
7. Export to CSV/JSON
8. Log completion

#### 2. **config.ps1** (Configuration)
Single source of truth for all settings.

**Contains:**
- `DefaultTimeout`: Timeout per port (ms) - default 2000
- `DefaultThreadCount`: Parallel thread limit - default 10
- `DefaultRetryCount`: Retry attempts on failure - default 1
- `CommonPorts`: Preset list of common ports (14 ports by default)
- `CriticalPorts`: List of security-critical ports
- `LogRetentionDays`: Delete logs older than this - default 30
- `ResultsDir`: Where to save CSV/JSON files
- `LogsDir`: Where to save logs
- `EnableLogging`: Toggle audit logging
- `EnableSeverityAnalysis`: Toggle risk classification

#### 3. **InputHandler.ps1** (Validation)
Validates and parses user input before scanning begins.

**Functions:**
- `Get-ValidIP`: Validates IP address format and reserved addresses
  - Checks format: `[ipaddress]` casting
  - Rejects reserved addresses (0.0.0.0, 255.255.255.255)
  - Provides helpful error messages
  
- `Get-ValidPorts`: Parses port specifications
  - Handles presets: `common`
  - Handles ranges: `80-443`
  - Handles lists: `22,80,443`
  - Handles single ports: `443`
  - Validates bounds (1-65535)
  
- `Get-UserInput`: Interactive prompts
  - Asks for target IP
  - Asks for port specification
  - Asks for export format

#### 4. **ScannerEngine.ps1** (Serial Scanner)
Performs TCP connection testing sequentially.

**Core Logic:**
- Uses `.NET System.Net.Sockets.TcpClient`
- Non-blocking connection attempts with timeout
- Retry loop for failed connections
- Returns: OPEN, CLOSED, or TIMEOUT

**Functions:**
- `Test-Port`: Tests single port with retry support
  - Creates TcpClient
  - Attempts BeginConnect (non-blocking)
  - Waits for timeout period
  - Returns success/failure
  
- `Invoke-PortScan`: Scans port list sequentially
  - Loops through ports one at a time
  - Calls Test-Port for each
  - Collects results

**Performance:** ~2 seconds per port with 2000ms timeout

#### 5. **ParallelScanner.ps1** (Parallel Scanner)
High-performance concurrent scanning using PowerShell jobs.

**Architecture:**
- Uses `Start-Job` for concurrent execution
- Maintains job queue for management
- Limits concurrent jobs to `DefaultThreadCount`
- Processes completions and resubmits pending jobs

**Functions:**
- `Test-PortAsync`: Asynchronous port test
  - Runs in PowerShell job context
  - Embeds retry logic
  - Returns result to parent process
  
- `Invoke-PortScanParallel`: Orchestrates parallel scanning
  - Creates initial batch of jobs (up to MaxConcurrent)
  - Waits for job completions
  - Receives results
  - Submits next batch from queue
  - Manages progress display

**Performance:** ~5 seconds for 14 ports (5-6x faster)

**Thread Count Selection:**
- 1-3: Conservative (slow/unreliable networks)
- 5-10: **Recommended** (balanced)
- 10-20: Fast (local networks only)
- 20+: Aggressive (risk of overload)

#### 6. **ResultAggregator.ps1** (Result Formatting)
Converts raw scan data into readable output and statistics.

**Functions:**
- `Format-ScanResults`: Converts raw results to PSCustomObjects
  - Creates structured objects with IP, Port, Status, Severity
  - Preserves all metadata
  
- `Get-ScanSummary`: Calculates statistics
  - Counts open/closed/timeout ports
  - Lists open ports
  - Calculates duration
  
- `Show-ScanSummary`: Displays to console
  - Formatted table of results
  - Summary statistics
  - Open port listing

#### 7. **Exporter.ps1** (CSV/JSON Export)
Saves results to files for analysis and archiving.

**Functions:**
- `Export-ToCSV`: Exports to comma-separated values
  - Columns: IP, Port, Status, Severity, Timestamp
  - Excel-compatible format
  
- `Export-ToJSON`: Exports to JSON
  - Preserves all metadata
  - Programmatic access
  
- `Export-ScanResults`: Main export orchestrator
  - Determines format from config
  - Calls appropriate export function
  - Creates results directory if needed
  - Returns success/failure
  
- `Get-ExportFilename`: Generates timestamped names
  - Format: `scan_IP_DATE_TIME.csv`
  - Example: `scan_192_168_1_1_20260525_043228.csv`

#### 8. **Logger.ps1** (Comprehensive Logging)
Maintains detailed audit trail of all scanning activities.

**Event Types:**
- `SCAN_START`: Scan initiation with port count
- `SCAN_END`: Scan completion with open/closed counts and duration
- `PORT_SCANNED`: Individual port result (IP, port, status)
- `ERROR`: Errors during scanning
- `TIMEOUT`: Timeout events on specific ports

**Log Format:**
```
[2026-05-25 04:32:28] [PORT_SCANNED] IP=192.168.1.1 PORT=80 STATUS=OPEN
[2026-05-25 04:32:28] [SCAN_END] IP=192.168.1.1 MSG=Completed. Open: 2, Closed: 1, Duration: 5s
```

**Functions:**
- `Initialize-Logger`: Creates log directory and file
- `Write-LogEntry`: Core logging function with formatting
- `Start-ScanLog`: Logs scan start
- `Stop-ScanLog`: Logs scan completion with stats
- `Write-PortResult`: Logs individual port result
- `Write-ScanError`: Logs errors
- `Write-Timeout`: Logs timeout events
- `Remove-OldLogs`: Cleanup logs older than retention period

**Cleanup:** Automatic removal of logs >30 days old

#### 9. **SeverityTagger.ps1** (Risk Classification)
Classifies ports by security risk and calculates overall risk score.

**Port Classifications:**

| Severity | Ports | Risk Points |
|----------|-------|-------------|
| **CRITICAL** | 22, 445, 3389, 1433, 3306 | 35 |
| **HIGH** | FTP, Telnet, Mail, LDAP, Databases, Elasticsearch | 15 |
| **MEDIUM** | DNS, HTTP, HTTPS, Dev ports | 5 |
| **LOW** | Everything else | 0 |

**Functions:**
- `Get-PortSeverity`: Classifies individual port
  - Returns severity level
  - Based on port number
  
- `Add-SeverityToResults`: Adds severity property to all results
  
- `Get-RiskScore`: Calculates overall risk (0-100)
  - Critical: 35 points each
  - High: 15 points each
  - Medium: 5 points each
  - Max: 100
  
- `Get-RiskLevel`: Converts score to text
  - 0 = SAFE
  - 1-24 = LOW
  - 25-49 = MEDIUM
  - 50-69 = HIGH
  - 70-100 = CRITICAL
  
- `Show-SeverityAnalysis`: Displays risk breakdown
  - Groups by severity level
  - Shows only OPEN ports
  - Highlights critical findings

## System Requirements

- Windows PowerShell 5.0 or later (or PowerShell Core 7+)
- .NET Framework 4.5+ (typically included with Windows)
- Administrator privileges (recommended for some network scenarios)

## Installation

1. Clone this repository:
```bash
git clone https://github.com/ishaan-1706/RiskMapper.git
cd RiskMapper
```

2. (Optional) Review and customize `config.ps1`

## Quick Start

### Interactive Mode (Recommended)

```powershell
cd RiskMapper
.\scanner.ps1
```

The script will prompt you for:
1. Target IP address
2. Port specification (preset, range, list, or single)
3. Export format (CSV or JSON)

### Parameter Mode (Automation)

```powershell
# Scan common ports
.\scanner.ps1 -IP "192.168.1.1" -Ports "common" -Format CSV

# Scan port range
.\scanner.ps1 -IP "10.0.0.5" -Ports "80-443" -Format CSV

# Scan specific ports with JSON output
.\scanner.ps1 -IP "192.168.1.100" -Ports "22,80,443,3389" -Format JSON
```

## Port Input Options

| Format | Example | Description |
|--------|---------|-------------|
| Preset | `common` | 14 predefined common ports |
| Single | `80` | One port |
| Range | `80-443` | Inclusive range |
| List | `22,80,443,3306` | Comma-separated |

## Configuration

Edit `config.ps1` to customize behavior:

```powershell
$script:Config = @{
    # Scanning behavior
    DefaultTimeout = 2000           # Milliseconds per port
    DefaultThreadCount = 10         # Parallel threads
    DefaultRetryCount = 1           # Retry attempts
    
    # Presets
    CommonPorts = @(21, 22, ...)    # Common ports list
    CriticalPorts = @(22, 445, ...) # Critical ports
    
    # Output
    DefaultExportFormat = 'CSV'
    ResultsDir = "$PSScriptRoot\results\scans"
    LogsDir = "$PSScriptRoot\results\logs"
    
    # Features
    EnableLogging = $true
    LogRetentionDays = 30
    EnableSeverityAnalysis = $true
}
```

## Results Files

### CSV Format

```csv
"IP","Port","Status","Severity","Timestamp"
"192.168.1.1","22","CLOSED","CRITICAL","2026-05-25 04:32:28"
"192.168.1.1","80","OPEN","MEDIUM","2026-05-25 04:32:24"
"192.168.1.1","443","OPEN","MEDIUM","2026-05-25 04:32:24"
```

### Scan Log

```
[2026-05-25 04:32:24] [SCAN_START] IP=192.168.1.1 MSG=Starting scan of 192.168.1.1 for 3 port(s)
[2026-05-25 04:32:24] [PORT_SCANNED] IP=192.168.1.1 PORT=80 STATUS=OPEN
[2026-05-25 04:32:24] [PORT_SCANNED] IP=192.168.1.1 PORT=443 STATUS=OPEN
[2026-05-25 04:32:28] [PORT_SCANNED] IP=192.168.1.1 PORT=22 STATUS=CLOSED
[2026-05-25 04:32:28] [SCAN_END] IP=192.168.1.1 MSG=Completed. Open: 2, Closed: 1, Duration: 5s
```

## Performance

| Scenario | Time | Details |
|----------|------|---------|
| Serial (1 port) | ~2 seconds | Single threaded with 2s timeout |
| Serial (14 ports) | ~28 seconds | 14 common ports sequentially |
| **Parallel (14 ports)** | **~5 seconds** | 14 ports with 10 concurrent threads |
| **Speedup** | **5-6x faster** | Parallel vs serial |

## Risk Levels

| Level | Score | Meaning | Examples |
|-------|-------|---------|----------|
| **CRITICAL** | 35 pts | Should never be open | 22 (SSH), 3389 (RDP), 445 (SMB), 1433 (SQL), 3306 (MySQL) |
| **HIGH** | 15 pts | Common attack vectors | 21 (FTP), 23 (Telnet), 25 (SMTP), 389 (LDAP), 5432 (PostgreSQL), 6379 (Redis), 27017 (MongoDB) |
| **MEDIUM** | 5 pts | Services with exposure | 53 (DNS), 80 (HTTP), 443 (HTTPS), 3000-8888 (Dev) |
| **LOW** | 0 pts | Low-risk services | Everything else |

## Examples

### Scan your local router
```powershell
.\scanner.ps1 -IP "192.168.1.1" -Ports "common"
```

### Check a server for critical ports
```powershell
.\scanner.ps1 -IP "server.example.com" -Ports "22,3389,445,1433,3306"
```

### Full port sweep (comprehensive)
```powershell
.\scanner.ps1 -IP "192.168.1.100" -Ports "1-1024"
```

### Export results as JSON
```powershell
.\scanner.ps1 -IP "10.0.0.50" -Ports "common" -Format JSON
```

### Scan with conservative settings
```powershell
# Edit config.ps1:
# DefaultThreadCount = 1
# DefaultTimeout = 5000
# DefaultRetryCount = 2
.\scanner.ps1 -IP "slow-device.local" -Ports "common"
```

## Troubleshooting

### Scanning is very slow
- Decrease `DefaultTimeout` in config.ps1 (try 1000-1500)
- Increase `DefaultThreadCount` (if network is fast)
- Use smaller port ranges

### Many timeout or connection errors
- Increase `DefaultTimeout` in config.ps1 (try 3000-5000)
- Enable `DefaultRetryCount = 2`
- Decrease `DefaultThreadCount` (try 3-5)
- Check target is reachable: `ping <IP>`

### Access denied errors
- Run PowerShell as Administrator
- Some networks require elevated privileges

### Results not exporting
- Verify `results/scans/` directory exists (should create automatically)
- Check disk space available
- Verify write permissions to results directory

## File Structure

```
RiskMapper/
├── scanner.ps1                      Main orchestrator
├── config.ps1                       Configuration
├── LICENSE                          MIT License
├── README.md                        This file
│
├── modules/
│   ├── InputHandler.ps1             Input validation
│   ├── ScannerEngine.ps1            Serial scanner
│   ├── ParallelScanner.ps1          Parallel scanner
│   ├── ResultAggregator.ps1         Result formatting
│   ├── Exporter.ps1                 CSV/JSON export
│   ├── Logger.ps1                   Audit logging
│   └── SeverityTagger.ps1           Risk classification
│
└── results/
    ├── scans/                       CSV/JSON export files
    └── logs/                        Scan audit logs
```

## Security Considerations

- This tool performs TCP connection tests only (no packets sent, no scanning)
- Results depend on network configuration and firewall rules
- Some networks may throttle or block port scans
- **Always get permission before scanning networks you don't own**
- Results show network state at scan time (may change immediately after)
- Scan logs may contain sensitive IP information—protect the results directory

## License

MIT License - See LICENSE file

## Contributing

This is a personal project, but feel free to fork and improve!

## Support

For issues or questions, check:
1. `results/logs/scan_log.txt` for detailed events
2. `config.ps1` for configuration options
3. Module headers for function documentation

---

**Version**: 1.0  
**Last Updated**: May 25, 2026  
**Repository**: https://github.com/ishaan-1706/RiskMapper


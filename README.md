# RiskMapper - TCP Port Scanner

A comprehensive PowerShell-based TCP port scanner with parallel execution, comprehensive logging, and security risk analysis.

## Features

- **Fast Scanning**: Parallel port scanning (default 10 concurrent threads) - 5-6x faster than sequential
- **Reliable**: Automatic retry logic on timeout or failure
- **Comprehensive Logging**: Detailed audit trail of all scanning activities with 30-day retention
- **Security Analysis**: Port risk classification (CRITICAL, HIGH, MEDIUM, LOW) with scoring
- **Export Options**: Save results to CSV or JSON for analysis
- **User-Friendly**: Interactive or parameter-based modes
- **Flexible Configuration**: Customize timeouts, thread count, ports, and more

## System Requirements

- Windows PowerShell 5.0 or later (or PowerShell Core 7+)
- .NET Framework 4.5+ (typically included with Windows)
- Administrator privileges (recommended for some network scenarios)

## Installation

1. Download or clone this repository
2. Navigate to the port_manager directory:
```powershell
cd C:\data\port_manager
```
3. (Optional) Review and customize settings in `config.ps1`

## Quick Start

### Interactive Mode (Recommended for First Use)

```powershell
cd C:\data\port_manager
.\scanner.ps1
```

The script will prompt you for:
1. **Target IP**: The IP address to scan (e.g., `192.168.1.1`)
2. **Port Input**: What ports to scan (see "Port Input Options" below)
3. **Export Format**: CSV or JSON (default: CSV)

### Parameter Mode (For Automation/Scripts)

```powershell
# Scan common ports on a specific IP
.\scanner.ps1 -IP "192.168.1.1" -Ports "common" -Format CSV

# Scan a port range
.\scanner.ps1 -IP "10.0.0.5" -Ports "80-443" -Format CSV

# Scan specific ports
.\scanner.ps1 -IP "192.168.1.100" -Ports "22,80,443,3389" -Format JSON

# Scan with retries (set in config.ps1)
.\scanner.ps1 -IP "slow-server.local" -Ports "80,443,3306"
```

## Port Input Options

When prompted for ports, you can use:

| Format | Example | Description |
|--------|---------|-------------|
| Preset | `common` | Scans predefined common ports (see config.ps1) |
| Single | `80` | Scan one port |
| Range | `80-443` | Scan ports 80 through 443 inclusive |
| List | `22,80,443,3306` | Scan specific ports separated by commas |

## Configuration

Edit `config.ps1` to customize behavior:

```powershell
$script:Config = @{
    # Scanning
    DefaultTimeout = 2000           # Milliseconds to wait for each port (default 2s)
    DefaultThreadCount = 10         # Concurrent threads (1 = serial, 10 = parallel)
    DefaultRetryCount = 1           # Retry attempts on timeout/failure
    
    # Port presets
    CommonPorts = @(...)            # Ports scanned when you use "common"
    CriticalPorts = @(...)          # Ports considered critical for risk analysis
    
    # Output
    DefaultExportFormat = 'CSV'     # CSV or JSON
    ResultsDir = "..."              # Where to save CSV/JSON files
    LogsDir = "..."                 # Where to save scan logs
    
    # Logging
    EnableLogging = $true           # Enable detailed logging
    LogRetentionDays = 30           # Delete logs older than 30 days
    
    # Risk Analysis
    EnableSeverityAnalysis = $true  # Classify ports by risk level
}
```

### Recommended Settings

**For Development/Testing (Fast):**
```powershell
DefaultThreadCount = 10     # Maximum parallelism
DefaultRetryCount = 0       # No retries
DefaultTimeout = 1000       # Quick timeout
```

**For Production (Reliable):**
```powershell
DefaultThreadCount = 5      # Moderate concurrency
DefaultRetryCount = 1       # One retry on failure
DefaultTimeout = 5000       # Generous timeout
```

**For Network Analysis (Conservative):**
```powershell
DefaultThreadCount = 1      # Serial (no parallel)
DefaultRetryCount = 2       # Multiple retries
DefaultTimeout = 10000      # Very generous timeout
```

## Thread Count Selection Guide

The `DefaultThreadCount` parameter in `config.ps1` controls parallel scanning performance. Here's how to choose:

### Recommended Values

| Threads | Network Type | Use Case | Speed | Safety |
|---------|--------------|----------|-------|--------|
| **1-3** | Slow/Unreliable | Congested networks, very old devices | Slowest | Safest |
| **5-10** | **Most Networks** | **Default (10) - General purpose** | **5-6x faster** | **Best balance** |
| **10-20** | Fast/Local | Trusted internal networks, modern devices | Very fast | Good |
| **20+** | Powerful systems only | Not recommended for most users | Fastest | Risk of overload |

### Why These Limits?

1. **Network Bandwidth**
   - Each thread opens a TCP connection simultaneously
   - Too many threads = network congestion and timeouts
   - ISPs/firewalls may throttle connections from one source

2. **Target Host Load**
   - The scanned device must handle concurrent connection attempts
   - Port limits per IP exist on some devices
   - Too many threads can cause the target to stop responding

3. **System Resources**
   - Each PowerShell job uses ~10-20 MB RAM
   - 100 threads = 1-2 GB of RAM consumption
   - CPU cores are limited (more threads than cores wastes resources)

4. **Reliability vs Speed**
   - 10 threads: ~5-6x faster, still very reliable
   - 1 thread: Slowest, but works on any network
   - 50+ threads: Only slightly faster, high failure risk

### Performance Comparison

```powershell
# Very safe but slow
DefaultThreadCount = 1      # 28 seconds for 14 ports

# Recommended (default)
DefaultThreadCount = 10     # 5 seconds for 14 ports (5.6x faster)

# Fast but aggressive
DefaultThreadCount = 20     # ~3 seconds for 14 ports (minor improvement)
```

### Adjustment Tips

**If scanning is timing out:**
- Decrease to 5 or 3 threads
- Increase `DefaultTimeout` to 3000-5000ms
- Enable `DefaultRetryCount = 1` or 2

**If you want maximum speed:**
- Use 10 (default) or 15 on modern networks
- Only increase beyond 15 if you have >8 CPU cores
- Always test with a small port range first

**If scanning very slow networks:**
- Use 1-3 threads
- Increase `DefaultTimeout` significantly (5000ms+)
- Use smaller port ranges

## Understanding Results


### Console Output

```
========================================
  Port Manager
  TCP Port Scanner
========================================
Validating parameters...
  Target IP: 192.168.1.1
  Ports: 22,80,443
Parameters validated successfully
Initiating port scan...
Mode: Parallel (max 10 concurrent)

Parallel scanning 192.168.1.1 on 3 port(s) (max 10 concurrent)...
[1/3] Port 80... OPEN
[2/3] Port 443... OPEN
[3/3] Port 22... CLOSED

=== Scan Summary ===
Total ports scanned: 3
Open ports: 2
Closed ports: 1
Open port(s): 80, 443

=== Risk Analysis (Open Ports) ===
MEDIUM risk open ports: 2
  Ports: 80, 443
No critical or high-risk open ports detected

Overall Risk Level: LOW (Score: 10/100)
Exporting results...
Results exported to CSV: C:\data\port_manager\results\scans\scan_192_168_1_1_20260525_043228.csv
[SUCCESS] Scan completed successfully
Summary: 2 open, 1 closed
```

### CSV Export Format

The CSV file contains:
- **IP**: Target IP address
- **Port**: Port number scanned
- **Status**: OPEN, CLOSED, or TIMEOUT
- **Severity**: CRITICAL, HIGH, MEDIUM, or LOW
- **Timestamp**: When the port was scanned

Example:
```csv
"IP","Port","Status","Severity","Timestamp"
"192.168.1.1","22","CLOSED","CRITICAL","2026-05-25 04:32:28"
"192.168.1.1","80","OPEN","MEDIUM","2026-05-25 04:32:24"
"192.168.1.1","443","OPEN","MEDIUM","2026-05-25 04:32:24"
```

### Risk Levels Explained

| Level | Score | Meaning | Examples |
|-------|-------|---------|----------|
| **CRITICAL** | 35 pts each | Ports that should never be open to untrusted networks | 22 (SSH), 3389 (RDP), 445 (SMB), 1433 (SQL Server), 3306 (MySQL) |
| **HIGH** | 15 pts each | Common attack vectors that warrant immediate review | FTP (21), Telnet (23), Mail (25, 110, 143), LDAP (389), PostgreSQL (5432), Redis (6379), MongoDB (27017), Elasticsearch (9200) |
| **MEDIUM** | 5 pts each | Services with potential exposure, monitor access | DNS (53), HTTP (80), HTTPS (443), Development ports (3000-8888) |
| **LOW** | 0 pts | Low-risk ports or services with minimal exposure | Everything else |

**Overall Risk Score**: Sum of all open port risks (max 100)
- 0-24 = LOW
- 25-49 = MEDIUM
- 50-69 = HIGH
- 70-100 = CRITICAL

## File Structure

```
port_manager/
├── scanner.ps1                      Main entry point - run this script
├── config.ps1                       Configuration and settings
├── README.md                        This file
├── ROADMAP.md                       Development phases and history
├── STATUS.md                        Implementation status
│
├── modules/
│   ├── InputHandler.ps1             IP and port input validation
│   ├── ScannerEngine.ps1            Serial (non-parallel) port scanner
│   ├── ParallelScanner.ps1          Parallel port scanner (10 concurrent)
│   ├── ResultAggregator.ps1         Format results and create summaries
│   ├── Exporter.ps1                 Export to CSV/JSON
│   ├── Logger.ps1                   Audit logging system
│   └── SeverityTagger.ps1           Port risk classification
│
└── results/
    ├── scans/                       CSV/JSON export files
    │   ├── scan_IP_DATE_TIME.csv
    │   └── scan_IP_DATE_TIME.json
    │
    └── logs/
        └── scan_log.txt             Complete audit trail of all scans
```

## Module Descriptions

### scanner.ps1 (Main Orchestrator)
The entry point that coordinates all operations:
- Validates parameters or prompts for input
- Initializes logging system
- Runs the scan (serial or parallel based on config)
- Displays results and risk analysis
- Exports to CSV/JSON
- Logs completion

### config.ps1 (Configuration)
Single source of truth for all settings:
- Timeout and thread count
- Port presets (common ports)
- Critical ports for risk analysis
- Logging and export settings

### InputHandler.ps1
Validates user input before scanning:
- IP address format validation
- Reserved address detection
- Port range validation (1-65535)
- Helpful error messages on invalid input

### ScannerEngine.ps1
Serial (non-parallel) port scanner:
- Uses .NET TcpClient for TCP connection testing
- Configurable timeout per port
- Automatic retries on failure
- Returns open/closed/timeout status

### ParallelScanner.ps1
High-performance parallel scanner:
- Uses PowerShell jobs for concurrent scanning
- Default 10 concurrent threads (configurable)
- Job queue management
- 5-6x faster than serial scanning

### ResultAggregator.ps1
Formats and summarizes scan results:
- Creates summary statistics
- Displays results in readable format
- Prepares data for export

### Exporter.ps1
Saves results to files:
- CSV format (Excel-compatible)
- JSON format (programmatic access)
- Timestamped filenames
- Creates results directory if needed

### Logger.ps1
Comprehensive audit logging:
- Logs every scan start/end
- Logs each port result
- Logs errors and timeouts
- Automatic cleanup of old logs (30+ days)
- Searchable log file

### SeverityTagger.ps1
Port risk classification:
- Classifies ports: CRITICAL, HIGH, MEDIUM, LOW
- Calculates overall risk score (0-100)
- Filters analysis to show only open ports
- Includes severity in exports

## Examples

### Example 1: Quick Scan of Common Ports

```powershell
.\scanner.ps1 -IP "192.168.1.1" -Ports "common" -Format CSV
```

Output: Scans 14 predefined common ports, exports to CSV

### Example 2: Scan Specific Range

```powershell
.\scanner.ps1 -IP "10.0.0.1" -Ports "1-1024" -Format CSV
```

Output: Scans all ports 1-1024 (slower, but comprehensive)

### Example 3: Check Critical Ports Only

```powershell
.\scanner.ps1 -IP "server.local" -Ports "22,3389,445,1433,3306" -Format JSON
```

Output: Only checks critical ports, exports to JSON

### Example 4: Run with Custom Timeout (Edit config.ps1 first)

1. Edit `config.ps1` and change `DefaultTimeout = 5000` (5 seconds)
2. Run: `.\scanner.ps1 -IP "slow-network.local" -Ports "80,443"`

## Troubleshooting

### "Cannot find path 'results' directory"
- The script should create it automatically
- If not, create manually: `New-Item -Path results/scans -ItemType Directory`

### "Access denied" errors
- Run PowerShell as Administrator
- Or run with: `powershell -RunAs Administrator`

### Scanning is slow
- Decrease `DefaultTimeout` in config.ps1 (e.g., 1000 instead of 2000)
- Check network connectivity
- Consider using smaller port ranges

### Timeout on many ports
- Some network devices respond slowly
- Increase `DefaultTimeout` in config.ps1
- Enable `DefaultRetryCount` for unreliable networks

### CSV file is empty
- Check if results/scans directory exists
- Verify export format is set correctly
- Check logs in results/logs/scan_log.txt

## Performance

| Scenario | Time | Details |
|----------|------|---------|
| Serial (1 port) | ~2 seconds | Single port with 2s timeout |
| Serial (14 ports) | ~28 seconds | 14 common ports sequentially |
| Parallel (14 ports) | ~5 seconds | 14 ports with 10 concurrent threads |
| Parallel (1000 ports) | ~100-150 seconds | Full well-known port range |

**Speedup**: ~5-6x faster with parallel execution

## Security Considerations

- This tool performs TCP connection tests only (no packets sent)
- Results depend on network configuration and firewall rules
- Some networks may filter or throttle port scans
- Always get permission before scanning networks you don't own
- Results show network state at scan time (may change)
- Scan logs contain sensitive information - protect the results directory

## License

See LICENSE file

## Support

For issues or questions:
1. Check results/logs/scan_log.txt for detailed logs
2. Review config.ps1 settings
3. Verify target IP is reachable: `ping <IP>`
4. Test basic connectivity: `Test-NetConnection <IP> -Port <PORT>`

## Changelog

**Current Version**: All features complete
- Parallel scanning with configurable concurrency
- Comprehensive logging system
- Automatic retry on failure
- Port risk classification and scoring
- CSV/JSON export
- Enhanced input validation with detailed error messages
#   R i s k M a p p e r  
 
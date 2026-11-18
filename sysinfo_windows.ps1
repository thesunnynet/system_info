<#
.SYNOPSIS
    Comprehensive Windows System Information Gathering Script
.DESCRIPTION
    Collects OS, hardware, disk, network, installed applications,
    services, and security configuration. Works on Windows Desktop & Server.
    Run as Administrator for complete data.
#>

param(
    [string]$OutputFile = "System_Full_Report.txt"
)

# Initialize output file
$null = New-Item -Path $OutputFile -ItemType File -Force

function Write-Section {
    param([string]$Title)
    $line = "=" * 80
    $text = "`n$line`n  $Title`n$line"
    Write-Host $text -ForegroundColor Cyan
    Add-Content -Path $OutputFile -Value $text
}

function Write-Result {
    param([string]$Description, [scriptblock]$Command)
    Write-Host "`n--- $Description ---" -ForegroundColor Yellow
    Add-Content -Path $OutputFile -Value "`n--- $Description ---"
    try {
        $result = & $Command | Out-String
        $result | Add-Content -Path $OutputFile
        # Display first 20 lines on screen to avoid flooding
        ($result -split "`n" | Select-Object -First 20) | Write-Host
    } catch {
        $err = "[Error executing: $_]"
        Write-Host $err -ForegroundColor Red
        Add-Content -Path $OutputFile -Value $err
    }
}

# ==============================================================================
# 1. OPERATING SYSTEM & KERNEL
# ==============================================================================
Write-Section "1. OPERATING SYSTEM & SYSTEM INFO"

Write-Result "OS & Computer Info (Get-ComputerInfo)" { 
    Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, 
    OsHardwareAbstractionLayer, CsManufacturer, CsModel, CsTotalPhysicalMemory,
    OsInstallDate, OsArchitecture, CsUserName, CsDNSHostName 
}

Write-Result "OS Caption, Version, Architecture (CIM)" {
    Get-CimInstance -ClassName Win32_OperatingSystem | 
    Select-Object Caption, Version, OSArchitecture, InstallDate, LastBootUpTime
}

Write-Result "Hostname & Uptime" {
    $os = Get-CimInstance Win32_OperatingSystem
    $uptime = (Get-Date) - $os.LastBootUpTime
    "Hostname: $env:COMPUTERNAME"
    "Uptime  : $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
}

Write-Result "System Date/Time" { Get-Date }

# ==============================================================================
# 2. HARDWARE (CPU, MEMORY)
# ==============================================================================
Write-Section "2. HARDWARE INFORMATION"

Write-Result "CPU Details" {
    Get-CimInstance Win32_Processor | 
    Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed, 
    LoadPercentage, Status
}

Write-Result "Memory Usage (Physical)" {
    $os = Get-CimInstance Win32_OperatingSystem
    $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedGB  = $totalGB - $freeGB
    [PSCustomObject]@{
        TotalRAM_GB = $totalGB
        UsedRAM_GB  = $usedGB
        FreeRAM_GB  = $freeGB
        UsagePercent = [math]::Round(($usedGB / $totalGB) * 100, 2)
    }
}

Write-Result "Top 10 Processes by CPU" {
    Get-Process | Sort-Object CPU -Descending | 
    Select-Object -First 10 Name, Id, CPU, WorkingSet
}

# ==============================================================================
# 3. DISK PARTITIONS, FILESYSTEMS & USAGE
# ==============================================================================
Write-Section "3. DISK & FILESYSTEM INFORMATION"

Write-Result "Logical Volumes & Free Space (Get-Volume)" {
    Get-Volume | Where-Object DriveLetter -ne $null | 
    Select-Object DriveLetter, FileSystemLabel, FileSystem, 
    @{N='Size_GB';E={[math]::Round($_.Size/1GB,2)}}, 
    @{N='Free_GB';E={[math]::Round($_.SizeRemaining/1GB,2)}}, 
    HealthStatus
}

Write-Result "Physical Partitions (Get-Partition)" {
    Get-Partition | Select-Object DiskNumber, PartitionNumber, DriveLetter, 
    @{N='Size_GB';E={[math]::Round($_.Size/1GB,2)}}, Type, IsActive
}

Write-Result "Physical Disks (Get-Disk)" {
    Get-Disk | Select-Object Number, FriendlyName, 
    @{N='Size_GB';E={[math]::Round($_.Size/1GB,2)}}, 
    PartitionStyle, HealthStatus, OperationalStatus
}

Write-Result "Mapped Drives (Get-PSDrive)" {
    Get-PSDrive -PSProvider FileSystem | 
    Select-Object Name, @{N='Used_GB';E={[math]::Round($_.Used/1GB,2)}}, 
    @{N='Free_GB';E={[math]::Round($_.Free/1GB,2)}}
}

# ==============================================================================
# 4. NETWORK CONFIGURATION
# ==============================================================================
Write-Section "4. NETWORK CONFIGURATION"

Write-Result "IP Configuration (Get-NetIPConfiguration)" {
    Get-NetIPConfiguration | Select-Object InterfaceAlias, InterfaceDescription,
    @{N='IPv4';E={$_.IPv4Address.IPAddress}}, 
    @{N='Gateway';E={$_.IPv4DefaultGateway.NextHop}},
    @{N='DNS';E={$_.DNSServer.ServerAddresses -join ', '}}
}

Write-Result "Network Adapters (Get-NetAdapter)" {
    Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, 
    LinkSpeed, MacAddress
}

Write-Result "Routing Table (Get-NetRoute)" {
    Get-NetRoute -AddressFamily IPv4 | 
    Select-Object DestinationPrefix, NextHop, InterfaceAlias, RouteMetric
}

Write-Result "Listening Ports & Connections (Get-NetTCPConnection)" {
    Get-NetTCPConnection -State Listen | 
    Select-Object LocalAddress, LocalPort, OwningProcess, 
    @{N='ProcessName';E={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name}}
}

Write-Result "Established Connections" {
    Get-NetTCPConnection -State Established | 
    Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess
}

# ==============================================================================
# 5. INSTALLED APPLICATIONS
# ==============================================================================
Write-Section "5. INSTALLED APPLICATIONS"

Write-Result "64-bit & 32-bit Installed Software (Registry)" {
    $paths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty $paths -ErrorAction SilentlyContinue | 
    Where-Object DisplayName | 
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | 
    Sort-Object DisplayName
}

Write-Result "Windows Store / Appx Packages (Summary)" {
    Get-AppxPackage | Select-Object Name, Version, Publisher | Sort-Object Name
}

Write-Result "Installed Hotfixes (Get-HotFix)" {
    Get-HotFix | Select-Object HotFixID, Description, InstalledOn | 
    Sort-Object InstalledOn -Descending
}

# ==============================================================================
# 6. SYSTEM CONFIGURATION & SERVICES
# ==============================================================================
Write-Section "6. SYSTEM CONFIGURATION & SERVICES"

Write-Result "Running Services" {
    Get-Service | Where-Object Status -eq 'Running' | 
    Select-Object Name, DisplayName, StartType | Sort-Object DisplayName
}

Write-Result "Scheduled Tasks (Ready/Enabled)" {
    Get-ScheduledTask | Where-Object State -eq 'Ready' | 
    Select-Object TaskName, TaskPath, State | Sort-Object TaskName
}

Write-Result "Local Users & Administrators" {
    "--- Local Users ---"
    Get-LocalUser | Select-Object Name, Enabled, LastLogon
    "--- Administrators Group ---"
    Get-LocalGroupMember -Group "Administrators" | Select-Object Name, PrincipalSource
}

Write-Result "Environment Variables (Key Paths)" {
    Get-ChildItem Env: | Where-Object Name -match 'PATH|HOME|SHELL|TEMP' | 
    Select-Object Name, Value
}

# ==============================================================================
# 7. SECURITY & FIREWALL SNAPSHOT
# ==============================================================================
Write-Section "7. SECURITY & FIREWALL SNAPSHOT"

Write-Result "Windows Defender Status" {
    Get-MpComputerStatus | Select-Object AMServiceEnabled, AntivirusEnabled, 
    RealTimeProtectionEnabled, AntivirusSignatureVersion, AntivirusSignatureLastUpdated
}

Write-Result "Firewall Profiles (Get-NetFirewallProfile)" {
    Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
}

Write-Result "Firewall Rules (Enabled, Inbound)" {
    Get-NetFirewallRule -Direction Inbound -Enabled True | 
    Select-Object DisplayName, Action, Profile | Sort-Object DisplayName
}

Write-Result "BitLocker Status (Get-BitLockerVolume)" {
    Get-BitLockerVolume -ErrorAction SilentlyContinue | 
    Select-Object MountPoint, VolumeStatus, EncryptionPercentage, KeyProtector
}

# ==============================================================================
# SCRIPT COMPLETE
# ==============================================================================
$footer = "`n" + ("=" * 80) + "`n  REPORT COMPLETE. Full details saved to: $OutputFile`n" + ("=" * 80)
Write-Host $footer -ForegroundColor Green
Add-Content -Path $OutputFile -Value $footer
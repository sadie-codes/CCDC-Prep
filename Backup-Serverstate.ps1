
# Backup-ServerState.ps1
# Read-only Windows server inventory and configuration snapshot.
# Run on ONE authorized server at a time.
# Does NOT copy arbitrary files, secrets, credentials, or malware artifacts.

$ErrorActionPreference = "Continue"

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$computer = $env:COMPUTERNAME
$outputRoot = Join-Path $PSScriptRoot "ServerSnapshots"
$outputDir = Join-Path $outputRoot "${computer}_${timestamp}"

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

$logFile = Join-Path $outputDir "snapshot-log.txt"

function Save-Section {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    $file = Join-Path $outputDir "$Name.txt"

    try {
        "Snapshot section: $Name" | Out-File $file
        "Collected: $(Get-Date)" | Out-File $file -Append
        "----------------------------------------" | Out-File $file -Append

        & $Command 2>&1 | Out-String -Width 300 |
            Out-File $file -Append

        "SUCCESS: $Name" | Out-File $logFile -Append
    }
    catch {
        "ERROR: $($_.Exception.Message)" |
            Out-File $file -Append

        "FAILED: $Name - $($_.Exception.Message)" |
            Out-File $logFile -Append
    }
}

"Server snapshot started: $(Get-Date)" | Out-File $logFile
"Computer: $computer" | Out-File $logFile -Append

# 1. System information
Save-Section "01-System" {
    Get-ComputerInfo |
        Select-Object CsName, WindowsProductName, WindowsVersion,
        OsBuildNumber, OsArchitecture, CsDomain, CsProcessors,
        CsTotalPhysicalMemory
}

# 2. Network configuration
Save-Section "02-Network" {
    ipconfig /all
}

# 3. Network connections
Save-Section "03-NetworkConnections" {
    Get-NetTCPConnection |
        Select-Object LocalAddress, LocalPort, RemoteAddress,
        RemotePort, State, OwningProcess
}

# 4. Local users
Save-Section "04-LocalUsers" {
    Get-LocalUser |
        Select-Object Name, Enabled, LastLogon, PasswordRequired
}

# 5. Local administrator membership
Save-Section "05-Administrators" {
    Get-LocalGroupMember -Group "Administrators"
}

# 6. Services
Save-Section "06-Services" {
    Get-CimInstance Win32_Service |
        Select-Object Name, DisplayName, State, StartMode, StartName
}

# 7. Firewall profiles
Save-Section "07-FirewallProfiles" {
    Get-NetFirewallProfile |
        Select-Object Name, Enabled, DefaultInboundAction,
        DefaultOutboundAction
}

# 8. Firewall rules
Save-Section "08-FirewallRules" {
    Get-NetFirewallRule |
        Select-Object DisplayName, Enabled, Direction, Action,
        Profile
}

# 9. Scheduled task inventory
Save-Section "09-ScheduledTasks" {
    Get-ScheduledTask |
        Select-Object TaskName, TaskPath, State, Author
}

# 10. SMB shares
Save-Section "10-SMB-Shares" {
    Get-SmbShare |
        Select-Object Name, Path, Description, ShareState
}

# 11. SMB share permissions
Save-Section "11-SMB-Permissions" {
    Get-SmbShare | ForEach-Object {
        "SHARE: $($_.Name)"
        Get-SmbShareAccess -Name $_.Name
    }
}

# 12. Installed Windows roles and features
Save-Section "12-WindowsFeatures" {
    if (Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue) {
        Get-WindowsFeature |
            Where-Object Installed |
            Select-Object Name, DisplayName, InstallState
    }
    else {
        "Get-WindowsFeature is unavailable on this machine."
    }
}

# 13. IIS website metadata
Save-Section "13-IIS-Sites" {
    if (Get-Command Get-Website -ErrorAction SilentlyContinue) {
        Get-Website |
            Select-Object Name, State, PhysicalPath, Bindings
    }
    else {
        "IIS management commands are unavailable."
    }
}

# 14. IIS application pools
Save-Section "14-IIS-AppPools" {
    if (Get-Command Get-IISAppPool -ErrorAction SilentlyContinue) {
        Get-IISAppPool |
            Select-Object Name, State, ManagedRuntimeVersion,
            ManagedPipelineMode
    }
    else {
        "IIS management commands are unavailable."
    }
}

# 15. DNS configuration
Save-Section "15-DNS" {
    Get-DnsClientServerAddress |
        Select-Object InterfaceAlias, AddressFamily, ServerAddresses
}

# 16. Running processes (inventory only)
Save-Section "16-Processes" {
    Get-Process |
        Select-Object Name, Id, CPU, StartTime
}

"----------------------------------------" |
    Out-File $logFile -Append
"Snapshot completed: $(Get-Date)" |
    Out-File $logFile -Append
"Output folder: $outputDir" |
    Out-File $logFile -Append

Write-Host ""
Write-Host "Snapshot completed."
Write-Host "Saved to: $outputDir"
Write-Host "Review snapshot-log.txt for collection errors."

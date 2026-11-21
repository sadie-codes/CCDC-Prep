
# ServiceHealth.ps1
# Read-only service health report

$Output = Join-Path $PSScriptRoot (
    "ServiceHealth_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".csv"
)

$Services = @(
    "DNS",
    "W3SVC",
    "MSSQLSERVER",
    "MySQL",
    "LanmanServer",
    "NTDS",
    "DHCPServer",
    "Spooler"
)

$Results = foreach ($Name in $Services) {
    $Service = Get-Service -Name $Name -ErrorAction SilentlyContinue

    if ($Service) {
        [PSCustomObject]@{
            Service = $Name
            Status = $Service.Status
            StartupType = $Service.StartType
        }
    }
    else {
        [PSCustomObject]@{
            Service = $Name
            Status = "Not found"
            StartupType = "Unknown"
        }
    }
}

$Results | Export-Csv $Output -NoTypeInformation
$Results | Format-Table -AutoSize

Write-Host "Report saved to $Output"

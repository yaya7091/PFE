# ===============================
# Windows Supervision Agent
# ===============================
# Outputs a JSON report including:
# - CPU, Disk, RAM usage
# - Status and logs of key services
# - Detected problems in logs

$services = @("sshd", "Apache2.4", "dns", "dhcp", "ldap")
$logLines = 50
$keywords = "error|fail|critical|unable|denied|panic|segfault"
$logPath = "$env:ProgramData\SupervisionAgent"
$jsonReport = "$logPath\windows_report.json"

if (!(Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath | Out-Null
}

function Get-CpuUsage {
    $cpu = Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property LoadPercentage -Average
    return "$($cpu.Average)%"
}

function Get-DiskUsage {
    $usage = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        [PSCustomObject]@{
            DeviceID = $_.DeviceID
            Usage    = "{0:N2}%" -f ((1 - ($_.FreeSpace / $_.Size)) * 100)
        }
    }
    return $usage
}

function Get-RamUsage {
    $mem = Get-CimInstance Win32_OperatingSystem
    $used = ($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / 1MB
    $total = $mem.TotalVisibleMemorySize / 1MB
    return ("{0:N2} GB / {1:N2} GB" -f $used, $total)
}

function Get-ServiceInfo {
    param($name)

    $status = "not installed"
    $logs = @()
    $problems = @()

    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($svc) {
        $status = $svc.Status.ToString().ToLower()
        $logs = Get-WinEvent -LogName System -MaxEvents $logLines |
                Where-Object { $_.Message -match $name } |
                Select-Object -ExpandProperty Message

        $problems = $logs | Where-Object { $_ -match $keywords }
    }

    return [PSCustomObject]@{
        name     = $name
        status   = $status
        logs     = $logs
        problems = $problems
    }
}

$report = @{
    cpu_usage  = Get-CpuUsage
    disk_usage = Get-DiskUsage
    ram_usage  = Get-RamUsage
    services   = @()
}

foreach ($s in $services) {
    $report.services += Get-ServiceInfo -name $s
}

$report | ConvertTo-Json -Depth 5 | Out-File -Encoding UTF8 $jsonReport

Write-Output "Report generated at $jsonReport"

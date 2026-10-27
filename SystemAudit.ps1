# ==========================================
# SYSTEM ADMINISTRATION AUDIT SCRIPT
# ==========================================

# Report file locations
$ReportPath = $PSScriptRoot
$DiskCSV = Join-Path $ReportPath "DiskAudit.csv"
$HTMLReport = Join-Path $ReportPath "SystemReport.html"

# ==========================================
# 1. SYSTEM INFORMATION AUDIT
# ==========================================

$SystemInfo = Get-ComputerInfo |
    Select-Object CsName, WindowsProductName, OsArchitecture

Write-Host "`nSYSTEM INFORMATION" -ForegroundColor Cyan
$SystemInfo | Format-Table -AutoSize

# ==========================================
# 2. DISK SPACE AUDIT
# ==========================================

$DiskInfo = Get-Volume |
    Where-Object {
        $_.DriveType -eq 'Fixed' -and
        $_.DriveLetter -and
        $_.Size -gt 0
    } |
    Select-Object DriveLetter, FileSystemLabel,
        @{Name='FreeSpaceGB';Expression={
            [math]::Round($_.SizeRemaining / 1GB, 2)
        }},
        @{Name='TotalSizeGB';Expression={
            [math]::Round($_.Size / 1GB, 2)
        }},
        @{Name='FreePercent';Expression={
            [math]::Round(($_.SizeRemaining / $_.Size) * 100, 2)
        }}

Write-Host "`nDISK SPACE AUDIT" -ForegroundColor Cyan
$DiskInfo | Format-Table -AutoSize

# Check for drives below 20% free space
$LowDisk = $DiskInfo | Where-Object {
    $_.FreePercent -lt 20
}

if ($LowDisk) {
    Write-Host "WARNING: Low disk space detected!" -ForegroundColor Yellow
    $LowDisk | Format-Table -AutoSize
}
else {
    Write-Host "Disk space is healthy." -ForegroundColor Green
}

# Export disk audit to CSV
$DiskInfo | Export-Csv -Path $DiskCSV -NoTypeInformation

Write-Host "Disk audit CSV saved successfully!" -ForegroundColor Cyan

# ==========================================
# 3. MEMORY AUDIT
# ==========================================

$MemoryInfo = Get-CimInstance Win32_ComputerSystem |
    Select-Object Name,
        @{Name='TotalRAMGB';Expression={
            [math]::Round($_.TotalPhysicalMemory / 1GB, 2)
        }}

Write-Host "`nMEMORY AUDIT" -ForegroundColor Cyan
$MemoryInfo | Format-Table -AutoSize

# ==========================================
# 4. WINDOWS SERVICES AUDIT
# ==========================================

$StoppedServices = Get-CimInstance Win32_Service |
    Where-Object {
        $_.StartMode -eq 'Auto' -and
        $_.State -eq 'Stopped'
    } |
    Select-Object Name, DisplayName, StartMode, State

Write-Host "`nWINDOWS SERVICES AUDIT" -ForegroundColor Cyan

if ($StoppedServices) {
    Write-Host "WARNING: Automatic services are stopped!" -ForegroundColor Yellow
    $StoppedServices | Format-Table -AutoSize
}
else {
    Write-Host "All automatic services are running." -ForegroundColor Green
}

# ==========================================
# 5. GENERATE HTML REPORT
# ==========================================

$Style = @"
<style>
body {
    font-family: Arial, sans-serif;
    margin: 30px;
    background-color: #f4f6f9;
    color: #222;
}
h1 {
    color: #17365d;
}
h2 {
    color: #245a81;
    margin-top: 30px;
}
table {
    border-collapse: collapse;
    width: 100%;
    background-color: white;
    margin-bottom: 20px;
}
th, td {
    border: 1px solid #ddd;
    padding: 10px;
    text-align: left;
}
th {
    background-color: #17365d;
    color: white;
}
tr:nth-child(even) {
    background-color: #eef2f6;
}
.warning {
    color: #b45309;
    font-weight: bold;
}
.success {
    color: green;
    font-weight: bold;
}
</style>
"@

$SystemTable = $SystemInfo | ConvertTo-Html -Fragment
$DiskTable = $DiskInfo | ConvertTo-Html -Fragment
$MemoryTable = $MemoryInfo | ConvertTo-Html -Fragment

if ($StoppedServices) {
    $ServicesTable = $StoppedServices | ConvertTo-Html -Fragment
    $ServiceStatus = "<p class='warning'>WARNING: Automatic services are stopped!</p>"
}
else {
    $ServicesTable = "<p>No stopped automatic services detected.</p>"
    $ServiceStatus = "<p class='success'>All automatic services are running.</p>"
}

if ($LowDisk) {
    $DiskStatus = "<p class='warning'>WARNING: Low disk space detected!</p>"
}
else {
    $DiskStatus = "<p class='success'>Disk space is healthy.</p>"
}

$ReportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$HTML = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>System Administration Audit Report</title>
$Style
</head>
<body>

<h1>System Administration Audit Report</h1>
<p><strong>Generated:</strong> $ReportDate</p>

<h2>System Information</h2>
$SystemTable

<h2>Disk Space Audit</h2>
$DiskStatus
$DiskTable

<h2>Memory Audit</h2>
$MemoryTable

<h2>Windows Services Audit</h2>
$ServiceStatus
$ServicesTable

</body>
</html>
"@

$HTML | Out-File -FilePath $HTMLReport -Encoding utf8

Write-Host "`nHTML report generated successfully!" -ForegroundColor Green
Write-Host "Report location: $HTMLReport" -ForegroundColor Cyan

# Open the HTML report automatically
Start-Process $HTMLReport
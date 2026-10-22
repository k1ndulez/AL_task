<#
.SYNOPSIS
    Retry-hammer for the ST-LINK -> target SWD link.
    Use it while you re-seat / re-wire SWDIO & SWCLK: it prints the exact
    ST-Link GDB server verdict every few seconds, so you see instantly whether
    the link came up.

.EXAMPLE
    .\tools\Wait-Target.ps1
.EXAMPLE
    .\tools\Wait-Target.ps1 -Frequency 480 -IntervalSeconds 3
#>
[CmdletBinding()]
param(
    [int]$Frequency = 1000,
    [int]$IntervalSeconds = 3,
    [int]$MaxAttempts = 40
)

$bundleRoot = if ($env:CUBE_BUNDLE_PATH) { $env:CUBE_BUNDLE_PATH } else { Join-Path $env:LOCALAPPDATA 'stm32cube\bundles' }
$gdbServer = Get-ChildItem (Join-Path $bundleRoot 'stlink-gdbserver') -Recurse -Filter 'ST-LINK_gdbserver.exe' -ErrorAction SilentlyContinue |
             Where-Object { $_.FullName -notmatch '\\native\\' } | Select-Object -First 1 -ExpandProperty FullName
$progCli = Get-ChildItem (Join-Path $bundleRoot 'programmer') -Recurse -Filter 'STM32_Programmer_CLI.exe' -ErrorAction SilentlyContinue |
           Select-Object -First 1 -ExpandProperty FullName

if (-not $gdbServer -or -not $progCli) { Write-Host 'STM32Cube tools not found.' -ForegroundColor Red; exit 1 }
$progDir = Split-Path $progCli
$log = Join-Path $env:TEMP 'wait-target.log'

Write-Host ("Watching the SWD link at {0} kHz, every {1}s. Ctrl+C to stop." -f $Frequency, $IntervalSeconds) -ForegroundColor Cyan
Write-Host 'Re-seat SWDIO / SWCLK / GND while this runs.' -ForegroundColor DarkGray
Write-Host ''

for ($i = 1; $i -le $MaxAttempts; $i++) {
    if (Test-Path $log) { Remove-Item $log -Force -ErrorAction SilentlyContinue }
    $out = & $gdbServer -p 61234 -l 31 -f $log -d -k --frequency $Frequency -cp $progDir 2>&1 | Out-String
    $stamp = Get-Date -Format 'HH:mm:ss'

    if ($out -match 'Waiting for gdb connection|Listening|listening') {
        Write-Host ("[{0}] #{1}  LINK IS UP  <- target talking, you can press F5 now" -f $stamp, $i) -ForegroundColor Green
        break
    }
    elseif ($out -match 'Unable to get core ID|No device found on target|Target no device found') {
        Write-Host ("[{0}] #{1}  ST-LINK ok, but NO response from MCU (SWDIO/SWCLK/GND or MCU itself)" -f $stamp, $i) -ForegroundColor Red
    }
    elseif ($out -match 'No ST-LINK found|No ST-LINK detected|USB') {
        Write-Host ("[{0}] #{1}  ST-LINK itself dropped off USB (cable/port/power)" -f $stamp, $i) -ForegroundColor Magenta
    }
    else {
        Write-Host ("[{0}] #{1}  other failure:" -f $stamp, $i) -ForegroundColor Yellow
        ($out -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 4 |
            ForEach-Object { Write-Host ('           ' + $_) }
    }
    Start-Sleep -Seconds $IntervalSeconds
}

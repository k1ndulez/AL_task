<#
.SYNOPSIS
    One-shot rescue for a board whose firmware disabled SWD (__HAL_AFIO_REMAP_SWJ_DISABLE).
    Connects under reset, erases, and flashes build/Debug/jishu.elf.

.DESCRIPTION
    Problem recap: CubeMX generated __HAL_AFIO_REMAP_SWJ_DISABLE() because SYS > Debug
    was "No Debug". That kills the SW-DP right after reset, so the ST-LINK reports
    "could not connect (error 138)" forever.

    This script removes that line from the running firmware by flashing the fixed image.
    Because the old firmware still closes SWD, the connection must win the race:
      - best: NRST of the board wired to RST of the ST-LINK, then this script does it alone
      - otherwise: press the board RESET button exactly when the script asks

.EXAMPLE
    .\tools\Flash-Fixed.ps1
.EXAMPLE
    .\tools\Flash-Fixed.ps1 -Elf .\build\Debug\jishu.elf -Frequency 480
#>
[CmdletBinding()]
param(
    [string]$Elf        = (Join-Path (Get-Location) 'build\Debug\jishu.elf'),
    [int]$Frequency     = 480,
    [switch]$SkipVerify,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Continue'
$bundleRoot = if ($env:CUBE_BUNDLE_PATH) { $env:CUBE_BUNDLE_PATH } else { Join-Path $env:LOCALAPPDATA 'stm32cube\bundles' }
$progCli = Get-ChildItem (Join-Path $bundleRoot 'programmer') -Recurse -Filter 'STM32_Programmer_CLI.exe' -ErrorAction SilentlyContinue |
           Select-Object -First 1 -ExpandProperty FullName

if (-not $progCli) { Write-Host 'STM32_Programmer_CLI.exe not found.' -ForegroundColor Red; exit 1 }
if (-not (Test-Path $Elf)) { Write-Host ("ELF not found: {0}" -f $Elf) -ForegroundColor Red; exit 1 }

Write-Host ''
Write-Host '===== ST-LINK rescue flash =====' -ForegroundColor Cyan
Write-Host ("ELF       : {0}" -f $Elf)
Write-Host ("Programmer: {0}" -f $progCli)
Write-Host ("SWD freq  : {0} kHz" -f $Frequency)
Write-Host ''

function Get-ProbeLine($text) {
    ($text -split "`r?`n") | Where-Object { $_ -match 'ST-LINK (SN|FW)|Voltage|Device ID|Device name|Flash size|Error' } |
        ForEach-Object { '    ' + $_.Trim() }
}

# --- attempt 1: automatic connect under reset (works when NRST is wired to ST-LINK RST) ---
Write-Host '--- attempt 1: connect under reset (no user action) ---' -ForegroundColor Yellow
$out1 = & $progCli -c port=SWD freq=$Frequency mode=UR reset=HWrst 2>&1 | Out-String
Get-ProbeLine $out1 | ForEach-Object { Write-Host $_ }

$connected = $out1 -match 'Device ID|Device name|Flash size'

# --- attempt 2: race the reset button ---
if (-not $connected) {
    if ($NonInteractive) {
        Write-Host '  [X] No target (non-interactive mode: reset-button race skipped).' -ForegroundColor Red
        exit 2
    }
    Write-Host ''
    Write-Host '--- attempt 2: race against the firmware ---' -ForegroundColor Yellow
    Write-Host '    The old firmware closes SWD a few ms after reset, so we must attach inside that window.'
    Write-Host '    >>> Press and HOLD the RESET button on the board, then press ENTER here,' -ForegroundColor Cyan
    Write-Host '    >>> and RELEASE the button when the next line says GO.' -ForegroundColor Cyan
    $null = Read-Host '    Ready? press ENTER'

    $job = Start-Job -ScriptBlock {
        param($cli, $freq)
        & $cli -c port=SWD freq=$freq mode=UR reset=HWrst 2>&1 | Out-String
    } -ArgumentList $progCli, $Frequency

    Start-Sleep -Milliseconds 700
    Write-Host '    GO - release RESET now!' -ForegroundColor Green
    $out2 = Receive-Job -Job $job -Wait
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    Get-ProbeLine $out2 | ForEach-Object { Write-Host $_ }
    $connected = $out2 -match 'Device ID|Device name|Flash size'
}

if (-not $connected) {
    Write-Host ''
    Write-Host '  [X] Still no target. The reset pulse is not reaching the MCU.' -ForegroundColor Red
    Write-Host '      Wire NRST (board) <-> RST of the ST-LINK, or keep holding RESET while re-running this.' -ForegroundColor Red
    Write-Host '      Also double-check SWDIO / SWCLK are not swapped.' -ForegroundColor Red
    exit 2
}

Write-Host ''
Write-Host '  [OK] Attached to the target.' -ForegroundColor Green

# --- erase + program + verify ---
Write-Host ''
Write-Host '--- erase / program / verify ---' -ForegroundColor Yellow
$flashArgs = @('-c', 'port=SWD', "freq=$Frequency", 'mode=UR', 'reset=HWrst', '-e', 'all', '-d', $Elf, '-rst')
if (-not $SkipVerify) { $flashArgs += '-v' }
$out3 = & $progCli @flashArgs 2>&1 | Out-String
($out3 -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 18 | ForEach-Object { Write-Host ('    ' + $_) }

if ($out3 -match 'File download complete|Download verified successfully|successfully downloaded') {
    Write-Host ''
    Write-Host '  [OK] New firmware flashed. SWD stays enabled now, so F5 in VS Code will work.' -ForegroundColor Green
    Write-Host '       Next: press F5 and debug normally.' -ForegroundColor Green
    exit 0
}

Write-Host ''
Write-Host '  [X] Flashing did not complete. Share the output above.' -ForegroundColor Red
exit 3

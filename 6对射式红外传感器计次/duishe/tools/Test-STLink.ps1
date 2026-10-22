<#
.SYNOPSIS
    ST-LINK connection diagnostics for the STM32Cube VS Code extension.
    Helps resolve: "bound doStepConnectToTarget Failed; could not connect (error 138)".

.DESCRIPTION
    Bypasses VS Code and calls ST's own tools directly, in three steps:
      1. Is the ST-LINK probe enumerated on USB (serial, firmware)?
      2. Can STM32CubeProgrammer connect to the target (connect-under-reset, low speed)?
      3. Can ST-LINK_gdbserver reach its "waiting for gdb connection" state
         (that is the exact step where the extension reports the error)?
    Full output of every attempt is written under tools\logs\.

.PARAMETER Frequency
    SWD clock in kHz. Default 1000. Try 480 or 140 with long / loose jumper wires.

.PARAMETER OnlyProbe
    Only run step 1.

.PARAMETER SkipGdbServer
    Run steps 1-2 only.

.PARAMETER ContinueWithoutProbe
    Do not stop when the probe is not enumerated; still try CubeProgrammer/gdbserver
    (useful when the probe only shows up while the target is powered).

.EXAMPLE
    .\tools\Test-STLink.ps1
.EXAMPLE
    .\tools\Test-STLink.ps1 -Frequency 480
#>
[CmdletBinding()]
param(
    [int]$Frequency = 1000,
    [switch]$OnlyProbe,
    [switch]$SkipGdbServer,
    [switch]$ContinueWithoutProbe
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# ---------- locate the tools shipped with the STM32Cube extension ----------
if ($env:CUBE_BUNDLE_PATH) { $bundleRoot = $env:CUBE_BUNDLE_PATH }
else { $bundleRoot = Join-Path $env:LOCALAPPDATA 'stm32cube\bundles' }

function Find-Tool([string]$bundle, [string]$exeName) {
    $base = Join-Path $bundleRoot $bundle
    if (-not (Test-Path $base)) { return $null }
    Get-ChildItem $base -Recurse -Filter $exeName -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\native\\' } |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

$gdbServer = Find-Tool 'stlink-gdbserver' 'ST-LINK_gdbserver.exe'
$progCli   = Find-Tool 'programmer' 'STM32_Programmer_CLI.exe'

$logDir = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Show-PathOrMissing($p) { if ($p) { $p } else { '<not found>' } }

Write-Host ''
Write-Host '===== ST-LINK connection diagnostics =====' -ForegroundColor Cyan
Write-Host ("bundle root : {0}" -f $bundleRoot)
Write-Host ("gdbserver   : {0}" -f (Show-PathOrMissing $gdbServer))
Write-Host ("programmer  : {0}" -f (Show-PathOrMissing $progCli))
Write-Host ("log folder  : {0}" -f $logDir)
Write-Host ''

if (-not $gdbServer -and -not $progCli) {
    Write-Host 'STM32Cube ST-LINK tools were not found.' -ForegroundColor Red
    Write-Host 'Make sure the STM32Cube extension is installed and has been activated once in VS Code.' -ForegroundColor Red
    exit 1
}

$progDir = $null
if ($progCli) { $progDir = Split-Path $progCli }

# ---------- step 1: probe present on USB? ----------
Write-Host '----- [1/3] Is the ST-LINK probe enumerated? -----' -ForegroundColor Yellow

$probeSeen = $false
if ($progCli) {
    $listLog = Join-Path $logDir "probe-$stamp.txt"
    $listOut = & $progCli --list 2>&1 | Out-String
    $listOut | Set-Content -Path $listLog -Encoding UTF8
    if ($listOut -notmatch 'No ST-Link detected') { $probeSeen = $true }
    ($listOut -split "`r?`n") | Where-Object { $_ -match 'ST-Link|ST-LINK|Serial|Firmware|No ST' } |
        ForEach-Object { Write-Host ('  ' + $_.Trim()) }
    Write-Host ("  (full list: {0})" -f $listLog)
}

if (-not $probeSeen) {
    Write-Host ''
    Write-Host '  [X] No ST-LINK detected on USB.' -ForegroundColor Red
    Write-Host '      "error 138" is only the symptom here. Fix the probe link first:' -ForegroundColor Red
    Write-Host '        1) Use a USB cable that carries data (many cables are power-only).'
    Write-Host '           Plug into a rear motherboard port, avoid hubs and front-panel ports.'
    Write-Host '        2) Device Manager > Universal Serial Bus devices should list'
    Write-Host '           "STM32 STLink" (VID_0483&PID_3748).'
    Write-Host '        3) Yellow warning icon -> reinstall the ST-LINK driver from'
    Write-Host '           STM32CubeProgrammer\Drivers\ST-LINK.'
    Write-Host '        4) Probe appears then vanishes -> power/cable problem, or the ST-LINK'
    Write-Host '           firmware is gone (recover with ST-LINK Upgrade).'
    Write-Host ''
    Write-Host '  Reminder: the target board needs its own solid 3.3V supply and a shared GND.' -ForegroundColor DarkGray
    if (-not $ContinueWithoutProbe) { exit 2 }
    Write-Host '  (-ContinueWithoutProbe: continuing anyway)' -ForegroundColor DarkGray
}

if ($probeSeen) { Write-Host '  [OK] ST-LINK is enumerated' -ForegroundColor Green }

if ($OnlyProbe) { exit 0 }

# ---------- step 2: CubeProgrammer connects to the target ----------
$hwOk = $null
if ($progCli -and -not $SkipGdbServer) {
    Write-Host ''
    Write-Host '----- [2/3] CubeProgrammer connects to the target (connect-under-reset) -----' -ForegroundColor Yellow
    $cpLog  = Join-Path $logDir "cubeprog-$stamp.txt"
    $cpArgs = @('-c', 'port=SWD', "freq=$Frequency", 'mode=UR', 'reset=HWrst', '-ob', 'RDP=0xAA')
    Write-Host ("  command: STM32_Programmer_CLI.exe {0}" -f ($cpArgs -join ' '))
    $cpOut = & $progCli @cpArgs 2>&1 | Out-String
    $cpOut | Set-Content -Path $cpLog -Encoding UTF8
    ($cpOut -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 25 |
        ForEach-Object { Write-Host ('  ' + $_) }
    Write-Host ("  (full output: {0})" -f $cpLog)

    if ($cpOut -match 'Device ID|Device name|Device family|Flash size') {
        Write-Host '  [OK] CubeProgrammer reaches the chip - wiring/power are fine,' -ForegroundColor Green
        Write-Host '       so the problem sits in the extension / launch configuration.' -ForegroundColor Green
        $hwOk = $true
    } else {
        Write-Host '  [X] CubeProgrammer cannot reach the chip either - this is hardware,' -ForegroundColor Red
        Write-Host '      wiring or power, not VS Code.' -ForegroundColor Red
        $hwOk = $false
    }
}

# ---------- step 3: run ST-LINK_gdbserver directly (what the extension does) ----------
if ($gdbServer -and -not $SkipGdbServer) {
    Write-Host ''
    Write-Host '----- [3/3] Start ST-LINK_gdbserver directly -----' -ForegroundColor Yellow
    $srvLog   = Join-Path $logDir "gdbserver-$stamp.log"
    $srvOut   = Join-Path $logDir "gdbserver-$stamp.out.txt"
    $srvErr   = Join-Path $logDir "gdbserver-$stamp.err.txt"
    $srvArgs  = @('-p', '61234', '-l', '31', '-f', $srvLog, '-d', '--frequency', "$Frequency", '-k')
    if ($progDir) { $srvArgs += @('-cp', $progDir) }
    Write-Host ("  command: ST-LINK_gdbserver.exe {0}" -f ($srvArgs -join ' '))
    Write-Host '  Expected: "Waiting for gdb connection on localhost:61234" then it blocks.'
    Write-Host ''

    $portOwner = Get-NetTCPConnection -State Listen -LocalPort 61234 -ErrorAction SilentlyContinue |
                 Select-Object -First 1 -ExpandProperty OwningProcess
    if ($portOwner) {
        $ownerName = (Get-Process -Id $portOwner -ErrorAction SilentlyContinue).ProcessName
        Write-Host ("  [!] Port 61234 is already in use by PID {0} ({1})." -f $portOwner, $ownerName) -ForegroundColor Red
        Write-Host '      That leftover process is exactly what makes the extension fail on F5.' -ForegroundColor Red
        Write-Host ("      Stop it with: Stop-Process -Id {0} -Force" -f $portOwner) -ForegroundColor Yellow
        Write-Host ''
    } else {
        Write-Host '  (port 61234 is free)'
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = $gdbServer
    $psi.Arguments              = ($srvArgs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.WorkingDirectory       = Split-Path $gdbServer

    $proc  = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $null  = $proc.Start()
    $stdout = $proc.StandardOutput.ReadToEndAsync()
    $stderr = $proc.StandardError.ReadToEndAsync()

    $waiting = $false
    $deadline = (Get-Date).AddSeconds(25)
    while ((Get-Date) -lt $deadline) {
        if ($proc.HasExited) { break }
        Start-Sleep -Milliseconds 500
        if ($stdout.IsCompleted) { break }
    }

    $outText = if ($stdout.IsCompleted) { $stdout.Result } else { '' }
    $errText = if ($stderr.IsCompleted) { $stderr.Result } else { '' }
    $outText | Set-Content -Path $srvOut -Encoding UTF8
    $errText | Set-Content -Path $srvErr -Encoding UTF8

    $combined = ($outText + "`n" + $errText)
    if (-not $proc.HasExited) {
        $waiting = $true
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }

    if ($waiting) {
        Write-Host '  [OK] gdbserver reached the listening state without a target error.' -ForegroundColor Green
        Write-Host '       The extension-side "error 138" is then usually a stale gdbserver' -ForegroundColor DarkGray
        Write-Host '       process or CubeMX holding the probe. Close them and retry F5.' -ForegroundColor DarkGray
    } else {
        Write-Host ("  [X] gdbserver exited, ExitCode = {0}" -f $proc.ExitCode) -ForegroundColor Red
        ($combined -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 14 |
            ForEach-Object { Write-Host ('  ' + $_) }
        Write-Host ("  (full log: {0})" -f $srvLog)
        Write-Host ''
        Write-Host '  Typical meanings:' -ForegroundColor DarkGray
        Write-Host '    No ST-LINK found          -> USB drop / cable / driver' -ForegroundColor DarkGray
        Write-Host '    Error in initializing     -> target unpowered, SWDIO/SWCLK swapped or loose,' -ForegroundColor DarkGray
        Write-Host '                                 or NRST not wired while using -k (connect under reset)' -ForegroundColor DarkGray
        Write-Host '    Could not connect         -> chip read-protected, in low-power mode,' -ForegroundColor DarkGray
        Write-Host '                                 or held by another process' -ForegroundColor DarkGray
    }
}

Write-Host ''
Write-Host '===== done =====' -ForegroundColor Cyan
Write-Host 'Share the newest files in tools\logs\ to pin down USB vs wiring vs configuration.' -ForegroundColor DarkGray

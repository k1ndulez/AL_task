@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0.."

rem ---------------------------------------------------------------
rem  Rescue flash for firmware that disabled SWD (SWJ_DISABLE).
rem  Needs NRST (board) wired to RST (ST-LINK): only connect-under-reset
rem  can halt the core before main() reconfigures PA13/PA14 as GPIO.
rem ---------------------------------------------------------------

set "BUNDLE=%LOCALAPPDATA%\stm32cube\bundles"
if defined CUBE_BUNDLE_PATH set "BUNDLE=%CUBE_BUNDLE_PATH%"

set "CLI="
for /d %%d in ("%BUNDLE%\programmer\*") do if exist "%%d\bin\STM32_Programmer_CLI.exe" set "CLI=%%d\bin\STM32_Programmer_CLI.exe"
if not defined CLI (
  echo [X] STM32_Programmer_CLI.exe not found under %BUNDLE%\programmer
  pause & exit /b 1
)
if not exist "build\Debug\jishu.elf" (
  echo [X] build\Debug\jishu.elf not found. Build first.
  pause & exit /b 1
)

echo.
echo ===== ST-LINK rescue flash =====
echo CLI : %CLI%
echo ELF : %CD%\build\Debug\jishu.elf
echo.
echo Required jumper:  board NRST  --^>  ST-LINK RST
echo.

set ATTEMPTS=5
set /a tries=0

:try
set /a tries+=1
echo --- attempt !tries!/%ATTEMPTS% : SWD 480 kHz, connect under reset ---
"%CLI%" -c port=SWD freq=480 mode=UR reset=HWrst -e all -d "build\Debug\jishu.elf" -v -rst
if not errorlevel 1 goto success
if !tries! geq %ATTEMPTS% goto failed
echo.
echo   no target yet, retrying in 2 s...
timeout /t 2 /nobreak >nul
goto try

:success
echo.
echo [OK] Firmware flashed. SWD stays enabled now - press F5 in VS Code.
echo      You can remove the NRST jumper afterwards.
pause
exit /b 0

:failed
echo.
echo [X] Could not attach after %ATTEMPTS% attempts.
echo.
echo     Most likely the reset line is missing. Wire:
echo         board NRST   --^>   ST-LINK RST
echo     RST is pin 15 of the 20-pin header, or the pin/pad labelled RST
echo     on the dongle.
echo.
echo     Then re-check the other three wires are straight through:
echo         3.3V - 3.3V,  SWDIO - SWDIO,  SWCLK - SWCLK,  GND - GND
echo.
pause
exit /b 2

@echo off
setlocal
cd /d "%~dp0.."

rem ---------------------------------------------------------------
rem  Rescue flash without any PowerShell script or execution policy.
rem  Tries to attach to the target under reset, erases, flashes.
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
  echo [X] build\Debug\jishu.elf not found. Build the project first.
  pause & exit /b 1
)

echo.
echo ===== ST-LINK rescue flash =====
echo CLI : %CLI%
echo ELF : %CD%\build\Debug\jishu.elf
echo.

echo --- attempt 1: connect under reset ---
"%CLI%" -c port=SWD freq=480 mode=UR reset=HWrst -e all -d "build\Debug\jishu.elf" -v -rst
if not errorlevel 1 goto success

echo.
echo --- attempt 2: race the RESET button ---
echo.
echo    1) Press and HOLD the RESET button on the board.
echo    2) Press any key in this window.
echo    3) When you see "GO", RELEASE the RESET button immediately.
echo.
pause
start "" /b "%CLI%" -c port=SWD freq=480 mode=UR reset=HWrst -e all -d "build\Debug\jishu.elf" -v -rst
timeout /t 1 /nobreak >nul
echo GO - release RESET now!
echo.
echo (If you got "Device not found", wait for the command to end and re-run this file.)
timeout /t 15 /nobreak
goto done

:success
echo.
echo [OK] Firmware flashed. SWD stays enabled now - press F5 in VS Code.

:done
echo.
pause

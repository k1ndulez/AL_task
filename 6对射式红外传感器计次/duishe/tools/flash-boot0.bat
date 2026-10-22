@echo off
setlocal
cd /d "%~dp0.."

rem ---------------------------------------------------------------
rem  Recovery WITHOUT any extra wire:
rem  1) Move the BOOT0 jumper on the board to 1
rem  2) Press RESET
rem  3) Run this file  -> the ROM bootloader leaves SWD enabled,
rem     so a plain NORMAL connect works and we can erase + flash.
rem  4) Move BOOT0 back to 0, press RESET
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
echo ===== ISOLATED SWD recovery via BOOT0 =====
echo CLI : %CLI%
echo ELF : %CD%\build\Debug\jishu.elf
echo.
echo Make sure BOOT0 = 1 and you pressed RESET before continuing.
echo.

echo --- connecting (NORMAL mode) ---
"%CLI%" -c port=SWD freq=480 mode=NORMAL
if errorlevel 1 (
  echo.
  echo [X] Could not attach. Confirm BOOT0 = 1 and that RESET was pressed.
  echo     Also check SWDIO / SWCLK / GND.
  pause & exit /b 2
)

echo.
echo --- erase + program + verify ---
"%CLI%" -c port=SWD freq=480 mode=NORMAL -e all -d "build\Debug\jishu.elf" -v -rst
if errorlevel 1 (
  echo.
  echo [X] Attached but flashing failed. Share the output above.
  pause & exit /b 3
)

echo.
echo [OK] Firmware flashed.
echo.
echo NEXT: set BOOT0 back to 0 and press RESET, otherwise the board
echo       will keep starting the bootloader instead of your program.
pause

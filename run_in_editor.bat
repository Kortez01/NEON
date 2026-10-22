@echo off
setlocal
cd /d "%~dp0"
set "GODOT_EXE="
if not "%GODOT_PATH%"=="" set "GODOT_EXE=%GODOT_PATH%"
if exist "%~dp0Godot_v4.6-stable_win64.exe" set "GODOT_EXE=%~dp0Godot_v4.6-stable_win64.exe"
if exist "%~dp0Godot_v4.6-stable_win64_console.exe" set "GODOT_EXE=%~dp0Godot_v4.6-stable_win64_console.exe"
if "%GODOT_EXE%"=="" (
  for %%G in (godot.exe godot4.exe Godot_v4.6-stable_win64.exe) do (
    where %%G >nul 2>nul && set "GODOT_EXE=%%G" && goto found_editor
  )
)
:found_editor
if "%GODOT_EXE%"=="" (
  echo Godot 4.6 not found. Put Godot next to this file or set GODOT_PATH.
  pause
  exit /b 1
)
start "NEON REVENANT Editor" "%GODOT_EXE%" --path "%~dp0" --editor
endlocal

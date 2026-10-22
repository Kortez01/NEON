@echo off
setlocal EnableExtensions
chcp 65001 >nul
cd /d "%~dp0"

set "GODOT_EXE="
if not "%GODOT_PATH%"=="" set "GODOT_EXE=%GODOT_PATH%"
if exist "%~dp0Godot_v4.6-stable_win64_console.exe" set "GODOT_EXE=%~dp0Godot_v4.6-stable_win64_console.exe"
if exist "%~dp0Godot_v4.6-stable_win64.exe" set "GODOT_EXE=%~dp0Godot_v4.6-stable_win64.exe"
if "%GODOT_EXE%"=="" (
  for %%G in (godot.exe godot4.exe Godot_v4.6-stable_win64.exe Godot_v4.6-stable_win64_console.exe) do (
    where %%G >nul 2>nul && set "GODOT_EXE=%%G" && goto found_godot
  )
)
:found_godot
if "%GODOT_EXE%"=="" (
  echo [ERROR] Не найден Godot 4.6.
  echo Скачай стандартную версию Godot 4.6 для Windows и распакуй рядом с этим BAT,
  echo либо укажи полный путь: set GODOT_PATH=C:\path\to\Godot_v4.6-stable_win64_console.exe
  echo Затем запусти build_windows.bat снова.
  pause
  exit /b 1
)

if not exist build mkdir build
echo Экспортирую нативную Windows-сборку...
"%GODOT_EXE%" --headless --path "%~dp0" --export-release "Windows Desktop" "%~dp0build\NEON_REVENANT.exe"
if errorlevel 1 (
  echo.
  echo [ERROR] Экспорт не завершён. Установи Export Templates для точно такой же версии Godot.
  echo В редакторе Godot: Editor ^> Manage Export Templates ^> Download and Install.
  pause
  exit /b 1
)
if exist "%~dp0build\NEON_REVENANT.exe" (
  echo.
  echo ГОТОВО: %~dp0build\NEON_REVENANT.exe
  echo Это нативное Windows-приложение, браузер не нужен.
  start "" "%~dp0build\NEON_REVENANT.exe"
) else (
  echo [ERROR] Экспорт завершился без ожидаемого файла.
  pause
  exit /b 1
)
endlocal

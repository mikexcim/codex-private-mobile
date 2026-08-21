@echo off
chcp 65001 >nul
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-independent-host.ps1"
if errorlevel 1 (
  echo.
  echo 安装未完成，请按上方提示处理。
  pause
  exit /b 1
)
echo.
echo 安装和首次启动已完成。
pause


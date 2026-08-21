@echo off
chcp 65001 >nul
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-independent-host.ps1"
if errorlevel 1 (
  echo.
  echo 启动失败，请按上方提示处理。
  pause
  exit /b 1
)
echo.
echo 服务已启动，现在可以用手机连接这台电脑。
pause


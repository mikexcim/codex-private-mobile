$ErrorActionPreference = 'Stop'

function Require-Winget {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw '未找到 winget。请先在 Microsoft Store 更新“应用安装程序”。'
    }
}

Require-Winget

if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) {
    Write-Output '正在安装 Node.js LTS...'
    winget install --id OpenJS.NodeJS.LTS --exact --silent `
        --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        throw 'Node.js 安装失败。'
    }
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
}

$tailscale = 'C:\Program Files\Tailscale\tailscale.exe'
if (-not (Test-Path -LiteralPath $tailscale)) {
    Write-Output '正在安装 Tailscale...'
    winget install --id Tailscale.Tailscale --exact --silent `
        --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tailscale)) {
        throw 'Tailscale 安装失败。'
    }
}

$tailscaleUi = 'C:\Program Files\Tailscale\tailscale-ipn.exe'
if (Test-Path -LiteralPath $tailscaleUi) {
    Start-Process -FilePath $tailscaleUi
}

Write-Output ''
Write-Output '请在 Tailscale 窗口使用你自己的账号登录。'
Write-Output '手机端稍后也必须使用这个人的同一个 Tailscale 网络。'
Read-Host '登录完成并显示 Connected 后，按回车继续'

$computerDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $computerDir 'start-independent-host.ps1')


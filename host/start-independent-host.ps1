$ErrorActionPreference = 'Stop'

$computerDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$hostDir = Join-Path $computerDir 'mobile-host'
$logDir = Join-Path $env:LOCALAPPDATA 'CodexPrivateMobileHost\logs'
$tailscale = 'C:\Program Files\Tailscale\tailscale.exe'
$addressFile = Join-Path $computerDir '手机连接地址.txt'

function Find-CodexExecutable {
    $candidates = [System.Collections.Generic.List[string]]::new()

    if ($env:CODEX_EXECUTABLE) {
        $candidates.Add($env:CODEX_EXECUTABLE)
    }

    $command = Get-Command codex.exe -ErrorAction SilentlyContinue
    if ($command) {
        $candidates.Add($command.Source)
    }

    $localBin = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin'
    if (Test-Path -LiteralPath $localBin) {
        Get-ChildItem -LiteralPath $localBin -Filter codex.exe -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            ForEach-Object { $candidates.Add($_.FullName) }
    }

    $appPackage = Get-AppxPackage OpenAI.Codex -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1
    if ($appPackage) {
        $candidates.Add((Join-Path $appPackage.InstallLocation 'app\resources\codex.exe'))
    }

    $legacyPath = Join-Path $env:LOCALAPPDATA 'CodexTools\codex.exe'
    $candidates.Add($legacyPath)

    return $candidates |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -First 1
}

$node = Get-Command node.exe -ErrorAction SilentlyContinue
if (-not $node) {
    throw '未找到 Node.js。请先运行“1-安装电脑端.cmd”。'
}
if (-not (Test-Path -LiteralPath $tailscale)) {
    throw '未找到 Tailscale。请先运行“1-安装电脑端.cmd”。'
}

$codex = Find-CodexExecutable
if (-not $codex) {
    throw '未找到 Codex 桌面端。请先安装/更新 Codex，配置并测试自己的 API，再重新运行。'
}

$statusText = & $tailscale status --json 2>$null
if (-not $statusText) {
    throw 'Tailscale 状态读取失败。请打开 Tailscale 并登录自己的账号。'
}
$tailscaleStatus = $statusText | ConvertFrom-Json
if ($tailscaleStatus.BackendState -ne 'Running' -or -not $tailscaleStatus.Self.DNSName) {
    $loginHint = if ($tailscaleStatus.AuthURL) { "`n登录地址：$($tailscaleStatus.AuthURL)" } else { '' }
    throw "Tailscale 尚未连接。请登录自己的账号。$loginHint"
}

$tailscaleIp = @($tailscaleStatus.Self.TailscaleIPs) |
    Where-Object { $_ -match '^100\.(?:[0-9]{1,3}\.){2}[0-9]{1,3}$' } |
    Select-Object -First 1
if (-not $tailscaleIp) {
    throw '未找到这台电脑的 Tailscale IPv4 地址。'
}

$tailscaleHost = $tailscaleStatus.Self.DNSName.TrimEnd('.')
$publicUrl = "http://${tailscaleHost}:8765"
$healthUrl = "http://${tailscaleIp}:8765/health"
$firewallName = 'Codex private mobile host (Tailscale only)'

$firewall = Get-NetFirewallRule -DisplayName $firewallName -ErrorAction SilentlyContinue
if ($firewall) {
    Set-NetFirewallRule -DisplayName $firewallName -Direction Inbound -Action Allow -Enabled True `
        -Profile Any -Protocol TCP -LocalPort 8765 -LocalAddress $tailscaleIp `
        -RemoteAddress '100.64.0.0/10' | Out-Null
} else {
    New-NetFirewallRule -DisplayName $firewallName -Direction Inbound -Action Allow -Protocol TCP `
        -LocalPort 8765 -LocalAddress $tailscaleIp -RemoteAddress '100.64.0.0/10' -Profile Any | Out-Null
}

New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$serverScript = Join-Path $hostDir 'server.mjs'
$existing = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq 'node.exe' -and $_.CommandLine -like "*$serverScript*" }

if ($existing) {
    $reuseExisting = $false
    try {
        $health = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 1
        $reuseExisting = $health.status -eq 'ok' -and
            $health.transport -eq 'tailscale-v1' -and
            $health.publicUrl -eq $publicUrl
    } catch {}

    if (-not $reuseExisting) {
        foreach ($process in $existing) {
            Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
                Where-Object { $_.ParentProcessId -eq $process.ProcessId } |
                ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
            Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Milliseconds 500
        $existing = $null
    }
}

if (-not $existing) {
    $env:CODEX_MOBILE_PUBLIC_URL = $publicUrl
    $env:CODEX_MOBILE_BIND_ADDRESS = $tailscaleIp
    $env:CODEX_EXECUTABLE = $codex
    Start-Process -FilePath $node.Source `
        -ArgumentList @("`"$serverScript`"") `
        -WorkingDirectory $computerDir `
        -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logDir 'stdout.log') `
        -RedirectStandardError (Join-Path $logDir 'stderr.log')
}

$ready = $false
for ($attempt = 0; $attempt -lt 40; $attempt++) {
    try {
        $response = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 1
        if ($response.status -eq 'ok' -and $response.publicUrl -eq $publicUrl) {
            $ready = $true
            break
        }
    } catch {
        Start-Sleep -Milliseconds 300
    }
}
if (-not $ready) {
    throw "电脑端服务启动失败。日志位置：$logDir"
}

@"
Codex 私人端 - 这台电脑的手机连接地址

当前入口：
$publicUrl

自动发现地址：
$publicUrl/public_url.json

电脑名：$($tailscaleStatus.Self.HostName)
Tailscale 账号/网络：$($tailscaleStatus.CurrentTailnet.Name)

请只将这两个地址填入你自己的手机 App。
"@ | Set-Content -LiteralPath $addressFile -Encoding UTF8

Write-Output '独立手机端已启动。'
Write-Output "手机入口：$publicUrl"
Write-Output "连接地址文件：$addressFile"


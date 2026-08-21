# Codex 私人端（员工独立版）

这是一个面向 Windows + Android 的独立手机访问方案。每名使用者使用自己的电脑、自己的 Codex/API 配置，以及自己的 Tailscale 账号和私人网络；不需要加入管理员或公司的共享 Tailnet。

> 本项目是非官方工具，与 OpenAI、Codex 或 Tailscale 官方无隶属、授权或背书关系。Codex 和 OpenAI 是其各自权利人的商标。

## 功能

- 在 Android 手机上查看和继续自己 Windows 电脑中的 Codex 任务。
- 从手机新建任务、发送消息，并处理命令执行或文件修改确认。
- 通过 Tailscale 私人网络连接，不需要 USB，也不需要把服务暴露到公网。
- 手机 App 不保存 API Key；API 登录和额度均来自使用者自己的电脑配置。

## 下载与安装

推荐从本仓库的 **Releases** 页面下载完整员工包并解压，然后按以下顺序操作：

1. 阅读 `docs/00-先看这里.txt`。
2. 按 `docs/01-电脑端安装说明.txt` 安装并启动电脑端。
3. 按 `docs/02-手机端安装说明.txt` 安装手机端并填写连接地址。

也可以直接使用仓库中的文件：

- Android 安装包：`android/Codex私人端.apk`
- Windows 安装与启动脚本：`host/`
- SHA-256 校验值：`SHA256.txt`

Tailscale 请只从[官方下载页](https://tailscale.com/download/android)或手机应用商店安装。本仓库不包含、也不重新分发 Tailscale APK。

## 系统要求

- Windows 10/11 64 位
- Android 手机
- Windows 可使用 `winget`
- 每名使用者拥有自己的 Codex/API 配置
- 每名使用者在手机和电脑上登录同一个、仅属于自己的 Tailscale 网络

## 安全说明

手机端连接后可以向电脑发送 Codex 指令，并可请求执行命令、读取或修改文件。请只在本人控制的设备和 Tailscale 网络中使用：

- 不要把“手机连接地址.txt”发给无关人员。
- 不要邀请不受信任的用户或设备加入同一 Tailnet。
- 批准命令或文件修改前，先核对具体内容。
- 发现手机或账号丢失时，立即从 Tailscale 管理后台移除对应设备并轮换相关凭据。
- 服务使用 HTTP 地址，但流量只绑定在 Tailscale 地址上，由 Tailscale 的加密隧道承载；不要修改脚本使其监听公网网卡。

## 仓库结构

```text
android/       Android 安装包
docs/          员工安装与使用说明
host/          Windows 电脑端脚本和网页界面
SHA256.txt     发布文件校验值
```

## 许可

本仓库暂未授予开源许可证。除法律另有规定外，未经权利人许可不得复制、修改或再分发。


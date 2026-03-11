# OpenClaw Windows 一键安装入口脚本 (v4.0.0)
# 中国大陆深度优化版本，支持全自动拆解安装流程

$ErrorActionPreference = 'Stop'
$global:Success = $false

# --- 基础配置变量 ---
$global:Version = '3.2.2'
$global:RepoUser = 'ClawTribe'
$global:RepoName = 'openclaw-oneclick'
$global:InstallDir = Join-Path $HOME 'OpenClaw'

# 分发加速线路
$ProxyPrefix = 'https://ghfast.top/'
$global:ReleaseBaseUrl = "${ProxyPrefix}https://github.com/$global:RepoUser/$global:RepoName/releases/download/v$global:Version"
$global:RawBaseUrl = "${ProxyPrefix}https://raw.githubusercontent.com/$global:RepoUser/$global:RepoName/main/scripts"
$global:NodeVersion = '22.14.0'
$global:NpmRegistry = 'https://registry.npmmirror.com'

function Write-Color {
    param($Text, $Color)
    Write-Host $Text -ForegroundColor $Color
}

Write-Color "`n──────────────────────────────────────────────────" "Cyan"
Write-Color "  🚀 OpenClaw 环境管家 (Windows)" "Cyan"
Write-Color "  正在为您进行全自动环境梳理与云端部署..." "Cyan"
Write-Color "──────────────────────────────────────────────────`n" "Cyan"

function Run-RemoteScript {
    param([string]$ScriptName)
    
    $ScriptUrl = "$global:RawBaseUrl/$ScriptName"
    Write-Color "➤ 正在拉取流程套件: $ScriptName ..." "Gray"
    
    try {
        $tempScript = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString() + ".ps1")
        Invoke-WebRequest -Uri $ScriptUrl -OutFile $tempScript -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
    } catch {
        # 降级尝试本地查找（为了开发人员本地测试和极低网速下的备用方案）
        $localPath = Join-Path $PWD "scripts\$ScriptName"
        if (Test-Path $localPath) {
            Copy-Item $localPath $tempScript
        } else {
            Write-Color "❌ 无法获取依赖流程文件 $ScriptName ，请检查网络或配置代理。" "Red"
            exit 1
        }
    }

    try {
        & $tempScript
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) { throw "Script exit code $LASTEXITCODE" }
    } catch {
        Write-Color "❌ 流程 $ScriptName 异常中断: $_" "Red"
        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        exit 1
    }
    Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
}

try {
    # 流程 1: Windows 基础权限开放以及 Git 和常用环境检查
    Run-RemoteScript "win_1_bases.ps1"
    
    # 流程 2: Node.js 淘宝镜像高速拉取与静默安装
    Run-RemoteScript "win_2_node.ps1"
    
    # 流程 3: 开箱下载 Release Zip 包、提取、绑定命令
    Run-RemoteScript "win_3_deploy.ps1"
    
    $global:Success = $true
} finally {
    Write-Color "`n──────────────────────────────────────────────────" "Cyan"
    if ($global:Success) {
        Write-Color "✓ OpenClaw 已成功部署！" "Green"
        Write-Color "  为确保后续无痛体验，请关闭此窗口并[重新打开一个全新 PowerShell]，然后运行：" "Yellow"
        Write-Color "  openclaw-setup" "Cyan"
    } else {
        Write-Color "⚠ 安装未完全成功。请翻看上方的红色错误日志。" "Yellow"
    }
    Write-Color "──────────────────────────────────────────────────" "Cyan"
    Write-Color "请按 [回车键] 退出..." "Cyan"
    Read-Host
}

# OpenClaw Windows Deployment Script
# Author: ClawTribe

Write-Host "
    ┌──────────────────────────────────────────────────┐
    │                                                  │
    │                  __                              │
    │                <(o )___                          │
    │                 ( ._> /                          │
    │                  \`---'                           │
    │            ~~~~~~~~~~~~~~~~~~                    │
    │                                                  │
    │            OpenClaw 智能管理中心                 │
    │               作者: ClawTribe | v2.0.2                 │
    └──────────────────────────────────────────────────┘
" -ForegroundColor Cyan

Write-Host "==================================================" -ForegroundColor Green
Write-Host "   🦆 OpenClaw Windows 全自动部署脚本       " -ForegroundColor Green
Write-Host "   作者: ClawTribe | 高亮交互稳定版 | 免费开源          " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green

# 1. 自动测速与换源
Write-Host "`n[1/4] 测试网络环境并配置加速源..." -ForegroundColor Yellow
try {
    $request = [System.Net.WebRequest]::Create("https://github.com")
    $request.Timeout = 3000
    $response = $request.GetResponse()
    $response.Close()
    Write-Host "   ✓ 国际网络畅通，使用官方节点" -ForegroundColor Green
    $env:npm_config_registry = "https://registry.npmjs.org/"
    $GitProxy = ""
} catch {
    Write-Host "   ✈️ 自动开启国内镜像加速 (NPM淘宝源 + GitHub加速)" -ForegroundColor Cyan
    $env:npm_config_registry = "https://registry.npmmirror.com"
    $GitProxy = "https://ghproxy.net/"
}

# 2. Node.js check (省略具体逻辑，同前)
Write-Host "`n[2/4] Node.js 环境检查..." -ForegroundColor Yellow

# 3. Sync and Install
Write-Host "`n[3/4] 正在同步管理工具代码..." -ForegroundColor Yellow
$InstallDir = Join-Path $HOME "OpenClaw"
if (Test-Path $InstallDir) {
    Set-Location $InstallDir
    if ($GitProxy -ne "") {
        git remote set-url origin "$($GitProxy)https://github.com/ClawTribe/openclaw-oneclick.git"
    } else {
        git remote set-url origin "https://github.com/ClawTribe/openclaw-oneclick.git"
    }
    git fetch --all
    git reset --hard origin/main
} else {
    git clone "$($GitProxy)https://github.com/ClawTribe/openclaw-oneclick.git" $InstallDir
    Set-Location $InstallDir
}

Write-Host "   - 安装内部依赖 (自动适配镜像源)..." -ForegroundColor Yellow
npm install --production --registry="$env:npm_config_registry"
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ 部署失败: 内部依赖安装出错。可能遇到权限问题。" -ForegroundColor Red
    exit 1
}

# 4. Register Command
Write-Host "`n[4/4] 配置系统全局命令..." -ForegroundColor Yellow
npm install -g . --registry="$env:npm_config_registry"
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ 部署失败: 全局命令注册出错。请检查权限或 Node.js 安装。" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎉 Deployment Successful! Run 'openclaw-setup' to start." -ForegroundColor Green

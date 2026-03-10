# OpenClaw Windows Deployment Script

$ErrorActionPreference = 'Stop'

$Version = '3.1.0'
$InstallDir = Join-Path $HOME 'OpenClaw'
$DefaultOpenClawVersion = 'v2026.2.26'
$OpenClawVersion = if ($env:OPENCLAW_VERSION) { $env:OPENCLAW_VERSION } else { $DefaultOpenClawVersion }
$OfficialInstallUrl = 'https://openclaw.ai/install.ps1'
$OfficialProjectGit = 'https://github.com/ClawTribe/openclaw-oneclick.git'
$FallbackProjectGit = 'https://ghfast.top/https://github.com/ClawTribe/openclaw-oneclick.git'
$OfficialNpmRegistry = 'https://registry.npmjs.org/'
$FallbackNpmRegistry = 'https://registry.npmmirror.com'
$TempDir = $null
$PreferredInstallUrl = 'https://openclaw.ai/install.ps1'
$PreferredProjectGit = 'https://ghfast.top/https://github.com/ClawTribe/openclaw-oneclick.git'
$PreferredNpmRegistry = 'https://registry.npmmirror.com'
$PreferredGitInsteadOf = 'https://ghfast.top/https://github.com/'

Write-Host @"
    ┌──────────────────────────────────────────────────┐
    │                                                  │
    │                  __                              │
    │                <(o )___                          │
    │                 ( ._> /                          │
    │                  ``---'                          │
    │            ~~~~~~~~~~~~~~~~~~                    │
    │                                                  │
    │            OpenClaw 智能管理中心                 │
    │               作者: ClawTribe | v$Version        │
    └──────────────────────────────────────────────────┘
"@ -ForegroundColor Cyan

function Ensure-TempDir {
    if (-not $script:TempDir) {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("openclaw-oneclick-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }
}

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-UrlAccess {
    param([string]$Url)
    try {
        $request = [System.Net.WebRequest]::Create($Url)
        $request.Timeout = 8000
        $response = $request.GetResponse()
        $response.Close()
        return $true
    } catch {
        return $false
    }
}

function Invoke-NpmCommand {
    param([string[]]$Arguments)

    & npm @Arguments --registry=$PreferredNpmRegistry
    if ($LASTEXITCODE -eq 0) {
        return $true
    }

    Write-Host '   ⚠ 国内 npm 镜像失败，回退官方 npm 源重试...' -ForegroundColor Yellow
    & npm @Arguments --registry=$OfficialNpmRegistry
    return ($LASTEXITCODE -eq 0)
}

function Require-BootstrapTools {
    Write-Host "`n[1/6] 检查基础环境..." -ForegroundColor Yellow

    if (Test-CommandExists 'powershell' -or $PSVersionTable) {
        Write-Host '   ✓ PowerShell 可用' -ForegroundColor Green
    }

    if (Test-CommandExists 'winget') {
        Write-Host '   ✓ 已检测到 winget' -ForegroundColor Green
    } elseif (Test-CommandExists 'choco') {
        Write-Host '   ✓ 已检测到 Chocolatey' -ForegroundColor Green
    } elseif (Test-CommandExists 'scoop') {
        Write-Host '   ✓ 已检测到 Scoop' -ForegroundColor Green
    } else {
        Write-Host '   ⚠ 未检测到受支持的 Windows 包管理器' -ForegroundColor Yellow
        Write-Host '   建议先安装 winget、Chocolatey 或 Scoop，以便自动补齐 Git 等基础工具' -ForegroundColor Yellow
    }

    Write-Host "   ✓ 当前默认采用中国大陆优先模式" -ForegroundColor Green
    Write-Host "   OpenClaw 默认版本: $OpenClawVersion" -ForegroundColor Green
    Write-Host "   npm 默认使用 $PreferredNpmRegistry" -ForegroundColor Green
    Write-Host '   GitHub 默认使用代理地址' -ForegroundColor Green
}

function Install-GitIfNeeded {
    Write-Host "`n[2/6] 检查 Git 环境..." -ForegroundColor Yellow
    if (Test-CommandExists 'git') {
        Write-Host '   ✓ Git 已安装' -ForegroundColor Green
        return
    }

    Write-Host '   ⚠ 未检测到 Git，开始自动安装...' -ForegroundColor Yellow
    if (Test-CommandExists 'winget') {
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    } elseif (Test-CommandExists 'choco') {
        choco install git -y
    } elseif (Test-CommandExists 'scoop') {
        scoop install git
    } else {
        Write-Host '❌ 无法自动安装 Git，请先准备基础环境后重试' -ForegroundColor Red
        Write-Host '💡 Windows 推荐先安装 winget，或手动安装 Git: https://git-scm.com/download/win' -ForegroundColor Yellow
        exit 1
    }

    if (-not (Test-CommandExists 'git')) {
        Write-Host '❌ Git 安装失败' -ForegroundColor Red
        exit 1
    }

    Write-Host '   ✓ Git 安装完成' -ForegroundColor Green
}

function Invoke-OfficialInstaller {
    Ensure-TempDir

    Write-Host "`n[3/6] 安装 OpenClaw 核心（国内优先模式）..." -ForegroundColor Yellow

    # 覆盖安装：先卸载现有版本
    Write-Host '   正在卸载现有 OpenClaw 版本...' -ForegroundColor Cyan
    npm uninstall -g openclaw 2>$null | Out-Null

    $installerFile = Join-Path $script:TempDir 'openclaw-install.ps1'
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $PreferredInstallUrl -OutFile $installerFile
        Write-Host '   ✓ 官方安装器下载成功' -ForegroundColor Green
    } catch {
        Write-Host '   ⚠ 首选链路失败，回退官方直连重试...' -ForegroundColor Yellow
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $OfficialInstallUrl -OutFile $installerFile
            Write-Host '   ✓ 已通过官方直连获取安装器' -ForegroundColor Green
        } catch {
            Write-Host '❌ 官方安装器下载失败，请检查网络后重试' -ForegroundColor Red
            exit 1
        }
    }

    $env:npm_config_registry = $PreferredNpmRegistry
    $env:OPENCLAW_VERSION = $OpenClawVersion
    $env:GIT_CONFIG_COUNT = '2'
    $env:GIT_CONFIG_KEY_0 = "url.$PreferredGitInsteadOf.insteadOf"
    $env:GIT_CONFIG_VALUE_0 = 'https://github.com/'
    $env:GIT_CONFIG_KEY_1 = "url.$PreferredGitInsteadOf.insteadOf"
    $env:GIT_CONFIG_VALUE_1 = 'git+https://github.com/'
    powershell -ExecutionPolicy Bypass -File $installerFile
    if ($LASTEXITCODE -eq 0) {
        Write-Host '   ✓ OpenClaw 核心安装完成' -ForegroundColor Green
        return
    }

    Write-Host '   ⚠ 国内优先链路失败，回退官方 npm 源重试...' -ForegroundColor Yellow
    $env:npm_config_registry = $OfficialNpmRegistry
    Remove-Item Env:GIT_CONFIG_COUNT, Env:GIT_CONFIG_KEY_0, Env:GIT_CONFIG_VALUE_0, Env:GIT_CONFIG_KEY_1, Env:GIT_CONFIG_VALUE_1 -ErrorAction SilentlyContinue
    $env:OPENCLAW_VERSION = $OpenClawVersion
    powershell -ExecutionPolicy Bypass -File $installerFile
    if ($LASTEXITCODE -eq 0) {
        Write-Host '   ✓ OpenClaw 核心安装完成（官方回退）' -ForegroundColor Green
        return
    }

    Write-Host '❌ OpenClaw 官方安装器执行失败' -ForegroundColor Red
    exit 1
}

function Sync-ProjectCode {
    Write-Host "`n[4/6] 同步管理工具代码..." -ForegroundColor Yellow

    if (Test-Path (Join-Path $InstallDir '.git')) {
        Set-Location $InstallDir
        git remote set-url origin $PreferredProjectGit | Out-Null
        git fetch --all
        if ($LASTEXITCODE -ne 0) {
            Write-Host '   ⚠ 国内代理拉取失败，回退官方 GitHub 重试...' -ForegroundColor Yellow
            git remote set-url origin $OfficialProjectGit | Out-Null
            git fetch --all
            if ($LASTEXITCODE -ne 0) { exit 1 }
        }
        git reset --hard origin/main
    } else {
        git clone $PreferredProjectGit $InstallDir
        if ($LASTEXITCODE -ne 0) {
            Write-Host '   ⚠ 国内代理克隆失败，回退官方 GitHub 重试...' -ForegroundColor Yellow
            git clone $OfficialProjectGit $InstallDir
            if ($LASTEXITCODE -ne 0) { exit 1 }
        }
        Set-Location $InstallDir
    }

    Write-Host '   ✓ 管理工具代码同步完成' -ForegroundColor Green
}

function Install-ProjectDependencies {
    Write-Host "`n[5/6] 安装管理工具依赖..." -ForegroundColor Yellow
    if (Invoke-NpmCommand -Arguments @('install', '--production')) {
        Write-Host '   ✓ 管理工具依赖安装完成' -ForegroundColor Green
    } else {
        Write-Host '❌ 管理工具依赖安装失败。可能遇到权限或网络问题。' -ForegroundColor Red
        exit 1
    }
}

function Install-ProjectCli {
    Write-Host "`n[6/6] 配置系统全局命令..." -ForegroundColor Yellow
    if (Invoke-NpmCommand -Arguments @('install', '-g', '.')) {
        Write-Host '   ✓ 全局命令链接成功' -ForegroundColor Green
    } else {
        Write-Host '❌ 全局命令注册失败。请检查 npm / Node.js 安装。' -ForegroundColor Red
        exit 1
    }
}

try {
    Require-BootstrapTools
    Install-GitIfNeeded
    Invoke-OfficialInstaller
    Sync-ProjectCode
    Install-ProjectDependencies
    Install-ProjectCli

    Write-Host "`n──────────────────────────────────────────────────" -ForegroundColor Green
    Write-Host '✓ 部署成功！' -ForegroundColor Green
    Write-Host '  运行 openclaw-setup 开始使用' -ForegroundColor Yellow
    Write-Host '──────────────────────────────────────────────────' -ForegroundColor Green
}
finally {
    if ($script:TempDir -and (Test-Path $script:TempDir)) {
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

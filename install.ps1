# OpenClaw Windows Deployment Script

$ErrorActionPreference = 'Stop'

$Version = '3.1.0'
$InstallDir = Join-Path $HOME 'OpenClaw'
$OfficialInstallUrl = 'https://openclaw.ai/install.ps1'
$OfficialProjectGit = 'https://github.com/ClawTribe/openclaw-oneclick.git'
$FallbackProjectGit = 'https://ghfast.top/https://github.com/ClawTribe/openclaw-oneclick.git'
$OfficialNpmRegistry = 'https://registry.npmjs.org/'
$FallbackNpmRegistry = 'https://registry.npmmirror.com'
$TempDir = $null

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

    & npm @Arguments --registry=$OfficialNpmRegistry
    if ($LASTEXITCODE -eq 0) {
        return $true
    }

    Write-Host '   ⚠ 官方 npm 源失败，切换到国内镜像重试...' -ForegroundColor Yellow
    & npm @Arguments --registry=$FallbackNpmRegistry
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

    if (Test-UrlAccess 'https://openclaw.ai/install.ps1') {
        Write-Host '   ✓ 官方安装器地址可访问' -ForegroundColor Green
    } else {
        Write-Host '   ⚠ 官方安装器地址当前不可达，后续可能需要代理或镜像' -ForegroundColor Yellow
    }
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

    Write-Host "`n[3/6] 安装 OpenClaw 核心（优先官方安装器）..." -ForegroundColor Yellow

    $installerFile = Join-Path $script:TempDir 'openclaw-install.ps1'
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $OfficialInstallUrl -OutFile $installerFile
        Write-Host '   ✓ 官方安装器下载成功' -ForegroundColor Green
    } catch {
        Write-Host '❌ 官方安装器下载失败，请检查网络后重试' -ForegroundColor Red
        exit 1
    }

    powershell -ExecutionPolicy Bypass -File $installerFile
    if ($LASTEXITCODE -eq 0) {
        Write-Host '   ✓ OpenClaw 核心安装完成' -ForegroundColor Green
        return
    }

    Write-Host '   ⚠ 官方安装流程失败，尝试以当前进程环境注入国内 npm 镜像后重试...' -ForegroundColor Yellow
    $env:npm_config_registry = $FallbackNpmRegistry
    powershell -ExecutionPolicy Bypass -File $installerFile
    if ($LASTEXITCODE -eq 0) {
        Write-Host '   ✓ OpenClaw 核心安装完成（fallback）' -ForegroundColor Green
        return
    }

    Write-Host '❌ OpenClaw 官方安装器执行失败' -ForegroundColor Red
    exit 1
}

function Sync-ProjectCode {
    Write-Host "`n[4/6] 同步管理工具代码..." -ForegroundColor Yellow

    if (Test-Path (Join-Path $InstallDir '.git')) {
        Set-Location $InstallDir
        git remote set-url origin $OfficialProjectGit | Out-Null
        git fetch --all
        if ($LASTEXITCODE -ne 0) {
            Write-Host '   ⚠ 官方 GitHub 拉取失败，切换代理重试...' -ForegroundColor Yellow
            git remote set-url origin $FallbackProjectGit | Out-Null
            git fetch --all
            if ($LASTEXITCODE -ne 0) { exit 1 }
        }
        git reset --hard origin/main
    } else {
        git clone $OfficialProjectGit $InstallDir
        if ($LASTEXITCODE -ne 0) {
            Write-Host '   ⚠ 官方 GitHub 克隆失败，切换代理重试...' -ForegroundColor Yellow
            git clone $FallbackProjectGit $InstallDir
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

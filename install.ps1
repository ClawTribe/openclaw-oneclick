# OpenClaw One-Click Windows Downloader (v3.1.0)
# Designed for ClawTribe/openclaw-oneclick

$ErrorActionPreference = 'Continue'
$global:Success = $false

$Version = '3.2.0'
$RepoUser = 'ClawTribe'
$RepoName = 'openclaw-oneclick'
$InstallDir = Join-Path $HOME 'OpenClaw'
$TempDir = $null

# 分发链路设置
$ProxyPrefix = 'https://ghfast.top/'
$ReleaseBaseUrl = "${ProxyPrefix}https://github.com/$RepoUser/$RepoName/releases/download/v$Version"

function Update-Environment {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = $env:Path
}

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Ensure-TempDir {
    if (-not $script:TempDir) {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("openclaw-dl-" + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }
}

function Require-BootstrapTools {
    Write-Host "`n[1/4] 检查基础环境..." -ForegroundColor Yellow
    if (-not (Test-CommandExists 'powershell')) { exit 1 }
    Write-Host '   ✓ PowerShell 核心就绪' -ForegroundColor Green
}

function Install-NodeIfNeeded {
    Write-Host "`n[2/4] 检查 Node.js 环境..." -ForegroundColor Yellow
    if (Test-CommandExists 'node' -and Test-CommandExists 'npm') {
        Write-Host '   ✓ Node.js 已就绪' -ForegroundColor Green
        return
    }

    Write-Host '   ⚠ 未检测到 Node.js，正在通过 winget 自动安装...' -ForegroundColor Yellow
    if (Test-CommandExists 'winget') {
        & winget install --id OpenJS.NodeJS.LTS -e --source winget --silent --accept-package-agreements --accept-source-agreements
        Update-Environment
    } else {
        Write-Host '❌ 无法自动安装 Node.js，请手动安装后重试: https://nodejs.org/' -ForegroundColor Red
        exit 1
    }
}

function Install-FromReleasePackage {
    Write-Host "`n[3/4] 下载预编译发行包..." -ForegroundColor Yellow
    Ensure-TempDir
    
    # 构造平台名称
    $Arch = if ([Environment]::Is64BitProcess) { "x64" } else { "x86" }
    $PackageName = "OpenClaw-Windows-$Arch.zip"
    $DownloadUrl = "$ReleaseBaseUrl/$PackageName"
    $ZipPath = Join-Path $script:TempDir $PackageName

    Write-Host "   正在从云端拉取: $PackageName" -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing
        Write-Host '   ✓ 下载完成，正在解压部署...' -ForegroundColor Green
        
        if (Test-Path $InstallDir) {
            Write-Host '   清理旧版安装目录...' -ForegroundColor Gray
            Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        
        Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
        
        # 智能路径修正：检查是否在子目录中
        if (-not (Test-Path (Join-Path $InstallDir "package.json"))) {
            $subDir = Get-ChildItem -Path $InstallDir -Directory | Select-Object -First 1
            if ($subDir -and (Test-Path (Join-Path $subDir.FullName "package.json"))) {
                Write-Host "   检测到嵌套目录，正在自动修正路径..." -ForegroundColor Gray
                Get-ChildItem -Path $subDir.FullName | Move-Item -Destination $InstallDir -Force
                Remove-Item -Path $subDir.FullName -Recurse -Force
            }
        }
        
        Write-Host "   ✓ 已成功部署至 $InstallDir" -ForegroundColor Green
    } catch {
        Write-Host "❌ 无法从 Release 页面下载包。请确认 Release 是否已发布并包含该文件。" -ForegroundColor Red
        Write-Host "💡 正在尝试回退到 Git 源码模式..." -ForegroundColor Yellow
        Install-FromGitSource
    }
}

function Install-FromGitSource {
    Write-Host "`n[3.5/4] 回退: 正在通过 Git 同步源码 (由于 Release 不可用)..." -ForegroundColor Yellow
    $GitUrl = "${ProxyPrefix}https://github.com/$RepoUser/$RepoName.git"
    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    & git clone $GitUrl $InstallDir
    Set-Location $InstallDir
    Write-Host '   正在安装依赖 (可能耗时较长并需要编译)...' -ForegroundColor Cyan
    & npm install --production --registry=https://registry.npmmirror.com
}

function Install-ProjectCli {
    Write-Host "`n[4/4] 注册系统全局命令..." -ForegroundColor Yellow
    
    # 自动解决 Windows 脚本执行策略问题（解决新手常见报错）
    if ((Get-ExecutionPolicy) -eq 'Restricted') {
        Write-Host "   检测到系统禁用脚本运行，正在为您自动授权..." -ForegroundColor Gray
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    }
    
    Set-Location $InstallDir
    & npm install -g . --registry=https://registry.npmmirror.com
    if ($LASTEXITCODE -eq 0) {
        Write-Host '   ✓ 全局命令 openclaw-setup 已激活' -ForegroundColor Green
    }
}

try {
    Require-BootstrapTools
    Install-NodeIfNeeded
    Install-FromReleasePackage
    Install-ProjectCli
    $global:Success = $true
} finally {
    if ($script:TempDir) {
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "`n──────────────────────────────────────────────────" -ForegroundColor Cyan
    if ($global:Success) {
        Write-Host "✓ OpenClaw 已成功部署！" -ForegroundColor Green
        Write-Host "  立即运行 'openclaw-setup' 开始配置。" -ForegroundColor Yellow
    } else {
        Write-Host "⚠ 安装未完全成功。请检查输出日志。" -ForegroundColor Yellow
    }
    Write-Host "请按 [回车键] 退出..." -ForegroundColor Cyan
    Read-Host
}

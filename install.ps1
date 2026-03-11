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

# Welcome banner removed by request

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

function Update-Environment {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Host '   ✓ 已刷新系统环境变量' -ForegroundColor Cyan
}

function Test-IsAdmin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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

    if (-not (Test-CommandExists 'npm')) {
        Write-Host '❌ 未检测到 npm 命令，请确认 Node.js 已正确安装并添加到 PATH。' -ForegroundColor Red
        return $false
    }

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

    if (-not (Test-IsAdmin)) {
        Write-Host '   ⚠ 注意: 当前未以管理员权限运行。自动安装组件时可能会弹出权限确认窗口。' -ForegroundColor Yellow
        Write-Host '   💡 建议退出并右键点击 PowerShell 选择“以管理员身份运行”。' -ForegroundColor Yellow
    }

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

    if (Test-CommandExists 'node') {
        $nodeVersion = node -v
        Write-Host "   ✓ Node.js $nodeVersion 已就绪" -ForegroundColor Green
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

    Write-Host '   ⚠ 未检测到 Git，开始静默安装...' -ForegroundColor Yellow
    if (Test-CommandExists 'winget') {
        Write-Host '   正在使用 winget 安装 Git (需管理员权限)...' -ForegroundColor Cyan
        & winget install --id Git.Git -e --source winget --silent --accept-package-agreements --accept-source-agreements
    } elseif (Test-CommandExists 'choco') {
        & choco install git -y
    } elseif (Test-CommandExists 'scoop') {
        & scoop install git
    } else {
        Write-Host '❌ 无法自动安装 Git，请先准备基础环境后重试' -ForegroundColor Red
        Write-Host '💡 Windows 推荐先安装 winget，或手动安装 Git: https://git-scm.com/download/win' -ForegroundColor Yellow
        exit 1
    }

    Update-Environment
    if (-not (Test-CommandExists 'git')) {
        Write-Host '❌ Git 安装成功但无法在当前会话中识别，请手动添加 Git 到 PATH 或重启终端' -ForegroundColor Red
        exit 1
    }

    Write-Host '   ✓ Git 环境已就绪' -ForegroundColor Green
}

function Install-NodeIfNeeded {
    Write-Host "`n[2.5/6] 检查 Node.js 环境..." -ForegroundColor Yellow
    if (Test-CommandExists 'node' -and Test-CommandExists 'npm') {
        Write-Host '   ✓ Node.js/npm 已就绪' -ForegroundColor Green
        return
    }

    Write-Host '   ⚠ 未检测到 Node.js，开始自动安装...' -ForegroundColor Yellow
    if (Test-CommandExists 'winget') {
        Write-Host '   正在使用 winget 安装 Node.js (LTS)...' -ForegroundColor Cyan
        & winget install --id OpenJS.NodeJS.LTS -e --source winget --silent --accept-package-agreements --accept-source-agreements
    } elseif (Test-CommandExists 'choco') {
        & choco install nodejs-lts -y
    } elseif (Test-CommandExists 'scoop') {
        & scoop install nodejs-lts
    } else {
        Write-Host '❌ 无法自动安装 Node.js，请先手动下载安装: https://nodejs.org/' -ForegroundColor Red
        exit 1
    }

    Update-Environment
    if (-not (Test-CommandExists 'node')) {
        Write-Host '❌ Node.js 安装成功但无法在当前会话中识别，请手动添加 Node 到 PATH 或重启终端' -ForegroundColor Red
        exit 1
    }
    Write-Host '   ✓ Node.js 安装完成' -ForegroundColor Green
}

function Invoke-OfficialInstaller {
    Ensure-TempDir

    Write-Host "`n[3/6] 安装 OpenClaw 核心（国内优先模式）..." -ForegroundColor Yellow

    # 在完全切断前，尝试停止可能正在后台运行的网关守护服务
    if (Test-CommandExists 'openclaw') {
        Write-Host '   正在停止可能正在运行的 OpenClaw 网关...' -ForegroundColor Cyan
        & openclaw gateway stop 2>$null | Out-Null
    }

    Write-Host '   正在卸载现有 OpenClaw 程序代码...' -ForegroundColor Cyan
    # 注: npm uninstall 只会删除软件代码，绝不会触碰用户的 ~/.openclaw 数据文件夹
    if (Test-CommandExists 'npm') {
        npm uninstall -g openclaw 2>$null | Out-Null
    }
    
    # 备份整个目录以防止丢失插件、工作区及日志
    Write-Host '   正在备份旧版工作空间与配置...' -ForegroundColor Cyan
    $configDir = Join-Path $HOME '.openclaw'
    if (Test-Path $configDir) {
        $timestamp = Get-Date -Format 'MMddHHmm'
        $backupDir = Join-Path $HOME ".openclaw_$timestamp.bak"
        Move-Item -Path $configDir -Destination $backupDir -Force
        Write-Host "   ✓ 已完整备份原配置及数据至 $backupDir" -ForegroundColor Green
    }

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
    Install-NodeIfNeeded
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

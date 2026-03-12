# Windows 步骤 2: Node.js 与 NPM 中国节点配置
$ErrorActionPreference = 'Stop'

# 兜底：若用户单独运行本脚本，或上层未注入 Write-Color，则提供本地实现
if (-not (Get-Command Write-Color -ErrorAction SilentlyContinue)) {
    function Write-Color {
        param(
            [Parameter(Mandatory = $true)][string]$Text,
            [string]$Color = 'White'
        )
        try { Write-Host $Text -ForegroundColor $Color } catch { Write-Host $Text }
    }
}

Write-Color "`n[2/3] 配置 Node.js 与 NPM 镜像缓存 (依赖 22.14.0 LTS 环境)..." "Yellow"

$tempDir = [System.IO.Path]::GetTempPath()

function Check-NodeVersion {
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) { return $false }
    $ver = node -v
    if ($ver -match "^v(\d+)\.") {
        if ([int]$matches[1] -ge 22) { return $true }
    }
    return $false
}

if (-not (Check-NodeVersion)) {
    Write-Color "   ⚠ 缺失推荐引擎或者当前 Node.js 版本低于 v22，准备进行热更新安装..." "Cyan"
    $nodeInstaller = Join-Path $tempDir "Node-Installer.msi"
    
    $nodeUrl = "https://npmmirror.com/mirrors/node/v$global:NodeVersion/node-v$global:NodeVersion-x64.msi"
    if (-not [Environment]::Is64BitOperatingSystem) {
        $nodeUrl = "https://npmmirror.com/mirrors/node/v$global:NodeVersion/node-v$global:NodeVersion-x86.msi"
    }

    Write-Color "   ➤ 下载淘宝离线 MSI ($nodeUrl) ..." "Gray"
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        $p = Start-Process -FilePath "curl.exe" -ArgumentList "-fSL", "--progress-bar", "$nodeUrl", "-o", "`"$nodeInstaller`"" -Wait -NoNewWindow -PassThru
        if ($p.ExitCode -ne 0) { throw "下载 Node 失败" }
    } else {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeInstaller -UseBasicParsing -TimeoutSec 120
        $ProgressPreference = 'Continue'
    }
    
    Write-Color "   ➤ 强制静默写入系统注册表... " "Yellow"
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$nodeInstaller`" /qn /norestart" -Wait -NoNewWindow -PassThru
    
    if ($process.ExitCode -ne 0) {
        Write-Color "❌ 安装 Node.js 严重失败 (退出码: $($process.ExitCode))" "Red"
        exit 1
    }
}

# 刷新 PowerShell 会话的环境变量 PATH 以防止刚安装完找不到命令
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

if (Check-NodeVersion) {
    Write-Color "   ✓ Node v22.x 调度中心运行中" "Green"
} else {
    Write-Color "❌ 系统 PATH 未能自动重载，无法调用刚安装的 Node。请重启电脑后重试。" "Red"
    exit 1
}

# 连通淘宝源
if (Get-Command npm -ErrorAction SilentlyContinue) {
    & npm config set registry $global:NpmRegistry
    & npm config set update-notifier false
    Write-Color "   ✓ npm 连接池已切换至 $global:NpmRegistry" "Green"
} else {
    Write-Color "❌ npm 包管理器缺失或未加入环境。" "Red"
    exit 1
}

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

Write-Color "`n[2/3] 配置 Node.js 与 NPM 镜像缓存 (需要 v$global:NodeVersion+)..." "Yellow"

$tempDir = [System.IO.Path]::GetTempPath()

# 精确版本比较：当前版本 >= 要求版本
function Test-NodeVersionOk {
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) { return $false }
    $ver = node -v
    if ($ver -match '^v?(\d+)\.(\d+)\.(\d+)') {
        $curMajor = [int]$matches[1]; $curMinor = [int]$matches[2]; $curPatch = [int]$matches[3]
    } else {
        return $false
    }
    # 解析要求的版本
    if ($global:NodeVersion -match '^v?(\d+)\.(\d+)\.(\d+)') {
        $reqMajor = [int]$matches[1]; $reqMinor = [int]$matches[2]; $reqPatch = [int]$matches[3]
    } else {
        return $false
    }
    if ($curMajor -gt $reqMajor) { return $true }
    if ($curMajor -lt $reqMajor) { return $false }
    if ($curMinor -gt $reqMinor) { return $true }
    if ($curMinor -lt $reqMinor) { return $false }
    return ($curPatch -ge $reqPatch)
}

if (-not (Test-NodeVersionOk)) {
    if (Get-Command node -ErrorAction SilentlyContinue) {
        $curVer = node -v
        Write-Color "   ⚠ 当前 Node.js $curVer 版本低于要求 (需要 v$global:NodeVersion+)，准备升级..." "Cyan"
    } else {
        Write-Color "   ⚠ 未找到 Node.js，准备安装 v$global:NodeVersion..." "Cyan"
    }
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

if (Test-NodeVersionOk) {
    Write-Color "   ✓ Node.js $(node -v) 核心运转中" "Green"
} else {
    $curVer = if (Get-Command node -ErrorAction SilentlyContinue) { node -v } else { "未安装" }
    Write-Color "❌ Node.js 版本不满足要求：当前 $curVer，需要 v$global:NodeVersion+" "Red"
    Write-Color "   请手动安装 Node.js v$global:NodeVersion 后重试。" "Yellow"
    exit 1
}

# 连通淘宝源
if (Get-Command npm -ErrorAction SilentlyContinue) {
    cmd /c "npm config set registry $global:NpmRegistry 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Color "   ⚠ npm  registry 配置可能未成功，继续执行..." "Yellow"
    }
    cmd /c "npm config set update-notifier false 2>&1"
    Write-Color "   ✓ npm 连接池已切换至 $global:NpmRegistry" "Green"
} else {
    Write-Color "❌ npm 包管理器缺失或未加入环境。" "Red"
    exit 1
}

# 确保成功退出时返回 0
exit 0

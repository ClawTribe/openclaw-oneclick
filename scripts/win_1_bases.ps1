# Windows 步骤 1: 权限与基础环境 (Git)
$ErrorActionPreference = 'Stop'

Write-Color "`n[1/3] 正在梳理系统基础环境 (Git与权限策略)..." "Yellow"

if ((Get-ExecutionPolicy) -eq 'Restricted') {
    Write-Color "   ➤ 检测到系统禁用脚本，这可能阻碍安装过程。自动授权中..." "Gray"
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
}

$tempDir = [System.IO.Path]::GetTempPath()

# 检查是否已有 Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Color "   ⚠ 未检测到 Git 平台工具，将启动静默加速安装..." "Cyan"
    $gitInstaller = Join-Path $tempDir "Git-Installer.exe"
    
    $gitUrl = "https://npmmirror.com/mirrors/git-for-windows/v2.44.0.windows.1/Git-2.44.0-64-bit.exe"
    if (-not [Environment]::Is64BitOperatingSystem) {
        $gitUrl = "https://npmmirror.com/mirrors/git-for-windows/v2.44.0.windows.1/Git-2.44.0-32-bit.exe"
    }
    
    Write-Color "   ➤ 正在从淘宝直连拉取客户端 ($gitUrl) ..." "Gray"
    Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing -TimeoutSec 120
    
    Write-Color "   ➤ 后台安装中。如果您看到 UAC 系统询问窗口，请点击 [允许 / 是] ..." "Yellow"
    $args = @("/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-", "/SUPPRESSMSGBOXES")
    $process = Start-Process -FilePath $gitInstaller -ArgumentList $args -Wait -NoNewWindow -PassThru
    
    if ($process.ExitCode -ne 0) {
        Write-Color "❌ Git 自动化平台未能成功嵌入系统，核心流程中断 (退出码: $($process.ExitCode))" "Red"
        exit 1
    }
    Write-Color "   ✓ Git 平台部署成功" "Green"
} else {
    Write-Color "   ✓ Git 引擎已就绪：$((git --version) -join ' ')" "Green"
}

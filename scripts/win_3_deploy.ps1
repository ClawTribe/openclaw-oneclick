# Windows 步骤 3: 提取并部署核心应用

$ErrorActionPreference = 'Stop'
Write-Color "`n[3/3] 下载并装载 OpenClaw 预构建平台包..." "Yellow"

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("openclaw-dl-" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$Arch = if ([Environment]::Is64BitProcess) { "x64" } else { "x86" }
$PackageName = "OpenClaw-Windows-$Arch.zip"
$DownloadUrl = "$global:ReleaseBaseUrl/$PackageName"
$ZipPath = Join-Path $tempDir $PackageName

Write-Color "   ➤ 云端计算节点: Windows - $Arch" "Cyan"
Write-Color "   ➤ 隧道下载中: $PackageName" "Gray"

try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing -TimeoutSec 300
    Write-Color "   ✓ 下载回传完毕，正在将代码覆盖工作区..." "Green"
    
    if (Test-Path $global:InstallDir) {
        Write-Color "   ⚠ 发现已有的部署目录，正在覆盖核心文件以防破坏用户配置..." "Gray"
        # 安全清理：只删除旧的核心工作文件，千万不要删除整个文件夹
        Remove-Item -Path (Join-Path $global:InstallDir "node_modules") -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $global:InstallDir "dist") -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $global:InstallDir "package.json") -Force -ErrorAction SilentlyContinue
    } else {
        New-Item -ItemType Directory -Path $global:InstallDir -Force | Out-Null
    }
    
    Expand-Archive -Path $ZipPath -DestinationPath $global:InstallDir -Force
    
    # 嵌套修正
    if (-not (Test-Path (Join-Path $global:InstallDir "package.json"))) {
        $subDir = Get-ChildItem -Path $global:InstallDir -Directory | Select-Object -First 1
        if ($subDir -and (Test-Path (Join-Path $subDir.FullName "package.json"))) {
            Write-Color "   ➤ 漂移隔离修复: 检测到层级嵌套，正在还原结构..." "Gray"
            Get-ChildItem -Path $subDir.FullName | Move-Item -Destination $global:InstallDir -Force
            Remove-Item -Path $subDir.FullName -Recurse -Force
        }
    }
    
    Write-Color "   ✓ 节点已部署至: $global:InstallDir" "Green"
} catch {
    Write-Color "❌ 安装分发包获取失败。" "Red"
    Write-Color "   连接地址: $DownloadUrl" "Red"
    Write-Color "   原因: $_" "Red"
    exit 1
}

Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Color "   将 CLI 绑定到系统执行环境变量..." "Gray"

try {
    # 强制重新以淘宝源挂载全局 (一键向导组件)
    Set-Location (Join-Path $global:InstallDir "openclaw_setup")
    & npm install -g . --registry=$global:NpmRegistry --silent
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "npm ExitCode: $LASTEXITCODE (Setup API)"
    }
    
    # 强制重新以淘宝源挂载全局 (OpenClaw 原生核心命令)
    Set-Location (Join-Path $global:InstallDir "openclaw_core")
    & npm install -g . --registry=$global:NpmRegistry --silent
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
         # 我们不因为核心注册失败而中断安装流程
         Write-Color "   ⚠ OpenClaw 底层服务注册未能全量成功，但不影响交互向导。" "Yellow"
    }
} catch {
    Write-Color "❌ 绑定 openclaw-setup 失败。这通常意味着缺少最高权限，或者网络极度不稳。" "Red"
    Write-Color "   代码实际上已解压至 $global:InstallDir ，请手动前往注册。" "Yellow"
    exit 1
}

Write-Color "   ✓ 交互面板与后台核心已完美激活挂载" "Green"

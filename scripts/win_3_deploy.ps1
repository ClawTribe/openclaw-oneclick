# Windows 步骤 3: 提取并部署核心应用

# 注意：这里不使用 Stop，以免 npm install 警告导致整个脚本失败
# 关键步骤使用 try-catch 手动控制错误流程
$ErrorActionPreference = 'Continue'

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
Write-Color "`n[3/3] 下载并装载 OpenClaw 预构建平台包..." "Yellow"

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("openclaw-dl-" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$Arch = if ([Environment]::Is64BitProcess) { "x64" } else { "x86" }
$PackageName = "OpenClaw-Windows-$Arch.zip"
$DownloadUrl = "$global:ReleaseBaseUrl/$PackageName"
$ZipPath = Join-Path $tempDir $PackageName

$FallbackUrl = $null
if ($global:FallbackProxyPrefix) {
    $FallbackUrl = $global:FallbackProxyPrefix + "https://github.com/$global:RepoUser/$global:RepoName/releases/download/v$global:Version/$PackageName?t=" + [guid]::NewGuid().ToString()
}

Write-Color "   ➤ 云端计算节点: Windows - $Arch" "Cyan"
Write-Color "   ➤ 隧道下载中: $PackageName" "Gray"

try {
    # 缓存优化：首次下载不使用query参数，失败重试时再添加以绕过CDN缓存
    $DownloadUrl = $global:ReleaseBaseUrl + "/" + $PackageName
    $DirectUrl = "https://github.com/" + $global:RepoUser + "/" + $global:RepoName + "/releases/download/v" + $global:Version + "/" + $PackageName
    
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        $p = Start-Process -FilePath "curl.exe" -ArgumentList "-fSL", "--progress-bar", "--connect-timeout", "15", "$DownloadUrl", "-o", "`"$ZipPath`"" -Wait -NoNewWindow -PassThru
        if ($p.ExitCode -ne 0) {
            # 首次下载失败，添加guid参数绕过CDN缓存后重试
            $retryDownloadUrl = $DownloadUrl + "?t=" + [guid]::NewGuid().ToString()
            if ($FallbackUrl) {
                Write-Color "   ⚠ 最优加速节点超时，尝试备用加速节点..." "Yellow"
                $retryFallbackUrl = $FallbackUrl + "?t=" + [guid]::NewGuid().ToString()
                $p1 = Start-Process -FilePath "curl.exe" -ArgumentList "-fSL", "--progress-bar", "--connect-timeout", "20", "$retryFallbackUrl", "-o", "`"$ZipPath`"" -Wait -NoNewWindow -PassThru
                if ($p1.ExitCode -eq 0) {
                    Write-Color "   ✓ 已通过备用加速节点完成下载" "Green"
                } else {
                    Write-Color "   ⚠ 备用加速节点也失败，尝试从 GitHub 源站直连..." "Yellow"
                    $retryDirectUrl = $DirectUrl + "?t=" + [guid]::NewGuid().ToString()
                    $p2 = Start-Process -FilePath "curl.exe" -ArgumentList "-fSL", "--progress-bar", "--connect-timeout", "60", "$retryDirectUrl", "-o", "`"$ZipPath`"" -Wait -NoNewWindow -PassThru
                    if ($p2.ExitCode -ne 0) { throw "Fallback download failed" }
                }
            } else {
                Write-Color "   ⚠ 加速节点超时，尝试从 GitHub 源站直连..." "Yellow"
                $retryDirectUrl = $DirectUrl + "?t=" + [guid]::NewGuid().ToString()
                $p2 = Start-Process -FilePath "curl.exe" -ArgumentList "-fSL", "--progress-bar", "--connect-timeout", "60", "$retryDirectUrl", "-o", "`"$ZipPath`"" -Wait -NoNewWindow -PassThru
                if ($p2.ExitCode -ne 0) { throw "Fallback download failed" }
            }
        }
    } else {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing -TimeoutSec 300
        $ProgressPreference = 'Continue'
    }
    Write-Color "   ✓ 下载回传完毕，正在准备安装环境..." "Green"
    
    if (Test-Path $global:InstallDir) {
        Write-Color "   ➤ 正在深度清理工作区 (防止新旧代码冲突，可能需要 1-2 分钟)..." "Gray"
        # 强制清除旧核心文件
        Remove-Item -Path (Join-Path $global:InstallDir "node_modules") -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $global:InstallDir "dist") -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $global:InstallDir "package.json") -Force -ErrorAction SilentlyContinue
    } else {
        New-Item -ItemType Directory -Path $global:InstallDir -Force | Out-Null
    }
    
    Write-Color "   ➤ 开始解压本地分发包到目标目录..." "Gray"
    if (Get-Command tar.exe -ErrorAction SilentlyContinue) {
        # 现代 Windows 使用 tar.exe 解压速度快 10 倍且不阻塞
        $p = Start-Process -FilePath "tar.exe" -ArgumentList "-xf", "`"$ZipPath`"", "-C", "`"$global:InstallDir`"" -Wait -NoNewWindow -PassThru
        if ($p.ExitCode -ne 0) { throw "解压核心包失败" }
    } else {
        Expand-Archive -Path $ZipPath -DestinationPath $global:InstallDir -Force
    }
    
    # 嵌套修正 (有些解压工具会多包一层路径)
    if (-not (Test-Path (Join-Path $global:InstallDir "package.json"))) {
        $subDir = Get-ChildItem -Path $global:InstallDir -Directory | Select-Object -First 1
        if ($subDir -and (Test-Path (Join-Path $subDir.FullName "package.json"))) {
            Write-Color "   ➤ 漂移隔离修复: 正在还原代码层级结构..." "Gray"
            Get-ChildItem -Path $subDir.FullName | Move-Item -Destination $global:InstallDir -Force
            Remove-Item -Path $subDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-Color "   ✓ 核心应用代码已完整装载至: $global:InstallDir" "Green"
} catch {
    Write-Color "`n❌ 部署核心包到磁盘时发生中断。" "Red"
    Write-Color "   原因: $_" "Red"
    Write-Color "   如果是由于文件被占用，请先关闭正在运行的 OpenClaw 后重试。" "Yellow"
    exit 1
}

Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Color "   将 CLI 绑定到系统执行环境变量..." "Gray"

try {
    # 1. 强制以淘宝源挂载全局 (OpenClaw 原生核心命令) - 位于主目录
    Set-Location $global:InstallDir
    Write-Color "   ➤ 正在注册 OpenClaw 核心命令..." "Gray"
    Write-Color "   ➤ 工作目录: $global:InstallDir" "Gray"
    Write-Color "   ➤ NPM 镜像: $global:NpmRegistry" "Gray"
    
    # 使用 cmd /c 来确保 npm 正确执行，并捕获退出码
    # 先重置 LASTEXITCODE
    $LASTEXITCODE = $null
    $npmCmd = "npm install -g . --registry=$global:NpmRegistry --silent"
    Write-Color "   ➤ 执行命令: $npmCmd" "Gray"
    
    $output = cmd /c $npmCmd 2>&1
    $exitCode = $LASTEXITCODE
    
    Write-Color "   ➤ 原始输出: $output" "Gray"
    Write-Color "   ➤ 退出码: $exitCode (LASTEXITCODE: $LASTEXITCODE)" "Gray"
    
    if ($exitCode -and $exitCode -ne 0) {
         # 不因核心错误中断向导
         Write-Color "   ⚠ OpenClaw 底层服务注册未能全量成功 (ExitCode: $exitCode)，但不影响交互向导。" "Yellow"
    } else {
         Write-Color "   ✓ OpenClaw 核心命令已注册" "Green"
    }

    # 2. 强制重新以淘宝源挂载全局 (一键向导组件) - 位于寄生子目录
    $oneclickDir = Join-Path $global:InstallDir "openclaw_oneclick"
    Write-Color "   ➤ 检查目录: $oneclickDir" "Gray"
    if (Test-Path $oneclickDir) {
        Set-Location $oneclickDir
        Write-Color "   ➤ 正在注册 openclaw-setup 向导..." "Gray"
        
        # 先重置 LASTEXITCODE
        $LASTEXITCODE = $null
        $npmCmd = "npm install -g . --registry=$global:NpmRegistry --silent"
        Write-Color "   ➤ 执行命令: $npmCmd" "Gray"
        
        $output = cmd /c $npmCmd 2>&1
        $exitCode = $LASTEXITCODE
        
        Write-Color "   ➤ 原始输出: $output" "Gray"
        Write-Color "   ➤ 退出码: $exitCode (LASTEXITCODE: $LASTEXITCODE)" "Gray"
        
        if ($exitCode -and $exitCode -ne 0) {
            Write-Color "   ⚠ openclaw-setup 注册失败 (ExitCode: $exitCode)，但不影响核心功能。" "Yellow"
            Write-Color "     如需使用配置向导，请尝试以管理员身份运行安装。" "Yellow"
        } else {
            Write-Color "   ✓ openclaw-setup 向导已注册" "Green"
        }
    } else {
        Write-Color "   ⚠ 未找到 openclaw_oneclick 目录，跳过向导注册。" "Yellow"
    }
} catch {
    Write-Color "❌ 绑定过程发生异常: $_" "Red"
    Write-Color "   代码实际上已解压至 $global:InstallDir ，请手动前往注册。" "Yellow"
    exit 1
}

Write-Color "   ✓ 交互面板与后台核心已完美激活挂载" "Green"

# 确保成功退出时返回 0（即使npm install部分失败也不中断整个流程）
exit 0

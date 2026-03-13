# OpenClaw Windows 一键安装入口脚本 (v4.0.0)
# 中国大陆深度优化版本，支持全自动拆解安装流程

$ErrorActionPreference = 'Stop'
$global:Success = $false

# --- 基础配置变量 ---
$global:Version = '3.3.13'
$global:RepoUser = 'ClawTribe'
$global:RepoName = 'openclaw-oneclick'
$global:InstallDir = Join-Path $HOME 'OpenClaw'

# --- 输出工具（必须在任何脚本/子脚本输出前可用） ---
# 说明：子流程脚本通过 `& $tempScript` 在独立脚本作用域执行，无法直接访问本脚本的 script-scope 函数。
# 将 Write-Color 定义为 global scope，确保 scripts/win_*.ps1 等远程脚本也能调用。
function global:Write-Color {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$Color = 'White'
    )
    try {
        Write-Host $Text -ForegroundColor $Color
    } catch {
        # 兼容：颜色名异常/不可用时降级为普通输出
        Write-Host $Text
    }
}

# 分发加速线路（每次运行动态测速并选择最优）
$global:ProxyCandidates = @(
  @{ Name = 'ghproxy.net';        Prefix = 'https://ghproxy.net/' },
  @{ Name = 'gh-proxy.com';       Prefix = 'https://gh-proxy.com/' },
  @{ Name = 'ghproxy.homeboyc.cn';Prefix = 'https://ghproxy.homeboyc.cn/' },
  @{ Name = 'ghproxy.cn';         Prefix = 'https://ghproxy.cn/' },
  @{ Name = 'ghp.ci';             Prefix = 'https://ghp.ci/' },
  @{ Name = 'ghfast.top';         Prefix = 'https://ghfast.top/' },
  @{ Name = 'mirror.ghproxy.com'; Prefix = 'https://mirror.ghproxy.com/' },
  @{ Name = 'direct';             Prefix = '' }
)

function Get-PlatformPackageName {
    # 仅用于测速 Release 链路：按当前系统架构推导包名，避免测速到不存在的文件导致误判
    $arch = if ([Environment]::Is64BitProcess) { "x64" } else { "x86" }
    return "OpenClaw-Windows-$arch.zip"
}

function Invoke-Probe {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [string]$HeaderName,
        [string]$HeaderValue
    )

    try {
        $headers = @{}
        if ($HeaderName) { $headers[$HeaderName] = $HeaderValue }

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        # 用 HEAD + 短超时做轻量探测；对 Release 用 Range 防止大流量
        $resp = Invoke-WebRequest -Uri $Url -Method Head -Headers $headers -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        $sw.Stop()

        $code = [int]$resp.StatusCode
        return @{ Ok = $true; Code = $code; Total = [double]::Parse(($sw.Elapsed.TotalSeconds.ToString('F3'))) }
    } catch {
        return @{ Ok = $false; Code = 0; Total = 999 }
    }
}

function Score-Proxy {
    param(
        [Parameter(Mandatory=$true)][hashtable]$Candidate,
        [int]$Tries = 2
    )

    $ok = 0
    $sum = 0.0
    $totalTries = $Tries * 2

    $rawPath = "https://raw.githubusercontent.com/$global:RepoUser/$global:RepoName/main/scripts/win_1_bases.ps1"
    $rawUrl = $Candidate.Prefix + $rawPath

    for ($i=0; $i -lt $Tries; $i++) {
        $r = Invoke-Probe -Url $rawUrl
        if ($r.Ok -and ($r.Code -ge 200 -and $r.Code -lt 400)) { $ok++; $sum += $r.Total }
    }

    $pkg = Get-PlatformPackageName
    $relPath = "https://github.com/$global:RepoUser/$global:RepoName/releases/download/v$global:Version/$pkg"
    $relUrl = $Candidate.Prefix + $relPath

    for ($i=0; $i -lt $Tries; $i++) {
        $r = Invoke-Probe -Url $relUrl -HeaderName 'Range' -HeaderValue 'bytes=0-1048575'
        if ($r.Ok -and ($r.Code -eq 200 -or $r.Code -eq 206 -or ($r.Code -ge 300 -and $r.Code -lt 400))) { $ok++; $sum += $r.Total }
    }

    $avg = if ($ok -gt 0) { [math]::Round(($sum / $ok), 3) } else { 999 }
    return @{ Name=$Candidate.Name; Prefix=$Candidate.Prefix; Ok=$ok; Total=$totalTries; Avg=$avg }
}

function Select-BestProxy {
    param([int]$Tries = 1)

    Write-Color "➤ 正在测试Openclaw可用加速源..." "Yellow"

    $best = $null
    foreach ($c in $global:ProxyCandidates) {
        # direct 直连在中国大陆经常很慢：不参与“最优线路”评选
        # 只有当所有加速源都不可用时才会回退到 direct（由后续脚本拉取/下载逻辑兜底）
        if ($c.Name -eq 'direct') { continue }
        $s = Score-Proxy -Candidate $c -Tries $Tries
        Write-Color ("   - {0}: ok={1}/{2} avg={3}s" -f $s.Name, $s.Ok, $s.Total, $s.Avg) "Cyan"

        if (-not $best) {
            $best = $s
        } elseif ($s.Ok -gt $best.Ok) {
            $best = $s
        } elseif ($s.Ok -eq $best.Ok -and $s.Avg -lt $best.Avg) {
            $best = $s
        }
    }

    return $best
}

function Select-FallbackProxy {
    param(
        # 允许空字符串：当最优线路为 direct 时 Prefix=''，依然需要选择一个备用线路
        [Parameter(Mandatory=$true)][AllowEmptyString()][string]$ChosenPrefix,
        [int]$Tries = 1
    )

    $best = $null
    foreach ($c in $global:ProxyCandidates) {
        if ($c.Prefix -eq $ChosenPrefix) { continue }
        $s = Score-Proxy -Candidate $c -Tries $Tries
        if (-not $best) {
            $best = $s
        } elseif ($s.Ok -gt $best.Ok) {
            $best = $s
        } elseif ($s.Ok -eq $best.Ok -and $s.Avg -lt $best.Avg) {
            $best = $s
        }
    }
    return $best
}

$best = Select-BestProxy -Tries 1
$fallback = Select-FallbackProxy -ChosenPrefix $best.Prefix -Tries 1

# 默认首选加速源（兼容旧变量命名）
$ProxyPrefix = $best.Prefix
$global:FallbackProxyPrefix = $fallback.Prefix

Write-Color ("✓ 已选择最优线路: {0}（备用: {1}）" -f $best.Name, $fallback.Name) "Green"

if ($ProxyPrefix) {
  $global:ReleaseBaseUrl = "${ProxyPrefix}https://github.com/$global:RepoUser/$global:RepoName/releases/download/v$global:Version"
  $global:RawBaseUrl = "${ProxyPrefix}https://raw.githubusercontent.com/$global:RepoUser/$global:RepoName/main/scripts"
} else {
  $global:ReleaseBaseUrl = "https://github.com/$global:RepoUser/$global:RepoName/releases/download/v$global:Version"
  $global:RawBaseUrl = "https://raw.githubusercontent.com/$global:RepoUser/$global:RepoName/main/scripts"
}
$global:NodeVersion = '22.14.0'
$global:NpmRegistry = 'https://registry.npmmirror.com'

Write-Color "`n──────────────────────────────────────────────────" "Cyan"
Write-Color "  🚀 OpenClaw 环境管家 (Windows)" "Cyan"
Write-Color "  正在为您进行全自动环境梳理与部署..." "Cyan"
Write-Color "──────────────────────────────────────────────────`n" "Cyan"

# 预检：磁盘空间 (至少 500MB)
$homeDrive = $env:SystemDrive.Replace(':', '')
$freeMB = (Get-PSDrive -Name $homeDrive).Free / 1MB
if ($freeMB -lt 500) {
    Write-Color "❌ 磁盘空间不足！" "Red"
    Write-Color "   当前驱动器 ($($env:SystemDrive)) 剩余约 $([int]$freeMB)MB" "Yellow"
    Write-Color "   安装全过程(Node+Git+Core)需要约 500MB 空间，请清理后再启动脚本。" "Yellow"
    exit 1
}

function Run-RemoteScript {
    param([string]$ScriptName)
    
    Write-Color "➤ 正在拉取流程套件: $ScriptName ..." "Gray"
    
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $tempScript = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString() + ".ps1")
        
        $ProgressPreference = 'SilentlyContinue'

        $directBase = "https://raw.githubusercontent.com/$global:RepoUser/$global:RepoName/main/scripts"

        $candidates = @(
          "$global:RawBaseUrl/$ScriptName"
        )

        if ($global:FallbackProxyPrefix) {
          $candidates += ($global:FallbackProxyPrefix + "https://raw.githubusercontent.com/$global:RepoUser/$global:RepoName/main/scripts/$ScriptName")
        }
        $candidates += "$directBase/$ScriptName"

        $resp = $null
        $lastErr = $null
        foreach ($u in $candidates) {
          try {
            $resp = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
            if ($resp -and $resp.Content) { break }
          } catch {
            $lastErr = $_
          }
        }
        if (-not $resp) { throw "All download candidates failed. LastError: $lastErr" }
        $ProgressPreference = 'Continue'
        
        # 强制将下载的源文件保存为带 BOM 的 UTF-8（解决 Win10 PS5.1 下中文字符串截断与乱码报错的问题）
        [System.IO.File]::WriteAllText($tempScript, $resp.Content, [System.Text.Encoding]::UTF8)
    } catch {
        # 降级尝试本地查找（为了开发人员本地测试和极低网速下的备用方案）
        $localPath = Join-Path $PWD "scripts\$ScriptName"
        if (Test-Path $localPath) {
            Copy-Item $localPath $tempScript
        } else {
            Write-Color "❌ 无法获取依赖流程文件 $ScriptName ，请检查网络或配置代理。" "Red"
            exit 1
        }
    }

    try {
        & $tempScript
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) { throw "Script exit code $LASTEXITCODE" }
    } catch {
        Write-Color "❌ 流程 $ScriptName 异常中断: $_" "Red"
        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        exit 1
    }
    Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
}

try {
    # 流程 1: Windows 基础权限开放以及 Git 和常用环境检查
    Run-RemoteScript "win_1_bases.ps1"
    
    # 流程 2: Node.js 淘宝镜像高速拉取与静默安装
    Run-RemoteScript "win_2_node.ps1"
    
    # 流程 3: 开箱下载 Release Zip 包、提取、绑定命令
    Run-RemoteScript "win_3_deploy.ps1"
    
    $global:Success = $true
    
    # 自动执行初始化和启动
    if ($global:Success) {
        Write-Color "`n──────────────────────────────────────────────────" "Cyan"
        Write-Color "  🚀 正在自动完成初始化配置..." "Cyan"
        Write-Color "──────────────────────────────────────────────────`n" "Cyan"
        
        try {
            # 生成随机 token (12位字母数字)
            $randomToken = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 12 | ForEach-Object {[char]$_})
            
            Write-Color "➤ 正在执行非交互式初始化..." "Gray"
            # Windows 上 --install-daemon 会调用 schtasks 创建计划任务，通常需要管理员权限。
            # 若非管理员权限，直接跳过安装服务，避免出现 schtasks create failed。
            $isAdmin = $false
            try {
                $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            } catch { $isAdmin = $false }

            $onboardArgs = @(
                "onboard",
                "--non-interactive",
                "--accept-risk",
                "--mode", "local",
                "--gateway-auth", "token",
                "--gateway-token", $randomToken,
                "--gateway-port", "18789",
                "--gateway-bind", "loopback",
                "--skip-skills"
            )

            if ($isAdmin) {
                $onboardArgs += "--install-daemon"
            } else {
                Write-Color "⚠ 检测到非管理员权限，将跳过安装 Windows 服务（schtasks）。如需后台常驻，请用管理员方式运行 PowerShell。" "Yellow"
            }

            & openclaw @onboardArgs

            # 如果安装服务失败（或其他原因），尝试降级：去掉 --install-daemon 再跑一遍
            if (($LASTEXITCODE -ne 0) -and ($onboardArgs -contains "--install-daemon")) {
                Write-Color "⚠ 初始化返回非 0（ExitCode=$LASTEXITCODE），尝试跳过服务安装并重试..." "Yellow"
                $onboardArgs = $onboardArgs | Where-Object { $_ -ne "--install-daemon" }
                & openclaw @onboardArgs
            }

            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                throw "openclaw onboard failed (ExitCode=$LASTEXITCODE)"
            }
            
            Write-Color "" "Gray"
            Write-Color "⚠ 初始化命令已执行，如果控制台未自动打开，请按回车键继续..." "Yellow"
            $null = $Host.UI.ReadLine()
            
            Write-Color "➤ 正在启动/重启网关..." "Gray"
            & openclaw gateway restart

            # 若未安装服务，restart 可能失败；则尝试用后台方式启动 gateway run
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                Write-Color "⚠ 网关服务重启失败，尝试后台启动：openclaw gateway run" "Yellow"
                $openclawExe = (Get-Command openclaw -ErrorAction SilentlyContinue).Source
                if ($openclawExe) {
                    Start-Process -FilePath $openclawExe -ArgumentList @("gateway","run") -WindowStyle Hidden | Out-Null
                }
            }
            
            Write-Color "➤ 正在打开控制台..." "Gray"
            openclaw dashboard
            
            Write-Color "`n✓ 初始化完成！" "Green"
            Write-Color "  您现在可以在浏览器中访问控制台了。" "Green"
        } catch {
            Write-Color "`n⚠ 自动初始化过程中出现问题，您可以手动运行以下命令：" "Yellow"
            Write-Color "  openclaw onboard --install-daemon" "Cyan"
            Write-Color "  openclaw gateway restart" "Cyan"
            Write-Color "  openclaw dashboard" "Cyan"
        }
    }
} finally {
    Write-Color "`n──────────────────────────────────────────────────" "Cyan"
    if ($global:Success) {
        Write-Color "✓ OpenClaw 已成功部署并完成初始化！" "Green"
    } else {
        Write-Color "⚠ 安装未完全成功。请翻看上方的红色错误日志。" "Yellow"
    }
    Write-Color "──────────────────────────────────────────────────" "Cyan"
    Write-Color "请按 [回车键] 退出..." "Cyan"
    Read-Host
}

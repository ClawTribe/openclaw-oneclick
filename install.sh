#!/usr/bin/env bash
# OpenClaw macOS/Linux 一键安装入口脚本 (v4.0.0)
# 中国大陆深度优化版本，支持全自动拆解安装流程

set -uo pipefail

# UI（必须在任何输出之前定义；脚本开启了 set -u）
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export CYAN='\033[0;36m'
export NC='\033[0m'

# 统一日志输出到 stderr，避免被命令替换 $(...) 捕获污染变量
log() {
  echo -e "$*" >&2
}

# --- 基础配置变量 ---
export VERSION="3.3.16"
export REPO_USER="ClawTribe"
export REPO_NAME="openclaw-oneclick"
export INSTALL_DIR="$HOME/OpenClaw"

# ---- 动态选择加速源（每次运行都测速，适配不同地区/运营商）----
# 说明：这里的“前缀”需要能拼接成：
#   <prefix>https://github.com/...
#   <prefix>https://raw.githubusercontent.com/...
# 可为空字符串（表示直连）。
PROXY_CANDIDATE_NAMES=(
  "ghproxy.net"
  "gh-proxy.com"
  "ghproxy.homeboyc.cn"
  "ghproxy.cn"
  "ghp.ci"
  "ghfast.top"
  "mirror.ghproxy.com"
  "direct"
)
PROXY_CANDIDATE_PREFIXES=(
  "https://ghproxy.net/"
  "https://gh-proxy.com/"
  "https://ghproxy.homeboyc.cn/"
  "https://ghproxy.cn/"
  "https://ghp.ci/"
  "https://ghfast.top/"
  "https://mirror.ghproxy.com/"
  ""
)

raw_test_url_for_prefix() {
  local prefix="$1"
  local raw_path="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/main/scripts/mac_linux_1_bases.sh"
  echo "${prefix}${raw_path}"
}

release_test_url_for_prefix() {
  local prefix="$1"
  # 使用当前平台对应的 Release 包名进行探测，避免某些版本不存在 macOS-x64 导致误判
  local os_name arch os arch_n pkg
  os_name="$(uname -s)"
  arch="$(uname -m)"
  if [[ "$os_name" == "Darwin" ]]; then os="macOS"; else os="Linux"; fi
  if [[ "$arch" == "x86_64" ]]; then arch_n="x64"; elif [[ "$arch" == "aarch64" ]]; then arch_n="arm64"; else arch_n="$arch"; fi
  pkg="OpenClaw-${os}-${arch_n}.zip"
  local rel_path="https://github.com/$REPO_USER/$REPO_NAME/releases/download/v$VERSION/${pkg}"
  echo "${prefix}${rel_path}"
}

# 快速探测：缩短超时，优先快速失败
curl_probe() {
  local url="$1"
  local header="$2"
  # 输出：<http_code> <time_total>
  # 调整：connect 2s + max 5s = 最长 7s 必须返回（原来 15s）
  if [ -n "$header" ]; then
    curl -sS -L --connect-timeout 2 --max-time 5 -o /dev/null -H "$header" -w "%{http_code} %{time_total}" "$url" 2>/dev/null || echo "000 999"
  else
    curl -sS -L --connect-timeout 2 --max-time 5 -o /dev/null -w "%{http_code} %{time_total}" "$url" 2>/dev/null || echo "000 999"
  fi
}

download_with_fallback() {
  # args: <url1> <url2> ... -- -o <out>
  # 用法示例：download_with_fallback "$best" "$fallback" "$direct" -- -o "$file"
  local args=("$@")
  local sep_index=-1
  local i
  for i in "${!args[@]}"; do
    if [ "${args[$i]}" = "--" ]; then sep_index=$i; break; fi
  done
  if [ "$sep_index" -lt 0 ]; then
    log "${RED}❌ download_with_fallback 缺少 -- 分隔符${NC}"
    return 2
  fi

  local urls=("${args[@]:0:$sep_index}")
  local curl_args=("${args[@]:$((sep_index+1))}")

  local u
  for u in "${urls[@]}"; do
    [ -z "$u" ] && continue
    if curl -fSL --progress-bar --connect-timeout 10 --max-time 60 "$u" "${curl_args[@]}"; then
      return 0
    fi
  done
  return 1
}

verbose_log_proxy() {
  if [ "${OPENCLAW_VERBOSE_PROXY_TEST:-0}" = "1" ]; then
    log "$1"
  fi
}

score_prefix() {
  local name="$1"
  local prefix="$2"
  local tries="${3:-2}"
  local ok=0
  local sum=0

  # 1) raw 小文件（代表脚本拉取）
  local raw_url
  raw_url="$(raw_test_url_for_prefix "$prefix")"
  for _ in $(seq 1 "$tries"); do
    local out code t
    out="$(curl_probe "$raw_url" "")"
    code="$(echo "$out" | awk '{print $1}')"
    t="$(echo "$out" | awk '{print $2}')"
    if echo "$code" | grep -qE '^(200|301|302|304)$'; then
      ok=$((ok+1))
      sum=$(awk -v a="$sum" -v b="$t" 'BEGIN{printf "%.6f", a+b}')
    fi
  done

  # 2) release 小分片（代表大文件下载链路）
  local rel_url
  rel_url="$(release_test_url_for_prefix "$prefix")"
  for _ in $(seq 1 "$tries"); do
    local out code t
    out="$(curl_probe "$rel_url" "Range: bytes=0-1048575")"
    code="$(echo "$out" | awk '{print $1}')"
    t="$(echo "$out" | awk '{print $2}')"
    if echo "$code" | grep -qE '^(200|206|301|302|304)$'; then
      ok=$((ok+1))
      sum=$(awk -v a="$sum" -v b="$t" 'BEGIN{printf "%.6f", a+b}')
    fi
  done

  local total_tries=$((tries * 2))
  local avg
  if [ "$ok" -gt 0 ]; then
    avg=$(awk -v s="$sum" -v k="$ok" 'BEGIN{printf "%.3f", s/k}')
  else
    avg="999"
  fi

  # 格式：name|prefix|ok|total_tries|avg
  echo "${name}|${prefix}|${ok}|${total_tries}|${avg}"
}

select_best_proxy() {
  local tries="${1:-2}"
  local best_line=""
  local best_ok=-1
  local best_avg=999

  log "${YELLOW}➤ 正在测试Openclaw可用加速源...${NC}"

  # 两阶段：先用 1 次探测筛掉明显不可用的，再对候选进行更准确的多次测量。
  local quick_tries=1
  local deep_tries="$tries"

  # quick pass
  local quick_lines=()
  local i
  for i in $(seq 0 $((${#PROXY_CANDIDATE_NAMES[@]} - 1))); do
    local name="${PROXY_CANDIDATE_NAMES[$i]}"
    local prefix="${PROXY_CANDIDATE_PREFIXES[$i]}"

    # direct 直连在中国大陆经常很慢：不参与“最优线路”评选
    # 只有当所有加速源都不可用时，才会在下面 deep_candidates 为空时回退到 direct
    if [ "$name" = "direct" ]; then
      continue
    fi

    local line ok avg
    line="$(score_prefix "$name" "$prefix" "$quick_tries")"
    ok="$(echo "$line" | awk -F'|' '{print $3}')"
    avg="$(echo "$line" | awk -F'|' '{print $5}')"
    log "   - ${CYAN}${name}${NC}: ok=${ok}/$((quick_tries*2)) avg=${avg}s"
    verbose_log_proxy "     ${name} prefix=${prefix}"
    quick_lines+=("$line")
  done

  # deep pass：只对 quick pass 中 ok>0 的源再测更准（最多取 4 个）
  local deep_candidates=()
  for line in "${quick_lines[@]}"; do
    ok="$(echo "$line" | awk -F'|' '{print $3}')"
    if [ "$ok" -gt 0 ]; then deep_candidates+=("$line"); fi
  done

  if [ "${#deep_candidates[@]}" -eq 0 ]; then
    # 全部都不可用：直接返回 direct（由后续 fallback/直连兜底）
    echo "direct||0|$((deep_tries*2))|999"
    return 0
  fi

  # 按 avg 从小到大排序，取前 4 个做 deep
  IFS=$'\n' deep_candidates=($(printf '%s\n' "${deep_candidates[@]}" | sort -t'|' -k5,5n | head -n 4))
  unset IFS

  log "${YELLOW}➤ 正在对候选线路做二次确认...${NC}"

  for line in "${deep_candidates[@]}"; do
    local name prefix
    name="$(echo "$line" | awk -F'|' '{print $1}')"
    prefix="$(echo "$line" | awk -F'|' '{print $2}')"

    local dline dok davg
    dline="$(score_prefix "$name" "$prefix" "$deep_tries")"
    dok="$(echo "$dline" | awk -F'|' '{print $3}')"
    davg="$(echo "$dline" | awk -F'|' '{print $5}')"
    log "   * ${CYAN}${name}${NC}: ok=${dok}/$((deep_tries*2)) avg=${davg}s"

    if [ "$dok" -gt "$best_ok" ]; then
      best_ok="$dok"; best_avg="$davg"; best_line="$dline"
    elif [ "$dok" -eq "$best_ok" ]; then
      better=$(awk -v a="$davg" -v b="$best_avg" 'BEGIN{print (a<b)?1:0}')
      if [ "$better" -eq 1 ]; then
        best_ok="$dok"; best_avg="$davg"; best_line="$dline"
      fi
    fi
  done

  # 只把最终选择输出到 stdout，供调用方捕获
  echo "$best_line"
}

pick_fallback_proxy() {
  local chosen_prefix="$1"
  local tries="${2:-1}"
  local best_line=""
  local best_ok=-1
  local best_avg=999

  local i
  for i in $(seq 0 $((${#PROXY_CANDIDATE_NAMES[@]} - 1))); do
    local prefix="${PROXY_CANDIDATE_PREFIXES[$i]}"
    [ "$prefix" = "$chosen_prefix" ] && continue

    local name="${PROXY_CANDIDATE_NAMES[$i]}"
    local line ok avg
    line="$(score_prefix "$name" "$prefix" "$tries")"
    ok="$(echo "$line" | awk -F'|' '{print $3}')"
    avg="$(echo "$line" | awk -F'|' '{print $5}')"

    if [ "$ok" -gt "$best_ok" ]; then
      best_ok="$ok"; best_avg="$avg"; best_line="$line"
    elif [ "$ok" -eq "$best_ok" ]; then
      better=$(awk -v a="$avg" -v b="$best_avg" 'BEGIN{print (a<b)?1:0}')
      if [ "$better" -eq 1 ]; then
        best_ok="$ok"; best_avg="$avg"; best_line="$line"
      fi
    fi
  done

  # 如果备用也没选出来（极端情况），至少回退到 direct
  if [ -z "$best_line" ]; then
    echo "direct||0|$((tries*2))|999"
  else
    echo "$best_line"
  fi
}

BEST_LINE="$(select_best_proxy 1)"
BEST_NAME="$(echo "$BEST_LINE" | awk -F'|' '{print $1}')"
BEST_PREFIX="$(echo "$BEST_LINE" | awk -F'|' '{print $2}')"

FALLBACK_LINE="$(pick_fallback_proxy "$BEST_PREFIX" 1)"
FALLBACK_NAME="$(echo "$FALLBACK_LINE" | awk -F'|' '{print $1}')"
FALLBACK_PREFIX="$(echo "$FALLBACK_LINE" | awk -F'|' '{print $2}')"

log "${GREEN}✓ 已选择最优线路: ${CYAN}${BEST_NAME}${NC}${GREEN}（备用: ${CYAN}${FALLBACK_NAME}${NC}${GREEN}）${NC}"

export PROXY_PREFIX="$BEST_PREFIX"
export FALLBACK_PROXY_PREFIX="$FALLBACK_PREFIX"

if [ -n "$PROXY_PREFIX" ]; then
  export RELEASE_BASE_URL="${PROXY_PREFIX}https://github.com/$REPO_USER/$REPO_NAME/releases/download/v$VERSION"
  export RAW_BASE_URL="${PROXY_PREFIX}https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/main/scripts"
else
  export RELEASE_BASE_URL="https://github.com/$REPO_USER/$REPO_NAME/releases/download/v$VERSION"
  export RAW_BASE_URL="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/main/scripts"
fi

export NODE_VERSION="22.14.0"
export NPM_REGISTRY="https://registry.npmmirror.com"

echo -e "${CYAN}
──────────────────────────────────────────────────
  🚀 OpenClaw 环境管家 (macOS / Linux)
  正在为您进行全自动环境梳理部署...
──────────────────────────────────────────────────
${NC}"

# 预检：磁盘空间 (至少需要 500MB 可用空间)
FREE_KB=$(df -Pk . | awk 'NR==2 {print $4}')
if [ "$FREE_KB" -lt 512000 ]; then
    echo -e "${RED}❌ 磁盘空间严重不足！已用尽。${NC}"
    echo -e "${YELLOW}   您的系统当前仅剩约 $((FREE_KB / 1024))MB 可用空间。${NC}"
    echo -e "${YELLOW}   建议清理至少 500MB 空间后再尝试安装。您可以先运行 'df -h' 检查。${NC}"
    exit 1
fi

# 下载并执行远端功能脚本的函数
run_remote_script() {
    local script_name=$1
    local tmp_script=$(mktemp)
    
    echo -e "➤ 正在拉取流程套件: ${script_name} ..."

    # 先尝试最优加速源，其次备用加速源，再降级直连 raw.githubusercontent.com，最后尝试本地脚本
    local fetched=0
    local direct_base_url="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/main/scripts"
    local candidates=("${RAW_BASE_URL}/${script_name}")
    if [ -n "${FALLBACK_PROXY_PREFIX:-}" ]; then
      candidates+=("${FALLBACK_PROXY_PREFIX}https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/main/scripts/${script_name}")
    fi
    candidates+=("${direct_base_url}/${script_name}")

    for u in "${candidates[@]}"; do
      [ -z "$u" ] && continue
      if curl -fSL --progress-bar --connect-timeout 10 --max-time 30 "$u" -o "$tmp_script"; then
        fetched=1
        break
      fi
    done

    if [ "$fetched" -ne 1 ]; then
      # 降级备用拉取：如果远程未提供，尝试在本地寻找同名文件（便于开发者本地测试）
      if [ -f "./scripts/$script_name" ]; then
          cp "./scripts/$script_name" "$tmp_script"
      else
          echo -e "${RED}❌ 无法获取依赖流程文件 ${script_name}，请检查网络。${NC}"
          rm -f "$tmp_script"
          exit 1
      fi
    fi
    
    chmod +x "$tmp_script"
    if ! bash "$tmp_script"; then
        echo -e "${RED}❌ 流程 ${script_name} 异常中断。${NC}"
        rm -f "$tmp_script"
        exit 1
    fi
    rm -f "$tmp_script"
}

# 流程 1: 基础命令工具 (CURL, UNZIP, GIT) 的检查或安装
run_remote_script "mac_linux_1_bases.sh"

# 仅冒烟测试：只跑到流程 1（避免实际安装/解压）。
if [ "${OPENCLAW_ONLY_STEP1:-0}" = "1" ]; then
  echo -e "${GREEN}✓ 已完成流程 1 冒烟测试（OPENCLAW_ONLY_STEP1=1），后续流程已跳过。${NC}"
  exit 0
fi

# 流程 2: Node.js 环境及 NPM 镜像池的静默配置
run_remote_script "mac_linux_2_node.sh"

# 流程 3: 下载与解包 OpenClaw 预编译 Zip 包
run_remote_script "mac_linux_3_deploy.sh"

# 自动执行初始化和启动
echo -e "\n${CYAN}──────────────────────────────────────────────────${NC}"
echo -e "${CYAN}  🚀 正在自动完成初始化配置...${NC}"
echo -e "${CYAN}──────────────────────────────────────────────────${NC}"

# 生成随机 token (12位字母数字)
RANDOM_TOKEN=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 12)

echo -e "➤ 正在执行非交互式初始化..."
if openclaw onboard --non-interactive \
  --accept-risk \
  --mode local \
  --gateway-auth token \
  --gateway-token "$RANDOM_TOKEN" \
  --gateway-port 18789 \
  --gateway-bind loopback \
  --install-daemon \
  --skip-skills; then
  echo ""
  echo -e "${YELLOW}⚠ 初始化命令已执行，如果控制台未自动打开，请按回车键继续...${NC}"
  read -r
  
  echo -e "➤ 正在重启网关..."
  openclaw gateway restart
  
  echo -e "➤ 正在打开控制台..."
  openclaw dashboard
  
  echo -e "\n${GREEN}✓ 初始化完成！${NC}"
  echo -e "${GREEN}  您现在可以在浏览器中访问控制台了。${NC}"
  echo -e "${CYAN}  下一步：在终端运行 openclaw-setup 配置大模型与飞书（可重复运行修改配置）。${NC}"
else
  echo -e "\n${YELLOW}⚠ 自动初始化过程中出现问题，您可以手动运行以下命令：${NC}"
  echo -e "${CYAN}  openclaw onboard --install-daemon${NC}"
  echo -e "${CYAN}  openclaw gateway restart${NC}"
  echo -e "${CYAN}  openclaw dashboard${NC}"
  echo -e "${CYAN}  openclaw-setup  # 配置大模型与飞书${NC}"
fi

# 尝试生成 shell 补全缓存，避免用户的 ~/.zshrc source 到不存在的 openclaw.zsh 时报错
openclaw completion --shell zsh --write-state >/dev/null 2>&1 || true

# 清除 bash 命令缓存，防止缓存了安装前的空路径
hash -r 2>/dev/null || true

echo -e "\n${GREEN}──────────────────────────────────────────────────${NC}"
echo -e "${GREEN}✓ OpenClaw 已成功部署并完成初始化！${NC}"
echo -e "${GREEN}──────────────────────────────────────────────────${NC}"

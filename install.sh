#!/usr/bin/env bash
# OpenClaw macOS/Linux 一键安装入口脚本 (v4.0.0)
# 中国大陆深度优化版本，支持全自动拆解安装流程

set -uo pipefail

# --- 基础配置变量 ---
export VERSION="3.2.4"
export REPO_USER="ClawTribe"
export REPO_NAME="openclaw-oneclick"
export INSTALL_DIR="$HOME/OpenClaw"
export PROXY_PREFIX="https://ghfast.top/"
export RELEASE_BASE_URL="${PROXY_PREFIX}https://github.com/$REPO_USER/$REPO_NAME/releases/download/v$VERSION"
export NODE_VERSION="22.14.0"
export NPM_REGISTRY="https://registry.npmmirror.com"
export RAW_BASE_URL="${PROXY_PREFIX}https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/main/scripts"

# UI
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export CYAN='\033[0;36m'
export NC='\033[0m'

echo -e "${CYAN}
──────────────────────────────────────────────────
  🚀 OpenClaw 环境管家 (macOS / Linux)
  正在为您进行全自动环境梳理与云端部署...
──────────────────────────────────────────────────
${NC}"

# 下载并执行远端功能脚本的函数
run_remote_script() {
    local script_name=$1
    local script_url="${RAW_BASE_URL}/${script_name}"
    local tmp_script=$(mktemp)
    
    echo -e "➤ 正在拉取流程套件: ${script_name} ..."
    if ! curl -fSL --progress-bar --connect-timeout 10 --max-time 30 "$script_url" -o "$tmp_script"; then
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

# 流程 2: Node.js 环境及 NPM 镜像池的静默配置
run_remote_script "mac_linux_2_node.sh"

# 流程 3: 下载与解包 OpenClaw 预编译 Zip 包
run_remote_script "mac_linux_3_deploy.sh"

echo -e "\n${GREEN}──────────────────────────────────────────────────${NC}"
echo -e "${GREEN}✓ OpenClaw 部署成功！${NC}"
echo -e "${YELLOW}运行 ${NC}${CYAN}openclaw-setup${NC}${YELLOW} 开始配置${NC}"
echo -e "${GREEN}──────────────────────────────────────────────────${NC}"

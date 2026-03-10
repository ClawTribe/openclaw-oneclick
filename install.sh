#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

VERSION="3.1.0"
INSTALL_DIR="$HOME/OpenClaw"
DEFAULT_OPENCLAW_VERSION="v2026.2.26"
OPENCLAW_VERSION="${OPENCLAW_VERSION:-$DEFAULT_OPENCLAW_VERSION}"
OFFICIAL_INSTALL_URL="https://openclaw.ai/install.sh"
OFFICIAL_PROJECT_GIT="https://github.com/ClawTribe/openclaw-oneclick.git"
FALLBACK_PROJECT_GIT="https://ghfast.top/https://github.com/ClawTribe/openclaw-oneclick.git"
OFFICIAL_NPM_REGISTRY="https://registry.npmjs.org/"
FALLBACK_NPM_REGISTRY="https://registry.npmmirror.com"
TMP_DIR=""
PREFERRED_INSTALL_URL="https://openclaw.ai/install.sh"
PREFERRED_PROJECT_GIT="https://ghfast.top/https://github.com/ClawTribe/openclaw-oneclick.git"
PREFERRED_NPM_REGISTRY="https://registry.npmmirror.com"
PREFERRED_GIT_INSTEAD_OF="https://ghfast.top/https://github.com/"

echo -e "${CYAN}
──────────────────────────────────────────────────
  OpenClaw 配置管理工具
  版本: v${VERSION} | 作者: ClawTribe
──────────────────────────────────────────────────
${NC}"

echo -e "${GREEN}正在部署 OpenClaw...${NC}"

cleanup() {
    if [ -n "${TMP_DIR}" ] && [ -d "${TMP_DIR}" ]; then
        rm -rf "${TMP_DIR}"
    fi
}

trap cleanup EXIT

log_info() {
    echo -e "$1"
}

ensure_tmp_dir() {
    if [ -z "${TMP_DIR}" ]; then
        TMP_DIR="$(mktemp -d)"
    fi
}

can_access_url() {
    local url="$1"
    curl -fsSLI --max-time 8 "$url" >/dev/null 2>&1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_downloader() {
    if command_exists curl; then
        return 0
    fi

    echo -e "${RED}❌ 缺少 curl，无法下载官方安装器${NC}"
    if command_exists brew; then
        echo -e "💡 macOS / Homebrew 可执行: ${CYAN}brew install curl${NC}"
    elif command_exists apt-get; then
        echo -e "💡 Debian / Ubuntu 可执行: ${CYAN}sudo apt-get update && sudo apt-get install -y curl${NC}"
    elif command_exists dnf; then
        echo -e "💡 Fedora / RHEL 可执行: ${CYAN}sudo dnf install -y curl${NC}"
    elif command_exists yum; then
        echo -e "💡 CentOS / RHEL 可执行: ${CYAN}sudo yum install -y curl${NC}"
    else
        echo -e "💡 请先用系统包管理器安装 ${CYAN}curl${NC} 后重试"
    fi
    exit 1
}

has_supported_package_manager() {
    command_exists brew || command_exists apt-get || command_exists dnf || command_exists yum
}

require_bootstrap_tools() {
    echo -e "\n${YELLOW}[1/6] 检查基础环境...${NC}"

    require_downloader
    echo -e "   ${GREEN}✓ curl 可用${NC}"

    if has_supported_package_manager; then
        echo -e "   ${GREEN}✓ 已检测到系统包管理器${NC}"
    else
        echo -e "   ${YELLOW}⚠ 未检测到受支持的系统包管理器${NC}"
        echo -e "   ${YELLOW}  如果缺少 Git 等基础工具，脚本将无法自动补齐${NC}"
        echo -e "   ${YELLOW}  macOS 建议先安装 ${CYAN}Homebrew${NC}；Linux 请确认 ${CYAN}apt-get / dnf / yum${NC} 可用${NC}"
    fi

    if command_exists apt-get || command_exists dnf || command_exists yum; then
        if command_exists sudo || [ "$(id -u)" -eq 0 ]; then
            echo -e "   ${GREEN}✓ sudo / root 权限环境可用${NC}"
        else
            echo -e "   ${YELLOW}⚠ 未检测到 sudo，且当前不是 root${NC}"
            echo -e "   ${YELLOW}  如果需要安装 Git 等系统依赖，脚本将无法继续${NC}"
            echo -e "   ${YELLOW}  请切换到 ${CYAN}root${NC} 用户执行，或先安装 ${CYAN}sudo${NC}${NC}"
        fi
    fi

    echo -e "   ${GREEN}✓ 当前默认采用中国大陆优先模式${NC}"
    echo -e "   ${GREEN}  OpenClaw 默认版本: ${OPENCLAW_VERSION}${NC}"
    echo -e "   ${GREEN}  npm 默认使用 ${PREFERRED_NPM_REGISTRY}${NC}"
    echo -e "   ${GREEN}  GitHub 默认使用代理地址${NC}"
}

run_npm_command() {
    local npm_args=("$@")
    if npm "${npm_args[@]}" --registry="$PREFERRED_NPM_REGISTRY"; then
        return 0
    fi

    log_info "   ${YELLOW}⚠ 国内 npm 镜像失败，回退官方 npm 源重试...${NC}"
    npm "${npm_args[@]}" --registry="$OFFICIAL_NPM_REGISTRY"
}

install_git_if_needed() {
    echo -e "\n${YELLOW}[2/6] 检查 Git 环境...${NC}"
    if command -v git >/dev/null 2>&1; then
        echo -e "   ${GREEN}✓ Git 已安装${NC}"
        return 0
    fi

    echo -e "   ${YELLOW}⚠ 未检测到 Git，开始自动安装...${NC}"
    if command -v brew >/dev/null 2>&1; then
        brew install git
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y git
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y git
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y git
    else
        echo -e "${RED}❌ 无法自动安装 Git，请先准备基础环境后重试${NC}"
        echo -e "💡 macOS 可先安装 ${CYAN}Homebrew${NC}"
        echo -e "💡 Linux 请确认 ${CYAN}apt-get / dnf / yum${NC} 与 ${CYAN}sudo${NC} 可用"
        echo -e "💡 Debian / Ubuntu 常用命令: ${CYAN}apt-get update && apt-get install -y git curl sudo${NC}"
        echo -e "💡 Fedora 常用命令: ${CYAN}dnf install -y git curl sudo${NC}"
        echo -e "💡 CentOS / RHEL 常用命令: ${CYAN}yum install -y git curl sudo${NC}"
        exit 1
    fi

    if ! command -v git >/dev/null 2>&1; then
        echo -e "${RED}❌ Git 安装失败${NC}"
        exit 1
    fi

    echo -e "   ${GREEN}✓ Git 安装完成${NC}"
}

run_official_installer() {
    ensure_tmp_dir

    echo -e "\n${YELLOW}[3/6] 安装 OpenClaw 核心（国内优先模式）...${NC}"

    # 覆盖安装：先卸载现有版本并备份配置
    echo -e "   ${CYAN}正在卸载现有 OpenClaw 版本...${NC}"
    npm uninstall -g openclaw 2>/dev/null || true
    
    # 备份整个目录以防止丢失插件、工作区及日志
    echo -e "   ${CYAN}正在备份旧版工作空间与配置...${NC}"
    if [ -d "$HOME/.openclaw" ]; then
        local backup_dir="$HOME/.openclaw_$(date +%m%d%H%M).bak"
        mv "$HOME/.openclaw" "$backup_dir"
        echo -e "   ${GREEN}✓ 已完整备份原配置及数据至 ${backup_dir}${NC}"
    fi

    local installer_file="$TMP_DIR/openclaw-install.sh"
    if curl -fsSL --proto '=https' --tlsv1.2 "$PREFERRED_INSTALL_URL" -o "$installer_file"; then
        echo -e "   ${GREEN}✓ 官方安装器下载成功${NC}"
    else
        echo -e "   ${YELLOW}⚠ 首选链路失败，回退官方直连重试...${NC}"
        if curl -fsSL --proto '=https' --tlsv1.2 "$OFFICIAL_INSTALL_URL" -o "$installer_file"; then
            echo -e "   ${GREEN}✓ 已通过官方直连获取安装器${NC}"
        else
            echo -e "${RED}❌ 官方安装器下载失败，请检查网络后重试${NC}"
            exit 1
        fi
    fi

    chmod +x "$installer_file"

    if \
        GIT_CONFIG_COUNT=2 \
        GIT_CONFIG_KEY_0=url."$PREFERRED_GIT_INSTEAD_OF".insteadOf \
        GIT_CONFIG_VALUE_0=https://github.com/ \
        GIT_CONFIG_KEY_1=url."$PREFERRED_GIT_INSTEAD_OF".insteadOf \
        GIT_CONFIG_VALUE_1=git+https://github.com/ \
        npm_config_registry="$PREFERRED_NPM_REGISTRY" \
        OPENCLAW_VERSION="$OPENCLAW_VERSION" \
        OPENCLAW_NO_ONBOARD=1 \
        bash "$installer_file" --no-onboard; then
        echo -e "   ${GREEN}✓ OpenClaw 核心安装完成${NC}"
        return 0
    fi

    echo -e "   ${YELLOW}⚠ 国内优先链路失败，回退官方 npm 源重试...${NC}"

    if OPENCLAW_VERSION="$OPENCLAW_VERSION" OPENCLAW_NO_ONBOARD=1 bash "$installer_file" --no-onboard; then
        echo -e "   ${GREEN}✓ OpenClaw 核心安装完成（官方回退）${NC}"
        return 0
    fi

    echo -e "${RED}❌ OpenClaw 官方安装器执行失败${NC}"
    exit 1
}

sync_project_code() {
    echo -e "\n${YELLOW}[4/6] 同步管理工具代码...${NC}"

    local clone_url="$PREFERRED_PROJECT_GIT"
    if [ -d "$INSTALL_DIR/.git" ]; then
        cd "$INSTALL_DIR"
        git remote set-url origin "$PREFERRED_PROJECT_GIT" || true
        if ! git fetch --all && git reset --hard origin/main; then
            echo -e "   ${YELLOW}⚠ 国内代理拉取失败，回退官方 GitHub 重试...${NC}"
            git remote set-url origin "$OFFICIAL_PROJECT_GIT"
            git fetch --all
            git reset --hard origin/main
        fi
    else
        if ! git clone "$clone_url" "$INSTALL_DIR"; then
            echo -e "   ${YELLOW}⚠ 国内代理克隆失败，回退官方 GitHub 重试...${NC}"
            git clone "$OFFICIAL_PROJECT_GIT" "$INSTALL_DIR"
        fi
        cd "$INSTALL_DIR"
    fi

    echo -e "   ${GREEN}✓ 管理工具代码同步完成${NC}"
}

install_project_dependencies() {
    echo -e "\n${YELLOW}[5/6] 安装管理工具依赖...${NC}"
    if run_npm_command install --production; then
        echo -e "   ${GREEN}✓ 管理工具依赖安装完成${NC}"
    else
        echo -e "${RED}❌ 管理工具依赖安装失败${NC}"
        echo -e "💡 建议执行 ${CYAN}sudo chown -R \$USER:\$USER ~/.npm${NC} 修复缓存权限"
        echo -e "💡 或者执行 ${CYAN}df -h${NC} 检查磁盘容量"
        exit 1
    fi
}

install_project_cli() {
    echo -e "\n${YELLOW}[6/6] 配置系统全局命令...${NC}"
    chmod +x src/index.js

    if run_npm_command install -g .; then
        echo -e "   ${GREEN}✓ 全局命令链接成功${NC}"
    else
        echo -e "${RED}❌ 全局命令注册失败${NC}"
        exit 1
    fi
}

require_bootstrap_tools
install_git_if_needed
run_official_installer
sync_project_code
install_project_dependencies
install_project_cli

echo -e "\n${GREEN}──────────────────────────────────────────────────${NC}"
echo -e "${GREEN}✓ 部署成功！${NC}"
echo -e "  运行 ${YELLOW}openclaw-setup${NC} 开始使用"
echo -e "${GREEN}──────────────────────────────────────────────────${NC}"

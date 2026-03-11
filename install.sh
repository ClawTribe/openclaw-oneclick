#!/usr/bin/env bash
# OpenClaw One-Click macOS/Linux Downloader (v3.2.0)
# Designed for ClawTribe/openclaw-oneclick

set -uo pipefail

# 变量设置
VERSION="3.2.2"
REPO_USER="ClawTribe"
REPO_NAME="openclaw-oneclick"
INSTALL_DIR="$HOME/OpenClaw"
PROXY_PREFIX="https://ghfast.top/"
RELEASE_BASE_URL="${PROXY_PREFIX}https://github.com/$REPO_USER/$REPO_NAME/releases/download/v$VERSION"
NPM_REGISTRY="https://registry.npmmirror.com"

# 追踪状态
FAILURE=0

# UI 助手
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}
──────────────────────────────────────────────────
  OpenClaw 官方分发下载器 (macOS / Linux)
  版本: v${VERSION} | 作者: ClawTribe
──────────────────────────────────────────────────
${NC}"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

pause_on_exit() {
    if [ $FAILURE -ne 0 ]; then
        echo -e "\n${YELLOW}──────────────────────────────────────────────────${NC}"
        echo -e "${YELLOW}⚠ 部署过程中遇到了一些问题，请检查上方的错误提示。${NC}"
        echo -e "${CYAN}请按 [回车键] 退出...${NC}"
        read -r
    fi
}

trap pause_on_exit EXIT

require_bootstrap_tools() {
    echo -e "\n${YELLOW}[1/4] 检查基础环境...${NC}"
    
    # 检查 curl
    if ! command_exists curl; then
        echo -e "${RED}❌ 缺少 curl，请先安装。${NC}"
        FAILURE=1 && exit 1
    fi
    echo -e "   ${GREEN}✓ curl 工具就绪${NC}"

    # 检查 unzip
    if ! command_exists unzip; then
        echo -e "   ${YELLOW}⚠ 缺少 unzip 解压工具，正在尝试自动获取...${NC}"
        if command_exists apt-get; then
            sudo apt-get update && sudo apt-get install -y unzip
        elif command_exists yum; then
            sudo yum install -y unzip
        elif command_exists dnf; then
            sudo dnf install -y unzip
        elif command_exists brew; then
            brew install unzip
        fi

        if ! command_exists unzip; then
            echo -e "${RED}❌ 无法自动安装 unzip，请手动安装后重试。${NC}"
            echo -e "   💡 Debian/Ubuntu: ${CYAN}sudo apt install unzip${NC}"
            echo -e "   💡 CentOS/Fedora: ${CYAN}sudo yum install unzip${NC}"
            FAILURE=1 && exit 1
        fi
    fi
    echo -e "   ${GREEN}✓ unzip 工具就绪${NC}"
}

install_node_if_needed() {
    echo -e "\n${YELLOW}[2/4] 检查 Node.js 环境...${NC}"
    if command_exists node && command_exists npm; then
        echo -e "   ${GREEN}✓ Node.js $(node -v) 已就绪${NC}"
        return 0
    fi

    echo -e "   ${YELLOW}⚠ 未检测到 Node.js，请执行以下命令进行安装：${NC}"
    if command_exists brew; then
        echo -e "   💡 可运行: ${CYAN}brew install node@22${NC}"
    else
        echo -e "   💡 可参考: https://nodejs.org/en/download/"
    fi
    FAILURE=1 && exit 1
}

install_from_git_source() {
    echo -e "\n${YELLOW}[3.5/4] 回退: 正在通过 Git 同步源码 (由于 Release 不可用)...${NC}"
    local GIT_URL="${PROXY_PREFIX}https://github.com/$REPO_USER/$REPO_NAME.git"
    
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "${INSTALL_DIR:?}"
    fi
    
    if ! command_exists git; then
        echo -e "   ${RED}❌ 缺少 git，无法从源码安装。请手动安装 git 后重试。${NC}"
        FAILURE=1 && exit 1
    fi
    
    git clone "$GIT_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR" || exit 1
    echo -e "   ${YELLOW}正在安装依赖 (可能耗时较长并需要编译)...${NC}"
    npm install --production --registry="$NPM_REGISTRY"
}

install_from_release_package() {
    echo -e "\n${YELLOW}[3/4] 下载并解压预编译发行包...${NC}"
    
    # 获取系统和架构
    OS_NAME=$(uname -s)
    ARCH=$(uname -m)
    
    if [[ "$OS_NAME" == "Darwin" ]]; then
        OS="macOS"
    else
        OS="Linux"
    fi
    
    # 重命名架构
    if [[ "$ARCH" == "x86_64" ]]; then ARCH="x64"; fi
    if [[ "$ARCH" == "aarch64" ]]; then ARCH="arm64"; fi
    
    PACKAGE_NAME="OpenClaw-${OS}-${ARCH}.zip"
    DOWNLOAD_URL="${RELEASE_BASE_URL}/${PACKAGE_NAME}"
    TMP_DIR=$(mktemp -d)
    ZIP_PATH="${TMP_DIR}/${PACKAGE_NAME}"
    
    echo -e "   目标平台: ${OS} (${ARCH})"
    echo -e "   正在从云端拉取: ${PACKAGE_NAME}"
    
    if curl -fSL --connect-timeout 15 --max-time 300 "$DOWNLOAD_URL" -o "$ZIP_PATH" 2>/dev/null; then
        echo -e "   ${GREEN}✓ 下载完成，正在解压部署...${NC}"
        
        if [ -d "$INSTALL_DIR" ]; then
            echo -e "   清理旧版安装目录..."
            rm -rf "${INSTALL_DIR:?}"
        fi
        mkdir -p "$INSTALL_DIR"
        
        unzip -oq "$ZIP_PATH" -d "$INSTALL_DIR"
        
        # 智能路径修正：检查是否在子目录中 (与 install.ps1 对齐)
        if [ ! -f "$INSTALL_DIR/package.json" ]; then
            local SUB_DIR
            SUB_DIR=$(find "$INSTALL_DIR" -maxdepth 1 -mindepth 1 -type d | head -n 1)
            if [ -n "$SUB_DIR" ] && [ -f "$SUB_DIR/package.json" ]; then
                echo -e "   检测到嵌套目录，正在自动修正路径..."
                mv "$SUB_DIR"/* "$SUB_DIR"/.??* "$INSTALL_DIR/" 2>/dev/null || true
                rm -rf "$SUB_DIR"
            fi
        fi
        
        echo -e "   ${GREEN}✓ 已成功部署至 $INSTALL_DIR${NC}"
    else
        echo -e "   ${RED}❌ 从发行版本下载失败。可能是 Release 未发布或无此架构文件。${NC}"
        echo -e "   ${YELLOW}💡 正在尝试回退到 Git 源码模式...${NC}"
        install_from_git_source
    fi
    
    # 清理临时目录
    [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"
}

install_project_cli() {
    echo -e "\n${YELLOW}[4/4] 注册系统全局命令...${NC}"
    cd "$INSTALL_DIR" || exit 1
    if npm install -g . --registry="$NPM_REGISTRY"; then
        echo -e "   ${GREEN}✓ 全局命令 openclaw-setup 已解锁${NC}"
    else
        echo -e "${RED}❌ 全局命令注册失败，可能需要 sudo 权限。${NC}"
        FAILURE=1 && exit 1
    fi
}

# 执行流程
require_bootstrap_tools
install_node_if_needed
install_from_release_package
install_project_cli

echo -e "\n${GREEN}──────────────────────────────────────────────────${NC}"
echo -e "${GREEN}✓ 部署成功！${NC}"
echo -e "${YELLOW}运行 openclaw-setup 开始配置${NC}"
echo -e "${GREEN}──────────────────────────────────────────────────${NC}"

#!/bin/bash

# --- 样式定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

VERSION="3.0.9"

echo -e "${CYAN}
──────────────────────────────────────────────────
  OpenClaw 配置管理工具
  版本: v${VERSION} | 作者: ClawTribe
──────────────────────────────────────────────────
${NC}"

echo -e "${GREEN}正在部署 OpenClaw...${NC}"

# --- 网络环境检测与自动换源 ---
echo -e "\n${YELLOW}[1/5] 测试网络环境并配置加速源...${NC}"
if curl -s -m 3 "https://github.com" >/dev/null; then
    echo -e "   ${GREEN}✓ 国际网络畅通，使用官方节点${NC}"
    export npm_config_registry="https://registry.npmjs.org/"
    GIT_PROXY=""
else
    echo -e "   ${YELLOW}✈️ 自动开启国内镜像加速 (NPM淘宝源 + GitHub加速)${NC}"
    export npm_config_registry="https://registry.npmmirror.com"
    GIT_PROXY="https://ghproxy.net/"
fi

# 1. 核心依赖安装 (Node.js)
if ! command -v node &> /dev/null; then
    echo -e "\n${YELLOW}[2/5] 正在安装 Node.js...${NC}"
    if command -v brew &> /dev/null; then
        brew install node
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y nodejs npm
    elif command -v yum &> /dev/null; then
        sudo yum install -y nodejs npm
    else
        echo -e "${RED}请手动安装 Node.js v22+${NC}"
        exit 1
    fi
else
    echo -e "\n${YELLOW}[2/5] Node.js 环境检查...${NC}"
    echo -e "   ${GREEN}✓ Node.js 已安装${NC}"
fi

# 2. OpenClaw 核心安装
if ! command -v openclaw &> /dev/null; then
    echo -e "\n${YELLOW}[3/5] 正在全局安装 OpenClaw 核心...${NC}"
    sudo -E npm install -g openclaw || npm install -g openclaw
else
    echo -e "\n${YELLOW}[3/5] OpenClaw 核心检查...${NC}"
    echo -e "   ${GREEN}✓ OpenClaw 已安装${NC}"
fi

# 3. 同步管理工具并安装依赖
echo -e "\n${YELLOW}[4/5] 正在同步管理工具代码...${NC}"
INSTALL_DIR="$HOME/OpenClaw"
if [ -d "$INSTALL_DIR" ]; then
    cd "$INSTALL_DIR" || exit
    # 根据网络动态更新 origin url
    if [ -n "$GIT_PROXY" ]; then
        git remote set-url origin "${GIT_PROXY}https://github.com/ClawTribe/openclaw-oneclick.git"
    else
        git remote set-url origin "https://github.com/ClawTribe/openclaw-oneclick.git"
    fi
    git fetch --all && git reset --hard origin/main
else
    git clone "${GIT_PROXY}https://github.com/ClawTribe/openclaw-oneclick.git" "$INSTALL_DIR"
    cd "$INSTALL_DIR" || exit
fi

# 安装依赖
echo -e "${YELLOW}   安装内部依赖 (自动适配镜像源)...${NC}"
npm install --production || {
    echo -e "${RED}❌ 依赖安装失败！可能遇到权限问题。${NC}"
    echo -e "💡 建议执行 ${CYAN}sudo chown -R \$USER:\$USER ~/.npm${NC} 修复缓存权限后，重新运行安装脚本。"
    exit 1
}

# 链接全局命令
echo -e "\n${YELLOW}[5/5] 配置系统全局命令...${NC}"
chmod +x src/index.js
sudo -E npm install -g . || npm install -g . || {
    echo -e "${RED}❌ 全局命令注册失败！${NC}"
    exit 1
}

# 4. 完成
echo -e "\n${GREEN}──────────────────────────────────────────────────${NC}"
echo -e "${GREEN}✓ 部署成功！${NC}"
echo -e "  运行 ${YELLOW}openclaw-setup${NC} 开始使用"
echo -e "${GREEN}──────────────────────────────────────────────────${NC}"

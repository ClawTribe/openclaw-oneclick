#!/usr/bin/env bash
set -e

echo -e "\n${YELLOW}[3/3] 正在拉取 OpenClaw 一键集成包并注册全局...${NC}"

OS_NAME=$(uname -s)
ARCH=$(uname -m)

if [[ "$OS_NAME" == "Darwin" ]]; then OS="macOS"; else OS="Linux"; fi
if [[ "$ARCH" == "x86_64" ]]; then ARCH="x64"; fi
if [[ "$ARCH" == "aarch64" ]]; then ARCH="arm64"; fi

PACKAGE_NAME="OpenClaw-${OS}-${ARCH}.zip"
DOWNLOAD_URL="${RELEASE_BASE_URL}/${PACKAGE_NAME}"
TMP_DIR=$(mktemp -d)
ZIP_PATH="${TMP_DIR}/${PACKAGE_NAME}"

echo -e "   目标架构: ${OS} - ${ARCH}"
echo -e "   正在从云端拉取 (带断点续传加速): ${PACKAGE_NAME}"

if curl -fSL --progress-bar --connect-timeout 15 --max-time 300 "$DOWNLOAD_URL" -o "$ZIP_PATH"; then
    echo -e "   ${GREEN}✓ 下载完成，正在解压与清洗目录...${NC}"
    
    if [ ! -d "$INSTALL_DIR" ]; then 
        mkdir -p "$INSTALL_DIR"
    else
        echo -e "   ${YELLOW}⚠ 发现已有的部署目录，正在覆盖核心文件以防破坏用户配置...${NC}"
        # 安全清理：只删除旧的核心工作文件，千万不要删除用户可能存放在此目录的本地数据库或配置文件
        rm -rf "$INSTALL_DIR/node_modules" "$INSTALL_DIR/dist" "$INSTALL_DIR/package.json" 2>/dev/null || true
    fi
    
    # -o 覆盖静默解压
    unzip -oq "$ZIP_PATH" -d "$INSTALL_DIR"
    
    # 路径漂移保护 (防止打包问题导致根目录嵌套一层文件夹)
    if [ ! -f "$INSTALL_DIR/package.json" ]; then
        SUB_DIR=$(find "$INSTALL_DIR" -maxdepth 1 -mindepth 1 -type d | head -n 1)
        if [ -n "$SUB_DIR" ] && [ -f "$SUB_DIR/package.json" ]; then
            mv "$SUB_DIR"/* "$SUB_DIR"/.??* "$INSTALL_DIR/" 2>/dev/null || true
            rm -rf "$SUB_DIR"
        fi
    fi
    
    echo -e "   ${GREEN}✓ 资源文件部署在 $INSTALL_DIR${NC}"
else
    echo -e "   ${RED}❌ 从 Release 页面获取核心包失败。${NC}"
    echo -e "   请检查加速地址 ${PROXY_PREFIX} 是否连通，或尝试手动下载。${NC}"
    exit 1
fi

[ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"

echo -e "   正在将面板与核心分别绑定到全局环境变量..."

# 1. 注册官方核心组件 (主目录)
cd "$INSTALL_DIR" || exit 1
if ! npm install -g . --registry="$NPM_REGISTRY" --silent; then
    sudo npm install -g . --registry="$NPM_REGISTRY" --silent || echo -e "   ${YELLOW}⚠ 核心模型CLI注册出现问题，但不影响配置面板启动。${NC}"
fi

# 2. 注册引导组件 (寄生子目录)
cd "$INSTALL_DIR/openclaw_oneclick" || exit 1
if ! npm install -g . --registry="$NPM_REGISTRY" --silent; then
    echo -e "   ${YELLOW}⚠ 遇到权限阻挡，正尝试以管理员身份重新注入全局绑定...${NC}"
    sudo npm install -g . --registry="$NPM_REGISTRY" --silent
fi

if command_exists openclaw-setup; then
    echo -e "   ${GREEN}✓ 终端控制台与核心服务已解锁装载。${NC}"
else
    echo -e "   ${RED}❌ 系统环境问题，未能成功放入可执行目录，但代码解压完毕。${NC}"
    exit 1
fi

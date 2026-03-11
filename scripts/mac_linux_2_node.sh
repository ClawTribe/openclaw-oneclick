#!/usr/bin/env bash
set -e

echo -e "\n${YELLOW}[2/3] 配置 Node.js 与 NPM 中国节点加速缓存...${NC}"

command_exists() { command -v "$1" >/dev/null 2>&1; }
OS="$(uname -s)"
ARCH="$(uname -m)"

NODE_VERSION_STR=$(node -v 2>/dev/null || echo "v0")
NODE_MAJOR=$(echo "$NODE_VERSION_STR" | sed 's/v//' | cut -d. -f1)

if ! command_exists node || [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 22 ]; then
    echo -e "   ${YELLOW}⚠ 未找到支持的 Node.js 引擎 (需要 v22+)，准备从淘宝镜像全静默安装...${NC}"
    TMP_DIR=$(mktemp -d)
    
    if [ "$OS" = "Darwin" ]; then
        PKG_URL="https://npmmirror.com/mirrors/node/v${NODE_VERSION}/node-v${NODE_VERSION}.pkg"
        PKG_PATH="${TMP_DIR}/node.pkg"
        
        echo -e "   ➤ 正在下载 macOS 安装包..."
        curl -fsSL -o "$PKG_PATH" "$PKG_URL"
        echo -e "   ➤ 启动静默系统级安装 (如果弹窗请填入密码，或者在终端直接输入密码盲打回车)..."
        # 强制静默以避开图形UI
        sudo installer -pkg "$PKG_PATH" -target /
    elif [ "$OS" = "Linux" ]; then
        if [ "$ARCH" = "x86_64" ]; then ARCH_N="x64";
        elif [ "$ARCH" = "aarch64" ]; then ARCH_N="arm64";
        else ARCH_N=$ARCH; fi
        
        TAR_URL="https://npmmirror.com/mirrors/node/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH_N}.tar.xz"
        TAR_PATH="${TMP_DIR}/node.tar.xz"
        
        echo -e "   ➤ 正在下载 Linux 安装压缩包..."
        curl -fsSL -o "$TAR_PATH" "$TAR_URL"
        echo -e "   ➤ 正在解压至系统目录 /usr/local ..."
        sudo tar -xJf "$TAR_PATH" -C /usr/local --strip-components=1
    fi
    rm -rf "$TMP_DIR"
    
    # 确保命令缓存刷新
    hash -r 2>/dev/null || true
    if ! command_exists node; then echo -e "${RED}❌ 严重错误: Node.js 安装失败。${NC}"; exit 1; fi
fi

echo -e "   ${GREEN}✓ Node.js $(node -v) 核心运转中${NC}"

# 配置 NPM 源加速
npm config set registry "$NPM_REGISTRY"
npm config set update-notifier false
echo -e "   ${GREEN}✓ npm 换源已指向: $(npm config get registry)${NC}"

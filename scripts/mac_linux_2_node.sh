#!/usr/bin/env bash
set -e

echo -e "\n${YELLOW}[2/3] 配置 Node.js 与 NPM 中国节点加速缓存...${NC}"

command_exists() { command -v "$1" >/dev/null 2>&1; }

# 语义化版本比较：version_ge "22.14.0" "22.16.0" → 返回 1（不满足）
# 用法：version_ge "$current" "$required"  → 返回 0 表示 current >= required
version_ge() {
    local cur="$1" req="$2"
    cur="${cur#v}"; req="${req#v}"
    local cur_major cur_minor cur_patch req_major req_minor req_patch
    IFS='.' read -r cur_major cur_minor cur_patch <<< "$cur"
    IFS='.' read -r req_major req_minor req_patch <<< "$req"
    cur_major=${cur_major:-0}; cur_minor=${cur_minor:-0}; cur_patch=${cur_patch:-0}
    req_major=${req_major:-0}; req_minor=${req_minor:-0}; req_patch=${req_patch:-0}
    if [ "$cur_major" -gt "$req_major" ]; then return 0; fi
    if [ "$cur_major" -lt "$req_major" ]; then return 1; fi
    if [ "$cur_minor" -gt "$req_minor" ]; then return 0; fi
    if [ "$cur_minor" -lt "$req_minor" ]; then return 1; fi
    if [ "$cur_patch" -ge "$req_patch" ]; then return 0; fi
    return 1
}

# 检查当前 node 版本是否满足要求（精确到 major.minor.patch）
node_version_ok() {
    if ! command_exists node; then return 1; fi
    local cur
    cur="$(node -v 2>/dev/null || echo 'v0.0.0')"
    version_ge "$cur" "$NODE_VERSION"
}

# 尝试加载 nvm（若用户本机已用 nvm 管理 Node，单纯安装 /usr/local/bin/node 会被 PATH 覆盖）
load_nvm() {
    if command_exists nvm; then return 0; fi
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        # shellcheck disable=SC1090
        . "$NVM_DIR/nvm.sh"
    fi
    command_exists nvm
}

# 尝试加载 asdf（若用户用 asdf 管理 node，同理需要用 asdf 升级/切换）
load_asdf() {
    if command_exists asdf; then return 0; fi
    if [ -s "$HOME/.asdf/asdf.sh" ]; then
        # shellcheck disable=SC1090
        . "$HOME/.asdf/asdf.sh"
    fi
    command_exists asdf
}

# volta 是可执行文件（通常不需要 source），但它也会把 node 放到 PATH 前面
has_volta() {
    command_exists volta
}

ensure_system_node_first_in_path() {
    if [ -x "/usr/local/bin/node" ]; then
        export PATH="/usr/local/bin:$PATH"
        hash -r 2>/dev/null || true
    fi
}

upgrade_via_volta_if_possible() {
    if ! has_volta; then return 1; fi
    echo -e "   ➤ 检测到 volta，优先使用 volta 安装并切换 Node v${NODE_VERSION} ..."
    volta install "node@${NODE_VERSION}" >/dev/null 2>&1 || return 1
    hash -r 2>/dev/null || true
    node_version_ok
}

upgrade_via_asdf_if_possible() {
    if ! load_asdf; then return 1; fi
    echo -e "   ➤ 检测到 asdf，优先使用 asdf 安装并切换 Node v${NODE_VERSION} ..."
    asdf plugin list 2>/dev/null | grep -q '^nodejs$' || asdf plugin add nodejs >/dev/null 2>&1 || true
    asdf install nodejs "${NODE_VERSION}" >/dev/null 2>&1 || return 1
    asdf global nodejs "${NODE_VERSION}" >/dev/null 2>&1 || true
    hash -r 2>/dev/null || true
    node_version_ok
}

OS="$(uname -s)"
ARCH="$(uname -m)"

if ! node_version_ok; then
    if command_exists node; then
        echo -e "   ${YELLOW}⚠ 当前 Node.js $(node -v) 版本低于要求 (需要 v${NODE_VERSION}+)，准备升级...${NC}"
    else
        echo -e "   ${YELLOW}⚠ 未找到 Node.js，准备安装 v${NODE_VERSION}...${NC}"
    fi

    # 优先：如果用户使用 node 版本管理器（nvm/volta/asdf），必须先用其升级/切换；
    # 否则系统 pkg/tar 安装会被 PATH 前置的 manager 覆盖，导致仍然显示旧版本。

    # 0) volta
    if upgrade_via_volta_if_possible; then
        echo -e "   ${GREEN}✓ 已通过 volta 切换到 Node.js $(node -v) (${CYAN}$(command -v node)${NC}${GREEN})${NC}"
    fi

    # 1) asdf
    if ! node_version_ok; then
        if upgrade_via_asdf_if_possible; then
            echo -e "   ${GREEN}✓ 已通过 asdf 切换到 Node.js $(node -v) (${CYAN}$(command -v node)${NC}${GREEN})${NC}"
        fi
    fi

    # 2) nvm
    if ! node_version_ok; then
        if load_nvm; then
            echo -e "   ➤ 检测到 nvm，优先使用 nvm 安装并切换 Node v${NODE_VERSION} ..."
            nvm install "${NODE_VERSION}" >/dev/null
            nvm use "${NODE_VERSION}" >/dev/null
            nvm alias default "${NODE_VERSION}" >/dev/null 2>&1 || true
            hash -r 2>/dev/null || true

            if node_version_ok; then
                echo -e "   ${GREEN}✓ 已通过 nvm 切换到 Node.js $(node -v) (${CYAN}$(command -v node)${NC}${GREEN})${NC}"
            else
                echo -e "   ${YELLOW}⚠ nvm 切换未生效，将回退到系统级安装...${NC}"
            fi
        fi
    fi

    # 若版本管理器均未生效，回退：系统级安装（macOS pkg / Linux tarball）
    if ! node_version_ok; then
        TMP_DIR=$(mktemp -d)

        if [ "$OS" = "Darwin" ]; then
            PKG_URL="https://npmmirror.com/mirrors/node/v${NODE_VERSION}/node-v${NODE_VERSION}.pkg"
            PKG_PATH="${TMP_DIR}/node.pkg"

            echo -e "   ➤ 正在下载 macOS 安装包..."
            curl -fSL --progress-bar -o "$PKG_PATH" "$PKG_URL"
            echo -e "   ➤ 启动静默系统级安装 (如果弹窗请填入密码，或者在终端直接输入密码盲打回车)..."
            sudo installer -pkg "$PKG_PATH" -target /
        elif [ "$OS" = "Linux" ]; then
            if [ "$ARCH" = "x86_64" ]; then ARCH_N="x64";
            elif [ "$ARCH" = "aarch64" ]; then ARCH_N="arm64";
            else ARCH_N=$ARCH; fi

            TAR_URL="https://npmmirror.com/mirrors/node/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH_N}.tar.xz"
            TAR_PATH="${TMP_DIR}/node.tar.xz"

            echo -e "   ➤ 正在下载 Linux 安装压缩包..."
            curl -fSL --progress-bar -o "$TAR_PATH" "$TAR_URL"
            echo -e "   ➤ 正在解压至系统目录 /usr/local ..."
            sudo tar -xJf "$TAR_PATH" -C /usr/local --strip-components=1
        fi

        rm -rf "$TMP_DIR"

        hash -r 2>/dev/null || true
        if ! command_exists node; then echo -e "${RED}❌ 严重错误: Node.js 安装失败。${NC}"; exit 1; fi

        ensure_system_node_first_in_path
    fi
fi

if ! node_version_ok; then
    echo -e "${RED}❌ Node.js 版本不满足要求：当前 $(node -v 2>/dev/null || echo 'unknown')，需要 v${NODE_VERSION}+${NC}"
    echo -e "${RED}   路径: ${CYAN}$(command -v node 2>/dev/null || echo 'node not found')${NC}"
    echo -e "${YELLOW}   如果你使用 nvm 管理 Node，请执行：${NC}"
    echo -e "${CYAN}   nvm install ${NODE_VERSION} && nvm use ${NODE_VERSION} && nvm alias default ${NODE_VERSION}${NC}"
    exit 1
fi

echo -e "   ${GREEN}✓ Node.js $(node -v) 核心运转中 (${CYAN}$(command -v node)${NC}${GREEN})${NC}"

# 配置 NPM 源加速
npm config set registry "$NPM_REGISTRY"
npm config set update-notifier false
echo -e "   ${GREEN}✓ npm 换源已指向: $(npm config get registry)${NC}"

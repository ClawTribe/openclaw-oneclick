#!/usr/bin/env bash
set -e

echo -e "\n${YELLOW}[2/3] 配置 Node.js 与 NPM 中国节点加速缓存...${NC}"

command_exists() { command -v "$1" >/dev/null 2>&1; }

# 尝试加载 nvm（若用户本机已用 nvm 管理 Node，单纯安装 /usr/local/bin/node 会被 PATH 覆盖）
load_nvm() {
    # 已可用
    if command_exists nvm; then return 0; fi

    # 常见安装位置
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
    # 常见安装位置
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

node_major() {
    local v
    v="$(node -v 2>/dev/null || echo 'v0.0.0')"
    echo "$v" | sed 's/v//' | cut -d. -f1
}

ensure_system_node_first_in_path() {
    # 如果系统级 node 已安装在 /usr/local/bin，但被 nvm 放在 PATH 前面，则临时把 /usr/local/bin 提前
    if [ -x "/usr/local/bin/node" ]; then
        export PATH="/usr/local/bin:$PATH"
        hash -r 2>/dev/null || true
    fi
}

upgrade_via_volta_if_possible() {
    # 返回 0 表示已成功切到 v22+
    if ! has_volta; then return 1; fi
    echo -e "   ➤ 检测到 volta，优先使用 volta 安装并切换 Node v${NODE_VERSION} ..."
    # volta 会把 shim 放到 PATH 前面，适合“无人值守”的全局默认
    volta install "node@${NODE_VERSION}" >/dev/null 2>&1 || return 1
    hash -r 2>/dev/null || true
    local m
    m="$(node_major)"
    [ -n "$m" ] && [ "$m" -ge 22 ]
}

upgrade_via_asdf_if_possible() {
    # 返回 0 表示已成功切到 v22+
    if ! load_asdf; then return 1; fi
    echo -e "   ➤ 检测到 asdf，优先使用 asdf 安装并切换 Node v${NODE_VERSION} ..."
    # 需要 nodejs 插件；若不存在则自动添加（尽量静默）
    asdf plugin list 2>/dev/null | grep -q '^nodejs$' || asdf plugin add nodejs >/dev/null 2>&1 || true
    asdf install nodejs "${NODE_VERSION}" >/dev/null 2>&1 || return 1
    asdf global nodejs "${NODE_VERSION}" >/dev/null 2>&1 || true
    hash -r 2>/dev/null || true
    local m
    m="$(node_major)"
    [ -n "$m" ] && [ "$m" -ge 22 ]
}

OS="$(uname -s)"
ARCH="$(uname -m)"

NODE_MAJOR="$(node_major)"

if ! command_exists node || [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 22 ]; then
    echo -e "   ${YELLOW}⚠ 未找到支持的 Node.js 引擎 (需要 v22+)，准备从淘宝镜像全静默安装...${NC}"

    # 优先：如果用户使用 node 版本管理器（nvm/volta/asdf），必须先用其升级/切换；
    # 否则系统 pkg/tar 安装会被 PATH 前置的 manager 覆盖，导致仍然显示旧版本。

    # 0) volta
    if upgrade_via_volta_if_possible; then
        echo -e "   ${GREEN}✓ 已通过 volta 切换到 Node.js $(node -v) (${CYAN}$(command -v node)${NC}${GREEN})${NC}"
    fi

    # 1) asdf
    NODE_MAJOR="$(node_major)"
    if [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 22 ]; then
        if upgrade_via_asdf_if_possible; then
            echo -e "   ${GREEN}✓ 已通过 asdf 切换到 Node.js $(node -v) (${CYAN}$(command -v node)${NC}${GREEN})${NC}"
        fi
    fi

    # 2) nvm
    if load_nvm; then
        echo -e "   ➤ 检测到 nvm，优先使用 nvm 安装并切换 Node v${NODE_VERSION} ..."
        nvm install "${NODE_VERSION}" >/dev/null
        nvm use "${NODE_VERSION}" >/dev/null
        # 尽量设置默认版本，避免用户新开终端又回到旧版本（不强制，失败也不影响本次安装）
        nvm alias default "${NODE_VERSION}" >/dev/null 2>&1 || true
        hash -r 2>/dev/null || true

        NODE_MAJOR="$(node_major)"
        if command_exists node && [ "$NODE_MAJOR" -ge 22 ]; then
            echo -e "   ${GREEN}✓ 已通过 nvm 切换到 Node.js $(node -v) (${CYAN}$(command -v node)${NC}${GREEN})${NC}"
        else
            echo -e "   ${YELLOW}⚠ nvm 切换未生效，将回退到系统级安装...${NC}"
        fi
    fi

    # 若 nvm 未生效，回退：系统级安装（macOS pkg / Linux tarball）
    NODE_MAJOR="$(node_major)"
    if ! command_exists node || [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 22 ]; then
        TMP_DIR=$(mktemp -d)

        if [ "$OS" = "Darwin" ]; then
            PKG_URL="https://npmmirror.com/mirrors/node/v${NODE_VERSION}/node-v${NODE_VERSION}.pkg"
            PKG_PATH="${TMP_DIR}/node.pkg"

            echo -e "   ➤ 正在下载 macOS 安装包..."
            curl -fSL --progress-bar -o "$PKG_PATH" "$PKG_URL"
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
            curl -fSL --progress-bar -o "$TAR_PATH" "$TAR_URL"
            echo -e "   ➤ 正在解压至系统目录 /usr/local ..."
            sudo tar -xJf "$TAR_PATH" -C /usr/local --strip-components=1
        fi

        rm -rf "$TMP_DIR"

        # 确保命令缓存刷新
        hash -r 2>/dev/null || true
        if ! command_exists node; then echo -e "${RED}❌ 严重错误: Node.js 安装失败。${NC}"; exit 1; fi

        # 若用户 PATH 里 nvm 仍在最前面，临时把系统 node 提到前面用于本次流程
        ensure_system_node_first_in_path
    fi
fi

NODE_MAJOR="$(node_major)"
if [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 22 ]; then
    echo -e "${RED}❌ Node.js 版本仍低于 v22：当前 $(node -v 2>/dev/null || echo 'unknown') (${CYAN}$(command -v node 2>/dev/null || echo 'node not found')${NC}${RED})${NC}"
    echo -e "${YELLOW}   你的系统使用 nvm 管理 Node 时，请执行：${NC}"
    echo -e "${CYAN}   nvm install ${NODE_VERSION} && nvm use ${NODE_VERSION} && nvm alias default ${NODE_VERSION}${NC}"
    exit 1
fi

echo -e "   ${GREEN}✓ Node.js $(node -v) 核心运转中 (${CYAN}$(command -v node)${NC}${GREEN})${NC}"

# 配置 NPM 源加速
npm config set registry "$NPM_REGISTRY"
npm config set update-notifier false
echo -e "   ${GREEN}✓ npm 换源已指向: $(npm config get registry)${NC}"

#!/usr/bin/env bash
set -e

echo -e "\n${YELLOW}[3/3] 正在拉取 OpenClaw 一键集成包并注册全局...${NC}"

command_exists() { command -v "$1" >/dev/null 2>&1; }

extract_zip() {
    local zip_path="$1"
    local dest_dir="$2"

    # macOS 上 Info-ZIP 的 unzip 在某些包含扩展属性/特殊条目的压缩包中可能报：
    #   "Attribute not found" / "unable to process ..."
    # 优先使用系统自带 ditto 解压；若不可用再用 unzip 并关闭 extra attributes。
    if [[ "$(uname -s)" == "Darwin" ]]; then
        if command_exists ditto; then
            ditto -x -k "$zip_path" "$dest_dir"
            return $?
        fi
        if command_exists unzip; then
            unzip -o -q -X "$zip_path" -d "$dest_dir"
            return $?
        fi
        return 127
    fi

    # Linux：优先 unzip；若系统无 unzip 则尝试 bsdtar/tar（部分发行版 tar 可解 zip）
    if command_exists unzip; then
        unzip -o -q "$zip_path" -d "$dest_dir"
        return $?
    fi
    if command_exists bsdtar; then
        bsdtar -xf "$zip_path" -C "$dest_dir"
        return $?
    fi
    if command_exists tar; then
        tar -xf "$zip_path" -C "$dest_dir"
        return $?
    fi
    return 127
}

OS_NAME=$(uname -s)
ARCH=$(uname -m)

if [[ "$OS_NAME" == "Darwin" ]]; then OS="macOS"; else OS="Linux"; fi
if [[ "$ARCH" == "x86_64" ]]; then ARCH="x64"; fi
if [[ "$ARCH" == "aarch64" ]]; then ARCH="arm64"; fi

PACKAGE_NAME="OpenClaw-${OS}-${ARCH}.zip"
# 绕过 ghfast 边缘缓存可能记住的 404 状态
DOWNLOAD_URL="${RELEASE_BASE_URL}/${PACKAGE_NAME}?t=$(date +%s)"
DIRECT_URL="https://github.com/$REPO_USER/$REPO_NAME/releases/download/v$VERSION/$PACKAGE_NAME"
FALLBACK_URL=""
if [ -n "${FALLBACK_PROXY_PREFIX:-}" ]; then
  FALLBACK_URL="${FALLBACK_PROXY_PREFIX}https://github.com/$REPO_USER/$REPO_NAME/releases/download/v$VERSION/$PACKAGE_NAME?t=$(date +%s)"
fi

TMP_DIR=$(mktemp -d)
ZIP_PATH="${TMP_DIR}/${PACKAGE_NAME}"

echo -e "   目标架构: ${OS} - ${ARCH}"
echo -e "   正在从云端拉取 (带断点续传加速): ${PACKAGE_NAME}"

# 尝试最优加速节点 → 备用加速节点 → Github 直连
if curl -fSL --progress-bar --connect-timeout 15 "$DOWNLOAD_URL" -o "$ZIP_PATH" || \
   { [ -n "$FALLBACK_URL" ] && curl -fSL --progress-bar --connect-timeout 15 "$FALLBACK_URL" -o "$ZIP_PATH"; } || \
   curl -fSL --progress-bar --connect-timeout 20 "$DIRECT_URL" -o "$ZIP_PATH"; then
    echo -e "   ${GREEN}✓ 下载完成，正在解压与清洗目录...${NC}"
    
    if [ ! -d "$INSTALL_DIR" ]; then 
        mkdir -p "$INSTALL_DIR"
    else
        echo -e "   ${YELLOW}⚠ 发现已有的部署目录，正在覆盖核心文件以防破坏用户配置...${NC}"
        # 安全清理：只删除旧的核心工作文件，千万不要删除用户可能存放在此目录的本地数据库或配置文件
        rm -rf "$INSTALL_DIR/node_modules" "$INSTALL_DIR/dist" "$INSTALL_DIR/package.json" 2>/dev/null || true
    fi
    
    # 防止旧文件因为属主不同或只读权限无法覆盖，加一层强力删除
    chmod -R 777 "$INSTALL_DIR/node_modules" 2>/dev/null || true
    rm -rf "$INSTALL_DIR/node_modules" 2>/dev/null || true

    # 某些 macOS 环境下该路径可能残留为“文件/不可写条目”，会导致解压时创建目录失败
    rm -rf "$INSTALL_DIR/extensions/memory-lancedb/node_modules/openai" 2>/dev/null || true

    # 解压（macOS 优先 ditto；否则用 unzip 并禁用 extra attributes 以规避 Attribute not found）
    if ! extract_zip "$ZIP_PATH" "$INSTALL_DIR"; then
        echo -e "   ${RED}❌ 解压失败。${NC}"
        echo -e "   ${YELLOW}提示：请确认目录可写：${NC}${CYAN}$INSTALL_DIR${NC}"
        echo -e "   ${YELLOW}若你使用了同步盘/特殊文件系统，建议将 INSTALL_DIR 改到本地磁盘目录后重试。${NC}"
        exit 1
    fi
    
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

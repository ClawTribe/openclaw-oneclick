#!/usr/bin/env bash
set -e

echo -e "$YELLOW[1/3] 正在梳理系统基础环境 (curl/unzip/git)...$NC"

command_exists() { command -v "$1" >/dev/null 2>&1; }

OS="$(uname -s)"

# 检查 curl
if ! command_exists curl; then
    echo -e "${RED}❌ 缺少基础命令 curl。由于 curl 是必需下载工具，请系统预装。${NC}"
    exit 1
fi
echo -e "   ${GREEN}✓ curl 工具就绪${NC}"

# 检查并自动安装 unzip
if ! command_exists unzip; then
    echo -e "   ${YELLOW}⚠ 缺少 unzip，正在为您自动热补丁安装...${NC}"
    if command_exists apt-get; then sudo apt-get update && sudo apt-get install -y unzip
    elif command_exists yum; then sudo yum install -y unzip
    elif command_exists dnf; then sudo dnf install -y unzip
    elif command_exists brew; then brew install unzip
    fi
    if ! command_exists unzip; then echo -e "${RED}❌ 无法自动补齐 unzip，请手动安装。${NC}"; exit 1; fi
fi
echo -e "   ${GREEN}✓ unzip 工具就绪${NC}"

# 检查并自动按需安装 Git
if ! command_exists git; then
    echo -e "   ${YELLOW}⚠ 未找到 Git 客户端，将启动静默加速安装...${NC}"
    if [ "$OS" = "Darwin" ]; then
        if ! command_exists brew; then
            export NONINTERACTIVE=1
            export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
            export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
            export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
            curl -fsSL "${PROXY_PREFIX}https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" | sed 's|https://github.com/Homebrew/brew|https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git|g' | bash
            
            # 手动拉取一次 brew 环境
            if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
            if [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
        fi
        brew install git
    elif [ "$OS" = "Linux" ]; then
        if command_exists apt-get; then sudo apt-get update && sudo apt-get install -y git
        elif command_exists yum; then sudo yum install -y git
        else echo -e "${RED}❌ 无法推断包管理器，Git 安装失败。${NC}"; exit 1; fi
    fi
fi
echo -e "   ${GREEN}✓ Git "$(git --version | awk '{print $3}')" 引擎就绪${NC}"

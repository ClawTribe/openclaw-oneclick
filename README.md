# OpenClaw 配置管理工具

> **OpenClaw 一键部署 + 全中文配置管理**

[![Version](https://img.shields.io/badge/Version-3.1.0-blue.svg)](https://github.com/ClawTribe/openclaw-oneclick)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

专为 [OpenClaw](https://openclaw.ai) 设计的中文配置管理工具，通过直观的交互式菜单管理 AI 助手的所有配置。

---

## 功能特性

| 特性                 | 说明                                              |
| -------------------- | ------------------------------------------------- |
| **中英文切换** | 一键切换界面语言                                  |
| **配置说明**   | 每个选项都有用途说明                              |
| **多通道支持** | WhatsApp / Telegram / Discord / Slack / Signal 等 |
| **安全控制**   | 沙箱模式、命令执行权限控制                        |
| **自动更新**   | 启动时自动检查新版本                              |

---

## 快速安装

### macOS / Linux

```bash
    curl -sSL https://raw.githubusercontent.com/ClawTribe/openclaw-oneclick/main/install.sh | bash
```

安装脚本会优先调用 OpenClaw 官方安装器完成核心安装；如果在中国大陆网络环境下遇到 npm 或 GitHub 访问问题，会自动尝试当前安装进程内的 fallback，不会主动改写你的全局 npm 配置。

当前安装策略为中国大陆优先：默认先使用国内 npm 镜像与 GitHub 代理；如果安装过程中遇到 [`git+https://github.com/...`](README.md:31) 这类 Git 依赖，也会在当前进程里临时注入 GitHub 代理映射，再在必要时回退官方源。

**支持覆盖安装**：如果已安装 OpenClaw，脚本会自动先卸载现有版本，**备份配置文件**（`~/.openclaw/openclaw.json` → `~/openclaw.MMDDHHmm.bak`），然后清理配置目录。这可以避免不同版本之间的配置兼容性问题，同时保留你的配置以便恢复。备份文件保存在用户主目录下，不会被清理。

### Windows (PowerShell 管理员)

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex (irm 'https://ghfast.top/https://raw.githubusercontent.com/ClawTribe/openclaw-oneclick/main/install.ps1')
```

Windows 脚本与 macOS / Linux 版本保持同一安装职责：先检查基础环境，再优先调用 OpenClaw 官方安装器，最后安装并注册 [`openclaw-setup`](package.json:6)。

Windows 版本同样采用中国大陆优先策略：默认先使用国内 npm 镜像、GitHub 代理与临时 Git URL 映射，失败时再回退官方链路。

**支持覆盖安装**：如果已安装 OpenClaw，脚本会自动先卸载现有版本，**备份配置文件**（`~/.openclaw/openclaw.json` → `~/openclaw.MMDDHHmm.bak`），然后清理配置目录。这可以避免不同版本之间的配置兼容性问题，同时保留你的配置以便恢复。备份文件保存在用户主目录下，不会被清理。

### 指定 OpenClaw 版本

默认安装的 OpenClaw 版本为 **2026.2.26**（此版本稳定性最佳，最新版本可能存在 bug）。

如需安装其他版本，可通过 `OPENCLAW_VERSION` 环境变量指定：

```bash
# macOS / Linux
OPENCLAW_VERSION=2026.2.26 curl -sSL https://raw.githubusercontent.com/ClawTribe/openclaw-oneclick/main/install.sh | bash

# Windows PowerShell
$env:OPENCLAW_VERSION='2026.2.26'; Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex (irm 'https://ghfast.top/https://raw.githubusercontent.com/ClawTribe/openclaw-oneclick/main/install.ps1')
```

---

## 使用方法

```bash
openclaw-setup
```

### 配置分类

| 分类       | 说明                                 |
| ---------- | ------------------------------------ |
| 基础核心   | AI 模型、时区、工作目录              |
| 通信频道   | WhatsApp/Telegram/Discord 等连接配置 |
| 会话管理   | 会话隔离、自动重置策略               |
| 浏览器控制 | AI 浏览器自动化                      |
| 定时任务   | Cron 定时执行                        |
| 网关服务   | 端口、认证、日志                     |
| 安全控制   | 沙箱、命令执行权限                   |

---

## 常见问题

| 问题                        | 解决方案                                  |
| --------------------------- | ----------------------------------------- |
| `command not found: node` | 安装 Node.js v22+ 并添加到 PATH           |
| `Permission denied`       | macOS/Linux 加 `sudo`，Windows 用管理员 |
| 缺少 `curl` / `git` / `sudo` | 安装脚本会先尝试自动补齐；若系统过于精简，会输出可直接复制的准备命令 |
| npm 已走镜像但仍安装失败 | 可能是 `openclaw` 依赖里的 GitHub git 依赖超时；当前脚本会自动为当前安装进程注入 GitHub 代理映射 |
| 网关启动失败                | 运行 `openclaw doctor` 诊断             |
| 配置不生效                  | 运行 `openclaw gateway restart`         |

---

## 相关链接

- [OpenClaw 官方](https://openclaw.ai)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [本项目 Issues](https://github.com/ClawTribe/openclaw-oneclick/issues)

---

## 许可

MIT License | Original by Jun | Modified & Optimized by ClawTribe

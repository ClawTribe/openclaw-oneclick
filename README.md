# OpenClaw 配置管理工具

> **OpenClaw 一键部署 + 全中文配置管理**

[![Version](https://img.shields.io/badge/Version-3.2.0-blue.svg)](https://github.com/ClawTribe/openclaw-oneclick)
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

## 🚀 极简快速安装 (全新版)

无需懂技术，无需自己装 Node，无需担心国内网络问题。我们深度整合了所有的流程，**只需要下面一行代码**，其余统统全自动解决（包含：下载所需加速器、安装环境、环境关联、核心代码装配等）！

### Windows 用户 (推荐)
**1. 右键点击“开始菜单”，选择“终端管理员”或“Windows PowerShell (管理员)”**
**2. 复制下方代码并在窗口中点击鼠标右键粘贴，敲下回车键：**
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex (irm 'https://raw.githubusercontent.com/ClawTribe/openclaw-oneclick/main/install.ps1')
```
*提示：如果有系统弹窗询问是否允许修改系统（安装 Git/Node等环境），请点击允许。部署成功后会提示您关闭当前页面并重新打开一个新的终端。*

> 常见报错：如果你看到红字提示 `Write-Color` / `CommandNotFoundException`，通常是旧版安装脚本中 `Write-Color` 在子流程脚本作用域不可见导致。
> 解决方式：更新到最新版后无需手动处理；若你正在使用旧缓存/旧脚本，请重新运行上面的一键命令（确保拉取到最新 `install.ps1`）。

> 注：安装脚本每次运行都会自动测速多个 GitHub 加速隧道，并选择当前网络环境下最稳定/最快的线路；无需手动改域名。

### macOS & Linux 用户
打开终端 (Terminal)，直接复制下段代码运行（中途可能需要您输入开机密码来确认系统权限）：
```bash
curl -fsSL https://raw.githubusercontent.com/ClawTribe/openclaw-oneclick/main/install.sh | bash
```

> 注：安装脚本每次运行都会自动测速多个 GitHub 加速隧道，并选择当前网络环境下最稳定/最快的线路；无需手动改域名。

---

## ✅ 验证安装

无论您使用哪种系统，安装程序最终都会把 OpenClaw 的核心代码资源保存在这儿：
- **Windows**: `C:\Users\您的用户名\OpenClaw`
- **macOS / Linux**: `~/OpenClaw` (即用户根目录下的 OpenClaw 文件夹)

**如何确认自己装好了？**
如果您看到满屏的绿色打勾提示“部署成功”，请**关闭当前所有终端窗口。然后重新打开一个新的终端或 PowerShell**，在里面输入：
```bash
openclaw-setup
```
如果您看到了全中文的配置交互菜单，恭喜您，机器人已就绪！

---

## 🛠️ 安装过程技术避坑指南 (针对小白)

尽管我们做到了最深度的全自动处理，但因为部分电脑由于杀毒软件或网络运营商的深度拦截，可能需要您的稍微介入：

**Q1：代码输进去敲回车后，出现大片红色字“在此系统上禁止运行脚本”？**
> **原因**：由于您的 Windows 安全中心设置得比较严格，禁用了 PowerShell 的基础执行权限。
> **快速解决**：在那个管理员的蓝框框里敲入 `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force` 并回车，然后再次运行上面的一键安装指令即可。

**Q2：提示 “系统 PATH 未能自动重载，无法调用刚安装的 Node” 怎么办？**
> **原因**：这说明环境已经全给您免弹窗强制静默装好了，但是在 Windows 下，新的环境变量只有在当前窗口被关掉，再新开的窗口里才生效，这导致我们后面连贯操作找不到配置！
> **极简解法**：听劝，把当前全都是红字的蓝黑框框**直接关掉**。重新再用管理员身份打开一个新的框框，**再运行一次**刚才的一键安装代码就行了！

**Q3：安装进度在下载 `OpenClaw-***.zip` 就一直卡着完全不动？**
> **技术解答**：安装脚本会按顺序尝试多个 GitHub 加速隧道（例如 `ghproxy.net`、`ghfast.top`），并在失败时自动回退到 GitHub 源站直连。不同地区/运营商对不同隧道的连通性差异很大，可能出现某个隧道突然超时。
> **建议**：
> 1) 直接重试一次（可能是隧道短时抖动）；
> 2) 若仍失败，可尝试全局代理（Clash / V2ray）；
> 3) 或手动把脚本中的加速前缀切换为你本地可用的那条线路。

**Q4：全部安装完毕后提示配置失败或者权限被阻挡 (Mac/Linux)？**
> **原因**：很多 macOS 的内核对文件夹写入采取非常严格的沙箱控制机制，导致最终虽然资源都下载了，就是无法绑定到 `openclaw-setup`。
> **解决**：在终端框内敲入 `sudo npm install -g .`，输入您的电脑密码并回车。

---

## ⚙️ 使用方法

在部署成功并且系统重启关联了环境路径后，以后只需随时打开终端运行：
```bash
openclaw-setup
```

### 配置分类
您可以利用它轻松把控您大模型机器人的各个关节：

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

## 相关链接

- [OpenClaw 官方](https://openclaw.ai)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [本项目 Issues](https://github.com/ClawTribe/openclaw-oneclick/issues)

---

## 许可

MIT License | Original by Jun | Modified & Optimized by ClawTribe

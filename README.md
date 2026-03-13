# OpenClaw 一键部署

[![Version](https://img.shields.io/badge/Version-3.3.4-blue.svg)](https://github.com/ClawTribe/openclaw-oneclick)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)


## 🚀 快速安装

**不需要先安装任何软件！** 只需要运行下面的一行代码，其他的都交给自动安装程序来完成。

### Windows 用户

**第一步：打开管理员 PowerShell**

1. 点击屏幕左下角的 **Windows 图标**（或按键盘 `Win` 键）打开开始菜单
2. 在搜索框中输入 `PowerShell`
3. 在搜索结果中找到 **"Windows PowerShell"**
4. **右键点击** "Windows PowerShell"，选择 **"以管理员身份运行"**
5. 如果弹出"用户账户控制"（UAC）窗口，点击 **"是"** 确认

> 💡 **小贴士**：打开的窗口顶部会显示"管理员: Windows PowerShell"，这就说明成功了！

**第二步：运行安装命令**

1. 复制下方整段代码：
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex (irm 'https://raw.githubusercontent.com/ClawTribe/openclaw-oneclick/main/install.ps1')
```
2. 在管理员 PowerShell 窗口中 **点击鼠标右键**（代码会自动粘贴）
3. 按下 **回车键** 开始安装

> ⚠️ **注意**：安装过程中请保持网络连接，耐心等待直到出现"部署成功"提示。

### macOS & Linux 用户

**第一步：打开终端**

1. 点击屏幕右上角的 **搜索图标**（🔍）
2. 在搜索框中输入 `终端` 或 `Terminal`
3. 点击 **"终端"** 应用打开它

> 💡 **小贴士**：也可以按 `Command + 空格键`，然后输入"终端"快速打开。

**第二步：运行安装命令**

1. 复制下方整段代码：
```bash
curl -fsSL https://raw.githubusercontent.com/ClawTribe/openclaw-oneclick/main/install.sh | bash
```
2. 在终端窗口中 **点击鼠标右键**（代码会自动粘贴）
3. 按下 **回车键** 开始安装

> ⚠️ **注意**：安装过程中可能需要您输入电脑密码来确认系统权限，输入密码时屏幕不会显示任何字符，这是正常的，输入完成后按回车即可。
---

## 🔧 配置大模型和飞书

初始化完成后，使用我们的**简易配置工具**来设置大模型和飞书：

```bash
openclaw-setup
```

这将打开一个中文菜单：

```
╔═══════════════════════════════════════╗
║      🔧 OpenClaw 简易配置工具         ║
╚═══════════════════════════════════════╝

  1. 🤖 配置大模型 API
  2. 📱 配置飞书机器人
  3. 🔍 查看当前配置
  4. 🔄 重启网关使配置生效

  0. 🚪 退出
```

### 配置大模型 API
- 支持：智谱 AI (GLM)、通义千问、DeepSeek、月之暗面 (Kimi)、MiniMax
- 选择供应商 → 选择模型 → 输入 API Key
- 完成后自动保存并可选择是否重启网关

> 💡 **推荐**：智谱 GLM 免费 API (glm-4-flash)：https://www.bigmodel.cn/invite?icode=xWdj8FBSlTeq3bY3R3fPbkjPr3uHog9F4g5tjuOUqno%3D

### 配置飞书机器人
- 输入 App ID、App Secret、Verification Token
- 完成后自动保存并可选择是否重启网关

**其他常用命令：**
```bash
openclaw dashboard   # 打开网页控制台
openclaw status      # 查看状态
openclaw logs        # 查看日志
```

---

## 相关链接

- [OpenClaw 官方](https://openclaw.ai)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [本项目 Issues](https://github.com/ClawTribe/openclaw-oneclick/issues)

---

## 许可

MIT License | Original by Jun | Modified & Optimized by ClawTribe

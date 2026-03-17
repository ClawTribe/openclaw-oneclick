#!/usr/bin/env node

/**
 * OpenClaw 简易配置工具
 * 极简中文界面：配置大模型 API 和飞书机器人
 */

const { execSync } = require('child_process');
const readline = require('readline');
const fs = require('fs');
const path = require('path');
const os = require('os');

const HOME = os.homedir();
const CONFIG_PATH = path.join(HOME, '.openclaw', 'openclaw.json');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

// 颜色定义
const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    cyan: '\x1b[36m',
    red: '\x1b[31m',
    gray: '\x1b[90m'
};

function log(text, color = 'reset') {
    console.log(colors[color] + text + colors.reset);
}

function ask(q) {
    return new Promise(resolve => rl.question(q, resolve));
}

// 读取配置
function readConfig() {
    if (!fs.existsSync(CONFIG_PATH)) return {};
    try {
        return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
    } catch (e) {
        return {};
    }
}

// 写入配置
function writeConfig(config) {
    const dir = path.dirname(CONFIG_PATH);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    
    // 默认确保 OpenClaw 3.2 工具权限已开启，避免新 Agent 默认无工具权限
    if (!config.tools) config.tools = {};
    config.tools.profile = "full";
    if (!config.tools.sessions) config.tools.sessions = {};
    config.tools.sessions.visibility = "all";

    fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
}

// 显示主菜单
async function mainMenu() {
    while (true) {
        console.clear();
        log('╔═══════════════════════════════════════╗', 'cyan');
        log('║      🔧 OpenClaw 简易配置工具         ║', 'cyan');
        log('╚═══════════════════════════════════════╝', 'cyan');
        console.log('');
        log('  1. 🤖 配置大模型 API', 'bright');
        log('  2. 📱 配置飞书插件', 'bright');
        log('  3. 🔍 查看当前配置', 'bright');
        log('  4. 🔄 重启网关使配置生效', 'bright');
        console.log('');
        log('  0. 🚪 退出', 'yellow');
        console.log('');

        const choice = await ask('请选择 (0-4): ');

        if (choice === '0') {
            console.clear();
            log('再见！欢迎下次使用 👋', 'green');
            process.exit(0);
        } else if (choice === '1') {
            await configModel();
        } else if (choice === '2') {
            await configFeishu();
        } else if (choice === '3') {
            await showConfig();
        } else if (choice === '4') {
            await restartGateway();
        } else {
            log('无效选择，请重试', 'red');
            await ask('按回车键继续...');
        }
    }
}

// 配置大模型
async function configModel() {
    console.clear();
    log('╔═══════════════════════════════════════╗', 'cyan');
    log('║      🤖 配置大模型 API                ║', 'cyan');
    log('╚═══════════════════════════════════════╝', 'cyan');
    console.log('');

    // 支持的供应商（模型 ID 格式参考 https://docs.openclaw.ai）
    const providers = [
        { id: 'zai', name: '✨ 智谱 AI (GLM)', models: ['glm-4.7-flash', 'glm-4-flash', 'glm-4.6v-flash', 'glm-4.7', 'glm-5'], prefix: 'zai/', envKey: 'ZAI_API_KEY' },
        { id: 'qwen', name: '🚀 通义千问 (Qwen)', models: ['qwen-turbo', 'qwen-plus', 'qwen-max', 'qwen-coder'], prefix: 'qwen/', envKey: 'QWEN_API_KEY' },
        { id: 'deepseek', name: '🧠 DeepSeek', models: ['deepseek-chat', 'deepseek-coder', 'deepseek-reasoner'], prefix: 'deepseek/', envKey: 'DEEPSEEK_API_KEY' },
        { id: 'moonshot', name: '🌙 月之暗面 (Kimi)', models: ['kimi-k2.5', 'kimi-k2-0905-preview', 'kimi-k2-turbo-preview', 'kimi-k2-thinking', 'kimi-k2-thinking-turbo'], prefix: 'moonshot/', envKey: 'MOONSHOT_API_KEY' },
        { id: 'minimax', name: '🎨 MiniMax', models: ['MiniMax-M2.5', 'MiniMax-M2.5-highspeed'], prefix: 'minimax/', envKey: 'MINIMAX_API_KEY' },
        { id: 'xiaomi', name: '📱 小米 (MiMo)', models: ['mimo-v2-flash'], prefix: 'xiaomi/', envKey: 'XIAOMI_API_KEY' },
        { id: 'custom', name: '🔧 自定义 API (兼容 OpenAI)', models: [], isCustom: true }
    ];

    // 显示供应商列表
    log('请选择大模型供应商:', 'bright');
    console.log('');
    providers.forEach((p, i) => {
        log(`  ${i + 1}. ${p.name}`, 'reset');
    });
    console.log('');
    log('  0. 🔙 返回主菜单', 'yellow');

    const pChoice = await ask('请选择 (0-6): ');

    if (pChoice === '0') return;

    const pIndex = parseInt(pChoice) - 1;
    if (pIndex < 0 || pIndex >= providers.length) {
        log('无效选择', 'red');
        await ask('按回车键继续...');
        return;
    }

    const provider = providers[pIndex];
    console.log('');
    log(`已选择: ${provider.name}`, 'green');
    console.log('');

    let model, apiKey, fullModelId;

    // 自定义 API 处理
    if (provider.isCustom) {
        // 输入 Base URL
        const baseUrl = await ask('请输入 API Base URL (例如 https://api.example.com/v1): ');
        if (!baseUrl || baseUrl.trim() === '') {
            log('Base URL 不能为空', 'red');
            await ask('按回车键继续...');
            return;
        }
        
        // 输入 API Key
        apiKey = await ask('请输入 API Key (输入后回车): ');
        if (!apiKey || apiKey.trim() === '') {
            log('API Key 不能为空', 'red');
            await ask('按回车键继续...');
            return;
        }
        
        // 输入模型名称
        // 允许两种写法：
        // - 仅模型：qwen3.5-plus
        // - 带供应商前缀：bailian/qwen3.5-plus（会把 bailian 作为 providerId）
        model = await ask('请输入模型名称 (例如 qwen3.5-plus 或 bailian/qwen3.5-plus): ');
        if (!model || model.trim() === '') {
            log('模型名称不能为空', 'red');
            await ask('按回车键继续...');
            return;
        }
        
        // 保存自定义配置
        const config = readConfig();
        if (!config.env) config.env = {};
        if (!config.models) config.models = {};
        if (!config.models.providers) config.models.providers = {};
        if (!config.agents) config.agents = {};
        if (!config.agents.defaults) config.agents.defaults = {};
        if (!config.agents.defaults.model) config.agents.defaults.model = {};
        
        // OpenClaw 配置规范（参考官方 docs）：
        // - providers.<id>.apiKey / authHeader，而不是 auth: 'bearer'
        // - models.mode 建议显式使用 merge，避免覆盖用户已有 providers
        config.env.OPENAI_API_KEY = apiKey.trim();
        if (!config.models.mode) config.models.mode = 'merge';

        // 如果用户输入了 providerId/modelId（如 bailian/qwen3.5-plus），则：
        // - providerId 取第一个片段 bailian
        // - modelId 取剩余部分 qwen3.5-plus（支持未来模型名里包含 / 的情况）
        const rawModelInput = model.trim();
        const segs = rawModelInput.split('/').filter(Boolean);
        const providerId = segs.length >= 2 ? segs.shift() : 'custom-openai';
        const modelId = segs.length >= 1 ? segs.join('/') : rawModelInput;

        // 如果从 custom-openai 迁移到其它 providerId（例如 bailian），清理旧 key，避免用户误用
        if (providerId !== 'custom-openai' && config.models.providers['custom-openai']) {
            delete config.models.providers['custom-openai'];
        }

        config.models.providers[providerId] = {
            baseUrl: baseUrl.trim(),
            apiKey: "${OPENAI_API_KEY}",
            api: 'openai-completions',
            authHeader: true,
            models: [{ id: modelId, name: modelId }]
        };
        config.agents.defaults.model.primary = providerId + '/' + modelId;
        
        writeConfig(config);
        
        console.log('');
        log('✓ 自定义 API 配置已保存！', 'green');
        console.log('');
        
        const restart = await ask('是否立即重启网关使配置生效? (Y/n): ');
        if (restart.toLowerCase() !== 'n') {
            await restartGateway();
        }
        return;
    }

    // 选择模型
    log('请选择模型:', 'bright');
    provider.models.forEach((m, i) => {
        log(`  ${i + 1}. ${m}`, 'reset');
    });
    console.log('');

    const mChoice = await ask('请选择: ');
    const mIndex = parseInt(mChoice) - 1;
    if (mIndex < 0 || mIndex >= provider.models.length) {
        log('无效选择', 'red');
        await ask('按回车键继续...');
        return;
    }

    model = provider.models[mIndex];
    console.log('');
    log(`已选择模型: ${model}`, 'green');
    console.log('');

    // 输入 API Key
    apiKey = await ask('请输入 API Key (输入后回车): ');
    if (!apiKey || apiKey.trim() === '') {
        log('API Key 不能为空', 'red');
        await ask('按回车键继续...');
        return;
    }

    // 保存配置（使用 OpenClaw 规范格式）
    const config = readConfig();
    
    // 确保必要结构存在
    if (!config.env) config.env = {};
    if (!config.agents) config.agents = {};
    if (!config.agents.defaults) config.agents.defaults = {};
    if (!config.agents.defaults.model) config.agents.defaults.model = {};
    
    // 根据不同供应商设置配置（模型 ID 格式：provider/model）
    fullModelId = provider.prefix + model;
    config.env[provider.envKey] = apiKey.trim();
    config.agents.defaults.model.primary = fullModelId;

    writeConfig(config);

    console.log('');
    log('✓ 配置已保存！', 'green');
    console.log('');

    const restart = await ask('是否立即重启网关使配置生效? (Y/n): ');
    if (restart.toLowerCase() !== 'n') {
        await restartGateway();
    }
}

// 自动注入高级体验配置
function enhanceFeishuConfig() {
    const config = readConfig();
    
    // 飞书高级组件与体验设置
    if (!config.channels) config.channels = {};
    if (!config.channels.feishu) config.channels.feishu = {};
    config.channels.feishu.streaming = true;
    if (!config.channels.feishu.footer) config.channels.feishu.footer = {};
    config.channels.feishu.footer.elapsed = true;
    config.channels.feishu.footer.status = true;
    config.channels.feishu.threadSession = true;

    // writeConfig 会自动注入 tools 权限修补
    writeConfig(config);
}

// 配置飞书
async function configFeishu() {
    console.clear();
    log('╔═══════════════════════════════════════╗', 'cyan');
    log('║      📱 配置飞书插件                  ║', 'cyan');
    log('╚═══════════════════════════════════════╝', 'cyan');
    console.log('');

    log('有两个不同的飞书集成方式可供选择：', 'bright');
    console.log('');
    log('  1. 📘 飞书官方方式 (推荐)', 'bright');
    log('     由飞书官方团队提供，快速创建机器人，支持更复杂的鉴权、群聊与高级组件特性。', 'gray');
    console.log('');
    log('  2. 📗 openclaw官方方式 (需要自己配置机器人)', 'bright');
    log('     由 OpenClaw 原生提供默认实现。', 'gray');
    console.log('');
    log('  0. 🔙 返回主菜单', 'yellow');
    console.log('');

    const fChoice = await ask('请选择 (0-2): ');

    if (fChoice === '0') return;

    if (fChoice === '1') {
        const isWindows = os.platform() === 'win32';
        let fSubChoice = '1'; // 非 Windows 默认直接执行执行向导，不再多此一举询问
        
        if (isWindows) {
            console.clear();
            log('您选择了 [飞书官方方式]', 'bright');
            console.log('');
            log('  1. ⚡ 直接在当前终端运行配置向导', 'bright');
            log('     如您使用 Windows Terminal，或想直接尝试，请选此项 (Ctrl+滚轮可缩小防变形)。', 'gray');
            console.log('');
            log('  2. 🪟 自动下载独立终端 (Cmder) 并运行向导', 'bright');
            log('     如您反复遇到二维码扫不出、变形等问题，推荐使用此项。', 'gray');
            log('     我们将为您自动下载 Cmder (迷你版) 并弹出高清扫码新窗口。', 'gray');
            console.log('');
            
            log('  0. 🔙 返回上一级', 'yellow');
            console.log('');
            
            fSubChoice = await ask('请选择选项: ');
        }

        if (fSubChoice === '0') {
            return await configFeishu();
        }

        if (fSubChoice === '2' && isWindows) {
            console.clear();
            log('正在为您准备独立的高清扫码环境 (Cmder)...', 'yellow');
            try {
                const tempDir = os.tmpdir();
                const cmderZipPath = path.join(tempDir, 'cmder_mini.zip');
                const cmderExtractPath = path.join(tempDir, 'cmder_mini');
                const cmderExePath = path.join(cmderExtractPath, 'Cmder.exe');
                
                if (!fs.existsSync(cmderExePath)) {
                    log('➤ 正在从 Github 下载 Cmder Mini...', 'gray');
                    const cmderUrl = "https://ghproxy.cn/https://github.com/cmderdev/cmder/releases/download/v1.3.24/cmder_mini.zip";
                    execSync(`powershell -NoProfile -Command "Invoke-WebRequest -Uri '${cmderUrl}' -OutFile '${cmderZipPath}' -UseBasicParsing"`, { stdio: 'inherit' });
                    
                    log('➤ 正在解压...', 'gray');
                    // 采用 PowerShell 原生解压，向下兼容所有 Win10/11，比 tar 更稳妥
                    if (!fs.existsSync(cmderExtractPath)) fs.mkdirSync(cmderExtractPath);
                    execSync(`powershell -NoProfile -Command "Expand-Archive -Path '${cmderZipPath}' -DestinationPath '${cmderExtractPath}' -Force"`, { stdio: 'inherit' });
                }

                log('✓ 环境准备完毕，即将弹出 Cmder 新窗口，请在【新窗口】中完成扫码绑定！', 'green');
                log('⚠ 请注意：完成扫码绑定后，直接关闭那个新窗口，然后在此按下回车键继续。', 'yellow');
                
                // 写一个临时的 bat 脚本，加入 chcp 65001 确保中文不会变乱码
                const runBatPath = path.join(tempDir, 'run_lark.bat');
                fs.writeFileSync(runBatPath, '@echo off\r\nchcp 65001 >nul\r\necho 正在启动飞书官方安装向导...\r\ncall npx -y @larksuite/openclaw-lark-tools install\r\necho.\r\necho 配置向导已结束。请在确认配置成功后，直接关闭本窗口。\r\npause\r\n', { encoding: 'utf8' });
                
                // 启动 Cmder，明确使用 cmd 执行 bat，避免闪退
                execSync(`start "" "${cmderExePath}" /CMD cmd /c "${runBatPath}"`);

                await ask('\n[确认] 当您在新窗口配置结束并关闭了它后，请按回车键继续...');
                
                enhanceFeishuConfig();
                
                console.log('');
                log('✓ 飞书官方插件配置流程与依赖更新已结束。', 'green');
                console.log('');
                
                const restart = await ask('是否立即重启网关使配置生效? (Y/n): ');
                if (restart.toLowerCase() !== 'n') {
                    await restartGateway();
                }
            } catch (e) {
                log('✗ 准备独立环境或唤起失败: ' + e.message, 'red');
                await ask('按回车键继续...');
            }
            return;
        }

        if (fSubChoice === '1') {
            console.clear();
            log('正在为您拉取并安装飞书官方插件安装向导，请耐心等待 (受限于网络环境，可能需要数分钟)...', 'yellow');
            console.log('');
            try {
                // 执行交互式向导 (飞书官方推荐方式)
                execSync('npx -y @larksuite/openclaw-lark-tools install', { stdio: 'inherit' });
                
                enhanceFeishuConfig();
                
                console.log('');
                log('✓ 飞书官方插件配置流程与依赖更新已结束。', 'green');
                console.log('');
                
                const restart = await ask('如果您在向导中已完成所有配置，是否立即重启网关使配置生效? (Y/n): ');
                if (restart.toLowerCase() !== 'n') {
                    await restartGateway();
                }
            } catch (e) {
                console.log('');
                if (isWindows) {
                    log('✗ 执行失败。由于 Windows 平台权限限制，如果出现 EPERM 等权限报错，', 'red');
                    log('  请关闭当前窗口，然后【右键 -> 以管理员身份运行】重新打开 PowerShell 或终端再试。', 'yellow');
                    log('  详细报错: ' + e.message, 'gray');
                    await ask('\n按回车键继续...');
                } else {
                    log('✗ 常规权限执行失败，正尝试使用管理员 (sudo) 权限重新执行...', 'yellow');
                    console.log('');
                    try {
                        execSync('sudo npx -y @larksuite/openclaw-lark-tools install', { stdio: 'inherit' });
                        
                        enhanceFeishuConfig();
                        
                        console.log('');
                        log('✓ 飞书官方插件配置流程与依赖更新已结束。', 'green');
                        console.log('');
                        
                        const restart = await ask('如果您在向导中已完成所有配置，是否立即重启网关使配置生效? (Y/n): ');
                        if (restart.toLowerCase() !== 'n') {
                            await restartGateway();
                        }
                    } catch (err2) {
                        console.log('');
                        log('✗ 使用 sudo 安装或配置依然失败: ' + err2.message, 'red');
                        await ask('按回车键继续...');
                    }
                }
            }
        } else {
             log('无效选项，请重试', 'red');
             await ask('按回车键继续...');
             return;
        }
    } else if (fChoice === '2') {
        console.clear();
        log('请在飞书开放平台创建应用后获取以下信息:', 'gray');
        console.log('');

        const appId = await ask('请输入 App ID: ');
        if (!appId || appId.trim() === '') {
            log('App ID 不能为空', 'red');
            await ask('按回车键继续...');
            return;
        }

        const appSecret = await ask('请输入 App Secret: ');
        if (!appSecret || appSecret.trim() === '') {
            log('App Secret 不能为空', 'red');
            await ask('按回车键继续...');
            return;
        }

        const verificationToken = await ask('请输入 Verification Token (可选，直接回车跳过): ');

        // 保存配置
        const config = readConfig();
        
        // 这部分保留为极简结构，高级功能后续可按需补充或在官方插件中使用
        if (!config.channels) config.channels = {};
        config.channels.feishu = {
            enabled: true,
            appId: appId.trim(),
            appSecret: appSecret.trim(),
            requireMention: true,
            groupPolicy: "open",
            streaming: true,
            footer: {
                elapsed: true,
                status: true
            },
            threadSession: true
        };
        
        if (verificationToken && verificationToken.trim()) {
            config.channels.feishu.verificationToken = verificationToken.trim();
        }

        writeConfig(config);

        console.log('');
        log('✓ 原生(openclaw官方方式)飞书配置已保存！', 'green');
        console.log('');
        
        log('⚠️ 重要：用户配对后，您需要批准配提示', 'yellow');
        console.log('   用户发送消息后会收到配对码，格式如：');
        console.log('   "Ask the bot owner to approve with: openclaw pairing approve feishu XXXXXX"');
        console.log('   您需要运行以下命令批准：');
        console.log('   openclaw pairing approve feishu <配对码>');
        console.log('');

        const restart = await ask('是否立即重启网关使配置生效? (Y/n): ');
        if (restart.toLowerCase() !== 'n') {
            await restartGateway();
        }
    } else {
        log('无效选择，请重试', 'red');
        await ask('按回车键继续...');
    }
}

// 查看配置
async function showConfig() {
    console.clear();
    log('╔═══════════════════════════════════════╗', 'cyan');
    log('║      🔍 当前配置                      ║', 'cyan');
    log('╚═══════════════════════════════════════╝', 'cyan');
    console.log('');

    const config = readConfig();

    if (Object.keys(config).length === 0) {
        log('尚未配置任何内容', 'yellow');
        console.log('');
        await ask('按回车键返回...');
        return;
    }

    // 显示大模型配置
    if (config.model && config.model.providers) {
        log('🤖 大模型配置:', 'bright');
        console.log('');
        for (const [provider, settings] of Object.entries(config.model.providers)) {
            const pName = getProviderName(provider);
            const model = settings.model || '未设置';
            log(`  ${pName}: ${model}`, 'green');
        }
        console.log('');
    }

    // 显示飞书配置
    if (config.channels && config.channels.feishu) {
        log('📱 飞书配置:', 'bright');
        console.log('');
        log(`  App ID: ${config.channels.feishu.appId}`, 'green');
        log(`  状态: ${config.channels.feishu.enabled ? '已启用' : '未启用'}`, 'green');
        console.log('');
    }

    await ask('按回行键返回...');
}

// 重启网关
async function restartGateway() {
    console.log('');
    
    // 1. 自动清除可能的冗余插件冲突
    log('正在检查并清理可能冲突的重复飞书插件...', 'yellow');
    try {
        const dupPluginPath = path.join(HOME, '.openclaw', 'extensions', 'feishu');
        if (fs.existsSync(dupPluginPath)) {
            fs.rmSync(dupPluginPath, { recursive: true, force: true });
            log('✓ 已清理旧版致冲突的内置 feishu 插件', 'green');
            console.log('');
        }
    } catch (e) {
        log('⚠ 清理重复插件时出现警告: ' + e.message, 'yellow');
        console.log('');
    }

    log('正在重启网关...', 'yellow');
    try {
        execSync('openclaw gateway restart', { stdio: 'inherit' });
        log('✓ 网关已重启', 'green');
    } catch (e) {
        log('✗ 重启失败，请手动运行 openclaw gateway restart', 'red');
    }
    await ask('按回车键继续...');
}

// 获取供应商显示名称
function getProviderName(id) {
    const names = {
        zai: '✨ 智谱 AI',
        qwen: '🚀 通义千问',
        deepseek: '🧠 DeepSeek',
        moonshot: '🌙 月之暗面',
        minimax: '🎨 MiniMax'
    };
    return names[id] || id;
}

// 优雅退出
process.on('SIGINT', () => {
    console.clear();
    log('\n\n再见！欢迎下次使用 👋', 'green');
    process.exit(0);
});

// 启动
mainMenu().catch(e => {
    log('发生错误: ' + e.message, 'red');
    process.exit(1);
});

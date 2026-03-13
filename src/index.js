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
        log('  2. 📱 配置飞书机器人', 'bright');
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

    // 支持的供应商
    const providers = [
        { id: 'zai', name: '✨ 智谱 AI (GLM)', models: ['glm-4-flash', 'glm-4-plus', 'glm-4v-flash'] },
        { id: 'qwen', name: '🚀 通义千问 (Qwen)', models: ['qwen-turbo', 'qwen-plus', 'qwen-max'] },
        { id: 'deepseek', name: '🧠 DeepSeek', models: ['deepseek-chat', 'deepseek-coder'] },
        { id: 'moonshot', name: '🌙 月之暗面 (Kimi)', models: ['kimi-chat'] },
        { id: 'minimax', name: '🎨 MiniMax', models: ['abab6.5s-chat'] }
    ];

    // 显示供应商列表
    log('请选择大模型供应商:', 'bright');
    console.log('');
    providers.forEach((p, i) => {
        log(`  ${i + 1}. ${p.name}`, 'reset');
    });
    console.log('');
    log('  0. 🔙 返回主菜单', 'yellow');

    const pChoice = await ask('请选择 (0-5): ');

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

    const model = provider.models[mIndex];
    console.log('');
    log(`已选择模型: ${model}`, 'green');
    console.log('');

    // 输入 API Key
    const apiKey = await ask('请输入 API Key (输入后回车): ');
    if (!apiKey || apiKey.trim() === '') {
        log('API Key 不能为空', 'red');
        await ask('按回车键继续...');
        return;
    }

    // 保存配置
    const config = readConfig();
    
    // 根据不同供应商设置配置
    if (provider.id === 'zai') {
        config.model = { providers: { zai: { apiKey: apiKey.trim(), model: model } } };
    } else if (provider.id === 'qwen') {
        config.model = { providers: { qwen: { apiKey: apiKey.trim(), model: model } } };
    } else if (provider.id === 'deepseek') {
        config.model = { providers: { deepseek: { apiKey: apiKey.trim(), model: model } } };
    } else if (provider.id === 'moonshot') {
        config.model = { providers: { moonshot: { apiKey: apiKey.trim(), model: model } } };
    } else if (provider.id === 'minimax') {
        config.model = { providers: { minimax: { apiKey: apiKey.trim(), model: model } } };
    }

    writeConfig(config);

    console.log('');
    log('✓ 配置已保存！', 'green');
    console.log('');

    const restart = await ask('是否立即重启网关使配置生效? (Y/n): ');
    if (restart.toLowerCase() !== 'n') {
        await restartGateway();
    }
}

// 配置飞书
async function configFeishu() {
    console.clear();
    log('╔═══════════════════════════════════════╗', 'cyan');
    log('║      📱 配置飞书机器人                ║', 'cyan');
    log('╚═══════════════════════════════════════╝', 'cyan');
    console.log('');

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
    
    // 设置飞书配置
    if (!config.channels) config.channels = {};
    config.channels.feishu = {
        enabled: true,
        appId: appId.trim(),
        appSecret: appSecret.trim()
    };
    
    if (verificationToken && verificationToken.trim()) {
        config.channels.feishu.verificationToken = verificationToken.trim();
    }

    writeConfig(config);

    console.log('');
    log('✓ 飞书配置已保存！', 'green');
    console.log('');

    const restart = await ask('是否立即重启网关使配置生效? (Y/n): ');
    if (restart.toLowerCase() !== 'n') {
        await restartGateway();
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

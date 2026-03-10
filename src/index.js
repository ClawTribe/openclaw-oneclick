#!/usr/bin/env node

/**
 * OpenClaw 核心入口
 * 交互优化版
 */

const { execSync } = require('child_process');
const readline = require('readline');
const SCHEMA = require('./config-map');
const engine = require('./config-engine');
const ui = require('./cli-ui');
const pkg = require('../package.json');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

// 优雅退出
process.on('SIGINT', () => {
    console.log(ui.msg('yellow', '\n\n再见！'));
    process.exit(0);
});

// 工具
function ask(q) {
    return new Promise(resolve => rl.question(q, resolve));
}

function sleep(ms) {
    return new Promise(r => setTimeout(r, ms));
}

function isNewer(r, l) {
    const rv = r.split('.').map(Number);
    const lv = l.split('.').map(Number);
    for (let i = 0; i < 3; i++) {
        if ((rv[i] || 0) > (lv[i] || 0)) return true;
        if ((rv[i] || 0) < (lv[i] || 0)) return false;
    }
    return false;
}

// 版本检查
async function checkUpdate() {
    console.log(ui.info('检查更新...'));
    try {
        let raw;
        let isProxy = false;
        try {
            // 尝试直连获取新版配置
            raw = execSync(
                `curl -s --connect-timeout 3 -m 5 "https://raw.githubusercontent.com/ClawTribe/openclaw-oneclick/main/package.json?t=${Date.now()}"`,
                { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }
            );
        } catch (e) {
            // 失败则降级使用代理加速源
            isProxy = true;
            raw = execSync(
                `curl -s --connect-timeout 3 -m 8 "https://ghproxy.net/https://raw.githubusercontent.com/ClawTribe/openclaw-oneclick/main/package.json?t=${Date.now()}"`,
                { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }
            );
        }

        const remote = JSON.parse(raw);
        if (isNewer(remote.version, pkg.version)) {
            console.log(ui.warning(`新版本 v${remote.version} 可用 (当前 v${pkg.version})`));
            console.log(`  1) 更新  2) 跳过`);
            const c = await ask('选择: ');
            if (c === '1') {
                const proxyPrefix = isProxy ? 'https://ghproxy.net/' : '';
                const cmd = process.platform === 'win32'
                    ? `powershell -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('${proxyPrefix}https://raw.githubusercontent.com/ClawTribe/openclaw-oneclick/main/install.ps1'))"`
                    : `curl -sSL ${proxyPrefix}https://raw.githubusercontent.com/ClawTribe/openclaw-oneclick/main/install.sh | bash`;
                execSync(cmd, { stdio: 'inherit' });
                process.exit(0);
            }
        } else {
            console.log(ui.success('已是最新'));
        }
    } catch (e) {
        console.log(ui.msg('gray', '跳过更新检查 (网络连接超时)'));
    }
    await sleep(300);
}

// enquirer
let Select, Input, Toggle;
try {
    const eq = require('enquirer');
    Select = eq.Select;
    Input = eq.Input;
    Toggle = eq.Toggle;
} catch (e) {
    console.log(ui.error('缺少 enquirer，请重新安装'));
    process.exit(1);
}

async function selectOrCustomInput(item, lang, current) {
    const choices = [
        ...(item.options || []),
        '✍️ 手动输入'
    ];
    const picker = new Select({
        message: item.label[lang] + ' (按上下键选择，回车确认):',
        choices
    });
    const choice = await picker.run();
    if (choice === '自定义' || choice === '✍️ 手动输入') {
        const inputPrompt = new Input({
            message: `⌨️ 请手动输入 [${item.label[lang]}] 的内容:`,
            initial: Array.isArray(current) ? current.join(', ') : (current || '')
        });
        const raw = await inputPrompt.run();
        if (item.isArray) {
            return raw
                .split(',')
                .map(s => s.trim())
                .filter(Boolean);
        }
        return raw;
    }
    return choice;
}

// 头部与状态概览
function showHeader() {
    console.clear();
    ui.setLang(engine.getLang());
    console.log(ui.getHeader(pkg.version));
    
    // 给纯小白的引导语与状态检查
    const config = engine.read();
    const primaryModel = engine.get(config, 'agents.defaults.model.primary');
    
    // 简单判断是否是初次配或者什么都没填
    if (!primaryModel || primaryModel === '未配置') {
        console.log(ui.msg('magenta', '   ✨ 欢迎使用！您似乎是第一次打开。'));
        console.log(ui.msg('gray', '   👉 第一步: 请在列表里选择 [0] 基础核心 -> 设置您的【主模型】\n'));
    } else {
        const providerName = primaryModel.split('/')[0];
        console.log(ui.msg('green', `   🟢 当前大模型驱动: ${primaryModel}`));
        console.log(ui.msg('gray', `   (如要正常对话，请确保已配置 ${providerName} 的 API Key)\n`));
    }
}

// ====== 新增: API Key 测速与验证 ======
async function testApiKey(provider, apiKey) {
    console.log(ui.info(`\n📡 正在测速与验证 ${provider} API Key 连通性...`));
    try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 8000); // 8秒超时限制
        
        let res;
        const normProvider = provider.replace('-cli', '').toLowerCase();
        
        if (normProvider === 'openai') {
            res = await fetch('https://api.openai.com/v1/models', {
                headers: { 'Authorization': `Bearer ${apiKey}` },
                signal: controller.signal
            });
        } else if (normProvider === 'deepseek') {
            res = await fetch('https://api.deepseek.com/models', {
                headers: { 'Authorization': `Bearer ${apiKey}`, 'Accept': 'application/json' },
                signal: controller.signal
            });
        } else if (normProvider.startsWith('google') || normProvider === 'gemini') {
            res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`, {
                signal: controller.signal
            });
        } else if (normProvider === 'anthropic' || normProvider === 'claude') {
            res = await fetch('https://api.anthropic.com/v1/messages', {
                method: 'POST',
                headers: { 
                    'x-api-key': apiKey, 
                    'anthropic-version': '2023-06-01',
                    'content-type': 'application/json' 
                },
                body: JSON.stringify({
                    model: 'claude-3-haiku-20240307',
                    max_tokens: 1,
                    messages: [{role: 'user', content: 'hi'}]
                }),
                signal: controller.signal
            });
        } else if (['minimax', 'glm', 'moonshot', 'volcengine', 'qwen'].includes(normProvider)) {
            const providerConfigMap = {
                minimax: 'models.providers.minimax',
                glm: 'models.providers.glm',
                moonshot: 'models.providers.moonshot',
                volcengine: 'models.providers.volcengine',
                qwen: 'models.providers.qwen'
            };
            const currentConfig = engine.read();
            const providerConfig = engine.get(currentConfig, providerConfigMap[normProvider]) || {};
            const baseUrl = providerConfig.baseUrl;
            if (!baseUrl) {
                clearTimeout(timeout);
                return { ok: null, msg: `请先配置 ${provider} 的 baseUrl，再进行连通性验证` };
            }
            const modelsUrl = `${String(baseUrl).replace(/\/$/, '')}/models`;
            res = await fetch(modelsUrl, {
                headers: { 'Authorization': `Bearer ${apiKey}`, 'Accept': 'application/json' },
                signal: controller.signal
            });
        } else {
            clearTimeout(timeout);
            return { ok: null, msg: `暂不支持 ${provider} 的自动验证，跳过测试` };
        }
        
        clearTimeout(timeout);
        
        if (res && res.status === 200) {
            return { ok: true, msg: '验证通过，网络连接与鉴权正常！' };
        } else if (res && (res.status === 401 || res.status === 403)) {
            return { ok: false, msg: `验证失败 (HTTP ${res.status}): API Key 错误或欠费` };
        } else if (res) {
            return { ok: false, msg: `请求异常 (HTTP ${res.status}): 所选服务商节点暂时异常` };
        }
        return { ok: false, msg: '未知网络错误' };
    } catch (e) {
        if (e.name === 'AbortError') {
            return { ok: false, msg: '网络连接超时！服务商 API 无法直连，您的电脑终端可能尚未配置科学上网代理环节。' };
        }
        return { ok: false, msg: `网络请求失败: ${e.message}` };
    }
}
// ===================================

// 编辑配置
async function editConfig(config, item) {
    const lang = engine.getLang();
    const current = engine.get(config, item.key);

    // 显示配置说明
    if (item.desc) {
        console.log(ui.showConfigInfo(item.label[lang], item.desc[lang]));
    }

    let newVal;
    try {
        if (item.type === 'boolean') {
            const p = new Toggle({
                message: item.label[lang] + ' (开关)',
                enabled: '🔴 开启',
                disabled: '⚪ 关闭',
                initial: current === true
            });
            newVal = await p.run();
        } else if (item.type === 'enum') {
            newVal = await selectOrCustomInput(item, lang, current);
        } else if (item.type === 'json') {
            const initialJson = current
                ? JSON.stringify(current, null, 2)
                : JSON.stringify(item.template || {}, null, 2);
            const p = new Input({
                message: `⌨️ 请以 JSON 形式输入 [${item.label[lang]}] 的内容:`,
                initial: initialJson
            });
            const raw = await p.run();
            newVal = raw ? JSON.parse(raw) : {};
        } else {
            const p = new Input({
                message: `⌨️ 请在此输入 [${item.label[lang]}] 的内容:`,
                initial: current || ''
            });
            newVal = await p.run();
        }
    } catch (e) {
        return; // 取消
    }

    if (newVal !== undefined && newVal !== current) {
        if (item.isArray && !Array.isArray(newVal)) {
            newVal = newVal ? [newVal] : [];
        }
        engine.set(config, item.key, newVal);

        // 模型选择后提示输入 API Key 并进行自动检测
        if (item.needsApiKey && newVal && String(newVal).includes('/')) {
            const modelStr = Array.isArray(newVal) ? newVal[0] : newVal;
            const provider = modelStr.split('/')[0];
            if (provider !== 'ollama') {
                console.log(ui.info(`\n👉 ${provider} 模型需要 API Key`));
                try {
                    const keyPrompt = new Input({ message: `请输入 ${provider.toUpperCase()} API Key (留空跳过):` });
                    const apiKey = await keyPrompt.run();
                    const cleanKey = apiKey ? apiKey.trim() : '';
                    
                    if (cleanKey) {
                        // 第 1 步：连通性测试
                        const testResult = await testApiKey(provider, cleanKey);
                        if (testResult.ok === true) {
                            console.log(ui.success(testResult.msg));
                        } else if (testResult.ok === false) {
                            console.log(ui.error(testResult.msg));
                        } else {
                            console.log(ui.msg('gray', testResult.msg));
                        }
                        
                        // 第 2 步：环境变量环境变量名映射
                        const envMap = {
                            'openai': 'OPENAI_API_KEY',
                            'anthropic': 'ANTHROPIC_API_KEY',
                            'google': 'GEMINI_API_KEY',
                            'google-gemini-cli': 'GEMINI_API_KEY',
                            'deepseek': 'DEEPSEEK_API_KEY',
                            'minimax': 'MINIMAX_API_KEY',
                            'glm': 'GLM_API_KEY',
                            'moonshot': 'MOONSHOT_API_KEY',
                            'volcengine': 'ARK_API_KEY',
                            'qwen': 'DASHSCOPE_API_KEY'
                        };
                        const providerDisplayNameMap = {
                            minimax: 'MiniMax',
                            glm: 'GLM',
                            moonshot: 'Kimi',
                            volcengine: 'Doubao',
                            qwen: 'Qwen'
                        };
                        const normProvider = provider.replace('-cli', '');
                        const envVar = envMap[normProvider] || `${provider.toUpperCase()}_API_KEY`;
                        const providerDisplayName = providerDisplayNameMap[normProvider] || provider.toUpperCase();
                        
                        console.log(ui.msg('gray', `\n注: ${providerDisplayName} 依靠底层系统的环境变量 ${envVar} 运行（而非写死在项目配置中）。`));
                        
                        // 第 3 步：一键注入系统变量
                        try {
                            const injectPrompt = new Toggle({
                                message: `是否由脚本一键将 ${envVar} 注入到您的系统环境变量中 ?`,
                                enabled: '一键写入',
                                disabled: '稍后手动配',
                                initial: true
                            });
                            const doInject = await injectPrompt.run();
                            if (doInject) {
                                if (process.platform === 'win32') {
                                    // Windows 环境变量写入 (通过 setx 写入用户变量)
                                    execSync(`setx ${envVar} "${cleanKey}"`, { stdio: 'ignore' });
                                    console.log(ui.success(`🎉 成功保存至 Windows 用户环境变量！\n   为使环境变量生效，请重启当前终端命令提示符。`));
                                } else {
                                    // macOS / Linux 终端配置写入
                                    const fs = require('fs');
                                    const path = require('path');
                                    const shellFile = (process.env.SHELL && String(process.env.SHELL).includes('zsh')) ? '.zshrc' : '.bashrc';
                                    const shellPath = path.join(require('os').homedir(), shellFile);
                                    let content = '';
                                    if (fs.existsSync(shellPath)) {
                                        content = fs.readFileSync(shellPath, 'utf8');
                                    }
                                    const exportCmd = `export ${envVar}="${cleanKey}"`;
                                    if (content.includes(`export ${envVar}=`)) {
                                        const regex = new RegExp(`export ${envVar}=.*`, 'g');
                                        content = content.replace(regex, exportCmd);
                                    } else {
                                        content += `\n\n# OpenClaw Auto Inject for ${envVar}\n${exportCmd}\n`;
                                    }
                                    fs.writeFileSync(shellPath, content);
                                    console.log(ui.success(`🎉 成功保存至 ~/${shellFile}！\n   为使环境变量生效，请在主终端执行 'source ~/${shellFile}' 然后重启应用。`));
                                }
                            } else {
                                console.log(ui.msg('yellow', `请手动设置环境变量: export ${envVar}="${cleanKey}"`));
                            }
                        } catch (e) {
                             console.log(ui.msg('yellow', `自动写入中断，请手动设置环境变量。\n   Windows: setx ${envVar} "${cleanKey}"\n   Mac/Linux: export ${envVar}="${cleanKey}"`));
                        }
                    }
                } catch (e) {
                    // 用户取消
                }
            }
        }

        engine.write(config);
        console.log(ui.success(ui.t('saveOk')));
        await sleep(400);
    }
}

// 子菜单
async function subMenu(cat) {
    const lang = engine.getLang();
    ui.pushPath(cat.label[lang]);

    try {
        while (true) {
            showHeader();
            const config = engine.read();
            const choices = [];

            // 分类描述
            const style = ui.categoryStyle(cat.id);
            if (style.desc[lang]) {
                console.log(ui.msg('gray', `  ${style.desc[lang]}`));
            }
            console.log('');

            if (cat.subCategories) {
                // 子分类列表
                cat.subCategories.forEach(sub => {
                    const subStyle = ui.categoryStyle(sub.id);
                    choices.push({
                        name: sub.id,
                        message: ui.formatCategory(sub.id, sub.label[lang]),
                        hint: subStyle.desc[lang]
                    });
                });
            } else {
                // 特殊操作
                if (cat.specialActions) {
                    console.log(ui.msg('yellow', '  ▸ 快捷操作'));
                    cat.specialActions.forEach(act => {
                        choices.push({
                            name: 'act_' + act.id,
                            message: `  ${ui.colors.yellow}▶${ui.colors.reset} ${act.label[lang]}`,
                            hint: act.command
                        });
                    });
                    choices.push({ name: '_sep', message: ui.separator(40), role: 'separator' });
                    console.log(ui.msg('cyan', '  ▸ 配置项'));
                }

                // 配置项列表
                cat.items.forEach((item, i) => {
                    const val = engine.get(config, item.key);
                    const display = ui.formatValue(val, item);
                    choices.push({
                        name: String(i),
                        message: `  ${item.label[lang]}`,
                        hint: display
                    });
                });
            }

            choices.push({ name: '_sep2', message: '', role: 'separator' });

            const prompt = new Select({
                message: '选择',
                choices: choices.filter(c => c.role !== 'separator'),
                pointer: '❯'
            });

            let choice;
            try {
                choice = await prompt.run();
            } catch (e) {
                break;
            }

            if (choice === 'back') break;

            if (cat.subCategories) {
                const sub = cat.subCategories.find(s => s.id === choice);
                if (sub) await subMenu(sub);
            } else if (choice.startsWith('act_')) {
                const act = cat.specialActions.find(a => a.id === choice.replace('act_', ''));
                if (act) {
                    console.log(ui.info(`执行: ${act.command}`));
                    try {
                        execSync(act.command, { stdio: 'inherit' });
                        console.log(ui.success('完成'));
                    } catch (e) {
                        console.log(ui.error('失败'));
                    }
                    await ask(ui.t('enterToContinue'));
                }
            } else {
                const idx = parseInt(choice);
                if (!isNaN(idx) && cat.items[idx]) {
                    await editConfig(config, cat.items[idx]);
                }
            }
        }
    } finally {
        ui.popPath();
    }
}

// 主菜单
async function main() {
    await checkUpdate();
    ui.clearPath();

    while (true) {
        const lang = engine.getLang();
        showHeader();

        console.log(ui.msg('gray', '  选择要配置的功能模块\n'));

        const choices = SCHEMA.map((cat, i) => {
            const style = ui.categoryStyle(cat.id);
            return {
                name: String(i),
                message: `   ${ui.formatCategory(cat.id, cat.label[lang])}`,
                hint: style.desc[lang]
            };
        });

        choices.push({ name: '_sep', message: '', role: 'separator' });
        choices.push({ name: 'lang', message: `   🌐 ${ui.t('langSwitch')}` });
        choices.push({ name: 'restart', message: `   🔄 ${ui.t('restart')}` });
        choices.push({ name: 'exit', message: `   🚪 ${ui.t('exit')}` });

        let choice;
        try {
            const prompt = new Select({
                message: ui.t('mainPrompt'),
                choices: choices.filter(c => c.role !== 'separator'),
                pointer: '❯'
            });
            choice = await prompt.run();
        } catch (e) {
            continue;
        }

        if (choice === 'exit') {
            console.log(ui.msg('yellow', '\n再见！\n'));
            process.exit(0);
        }

        if (choice === 'lang') {
            engine.setLang(lang === 'zh' ? 'en' : 'zh');
            continue;
        }

        if (choice === 'restart') {
            console.log(ui.info(ui.t('restarting')));
            try {
                execSync('openclaw gateway restart', { stdio: 'inherit' });
                console.log(ui.success(ui.t('restartOk')));
            } catch (e) {
                console.log(ui.error('失败'));
            }
            await sleep(800);
            continue;
        }

        const idx = parseInt(choice);
        if (!isNaN(idx) && SCHEMA[idx]) {
            await subMenu(SCHEMA[idx]);
        }
    }
}

main().catch(e => {
    if (e === '') process.exit(0);
    console.error(e);
    process.exit(1);
});

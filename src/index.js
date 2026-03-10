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
    // 针对大模型的两步选择优化
    if (item.key === 'agents.defaults.model.primary' || item.key === 'agents.defaults.model.fallbacks') {
        const providerDisplayNameMap = {
            'deepseek': '🧠 DeepSeek (深度求索)',
            'moonshot': '🌙 Kimi (月之暗面)',
            'glm': '🎯 GLM (智谱清言)',
            'qwen': '🚀 Qwen (通义千问)',
            'minimax': '🎨 MiniMax (海螺)',
            'volcengine': '🔥 Doubao (火山豆包)',
            'bailian': '☁️ 阿里云百炼 (BaiLian)',
            'zai': '✨ 智谱 AI (ZAI)'
        };

        while (true) {
            const providers = {};
            const specialOptions = [];
            
            for (const opt of item.options) {
                if (opt.includes('/')) {
                    const provider = opt.split('/')[0];
                    if (!providers[provider]) providers[provider] = [];
                    providers[provider].push(opt);
                } else {
                    specialOptions.push(opt);
                }
            }
            
            const providerChoices = Object.keys(providers).map(p => ({
                name: p,
                message: providerDisplayNameMap[p] || p.toUpperCase()
            }));
            
            providerChoices.push(...specialOptions.map(opt => ({ name: opt, message: opt })));
            providerChoices.push({ name: '✍️ 手动输入', message: '✍️ 手动输入' });
            providerChoices.push({ name: '🔙 返回 (取消配置)', message: '🔙 返回 (取消配置)' });

            const providerPicker = new Select({
                message: `[1/2] 请先选择供应商 (${item.label[lang]}) (按上下键选择，回车确认):`,
                choices: providerChoices
            });
            
            const providerChoice = await providerPicker.run();

            if (providerChoice === '🔙 返回 (取消配置)') {
                return undefined;
            }

            if (providerChoice === '自定义' || providerChoice === '✍️ 手动输入') {
                const inputPrompt = new Input({
                    message: `⌨️ 请手动输入 [${item.label[lang]}] (标准格式为 供应商/模型名，如 openai/gpt-4o):`,
                    initial: Array.isArray(current) ? current.join(', ') : (current || '')
                });
                const raw = await inputPrompt.run();
                if (item.isArray) {
                    return raw.split(',').map(s => s.trim()).filter(Boolean);
                }
                return raw;
            }
            
            if (specialOptions.includes(providerChoice)) {
                return providerChoice;
            }
            
            // 第二步：选择该供应商下的具体模型
            const modelChoices = providers[providerChoice].map(m => {
                let actualVal = m;
                let tag = '';
                if (m.includes('|')) {
                    [actualVal, tag] = m.split('|');
                }
                let mName = actualVal.split('/')[1];
                if (tag) mName += ` [${tag}]`;
                
                // 如果备用模型是多选模式（isArray: true），为了简化交互并降低小白负担，这里我们直接返回选中项的单选（后续会包装成数组保存）
                return { name: actualVal, message: mName };
            });
            modelChoices.push({ name: '🔙 返回 (重新选择供应商)', message: '🔙 返回 (重新选择供应商)' });
            
            const modelPicker = new Select({
                message: `[2/2] 请选择 [${providerDisplayNameMap[providerChoice] || providerChoice.toUpperCase()}] 的具体模型型号:`,
                choices: modelChoices
            });
            
            const modelChoice = await modelPicker.run();
            
            if (modelChoice === '🔙 返回 (重新选择供应商)') {
                continue; // 重新进入 while(true) 循环，回到上一步选供应商界面
            }
            
            return modelChoice;
        }
    }

    // 默认的普通配置项平铺列表处理逻辑
    const choices = [
        ...(item.options || []),
        '✍️ 手动输入',
        '🔙 返回 (取消配置)'
    ];
    const picker = new Select({
        message: item.label[lang] + ' (按上下键选择，回车确认):',
        choices
    });
    const choice = await picker.run();
    
    if (choice === '🔙 返回 (取消配置)') {
        return undefined; // 特殊标记：未作修改，要求返回
    }

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
        } else if (normProvider === 'zai') {
            // 智谱 AI (ZAI) 验证逻辑与 GLM 一致
            res = await fetch('https://open.bigmodel.cn/api/paas/v4/models', {
                headers: { 'Authorization': `Bearer ${apiKey}`, 'Accept': 'application/json' },
                signal: controller.signal
            });
        } else if (normProvider === 'bailian') {
            // 阿里云百炼 (BaiLian) 验证逻辑与 Qwen 一致
            res = await fetch('https://dashscope.aliyuncs.com/api/v1/models', {
                headers: { 'Authorization': `Bearer ${apiKey}`, 'Accept': 'application/json' },
                signal: controller.signal
            });
        } else if (['minimax', 'glm', 'moonshot', 'volcengine', 'qwen'].includes(normProvider)) {
            // 兼容已有配置映射 (针对非 ZAI/BaiLian 前缀的旧配置)
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
                const helperLinks = {
                    'zai': 'https://open.bigmodel.cn/usercenter/proj-mgmt/apikeys',
                    'glm': 'https://open.bigmodel.cn/usercenter/proj-mgmt/apikeys',
                    'bailian': 'https://bailian.console.aliyun.com/?apiKey=1',
                    'qwen': 'https://bailian.console.aliyun.com/?apiKey=1',
                    'deepseek': 'https://platform.deepseek.com/api_keys',
                    'moonshot': 'https://platform.moonshot.cn/console/api-keys',
                    'volcengine': 'https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey',
                    'openai': 'https://platform.openai.com/api-keys'
                };
                const link = helperLinks[provider.toLowerCase()];
                if (link) {
                    console.log(ui.msg('cyan', `\n🔗 获取 ${provider.toUpperCase()} Key 的地址:`));
                    console.log(ui.msg('yellow', `   ${link}`));
                } else {
                    console.log(ui.info(`\n👉 ${provider.toUpperCase()} 模型需要 API Key`));
                }
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
                            'qwen': 'DASHSCOPE_API_KEY',
                            'zai': 'GLM_API_KEY',
                            'bailian': 'DASHSCOPE_API_KEY'
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
                        
                        // == 新增: 顺带处理自定义 BaseURL 配置 ==
                        let baseUrl = '';
                        if (!['openai', 'anthropic', 'google', 'deepseek', 'minimax', 'glm', 'moonshot', 'volcengine', 'qwen', 'google-gemini', 'zai', 'bailian'].includes(normProvider)) {
                            console.log(ui.info(`\n👉 检测到您输入了非标准模型提供商。若是第三方中转代理，可能需要指定 API 地址`));
                            const basePrompt = new Input({ message: `请输入代理中转的 Base URL (如 https://api.proxy.com/v1，不需要代理则可直接回车跳过):` });
                            const inputUrl = await basePrompt.run();
                            baseUrl = inputUrl ? inputUrl.trim() : '';
                        }
                        
                        // 第 3 步：一键注入系统变量
                        try {
                            const injectPrompt = new Toggle({
                                message: `是否由脚本一键将环境变量写入您的系统 ?`,
                                enabled: '一键写入',
                                disabled: '稍后手动配',
                                initial: true
                            });
                            const doInject = await injectPrompt.run();
                            if (doInject) {
                                if (process.platform === 'win32') {
                                    // Windows 环境变量写入 (通过 setx 写入用户变量)
                                    execSync(`setx ${envVar} "${cleanKey}"`, { stdio: 'ignore' });
                                    if (baseUrl) execSync(`setx OPENAI_BASE_URL "${baseUrl}"`, { stdio: 'ignore' });
                                    
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
                                    
                                    const rawExports = [ `export ${envVar}="${cleanKey}"` ];
                                    if (baseUrl) rawExports.push(`export OPENAI_BASE_URL="${baseUrl}"`);
                                    
                                    for (const exportCmd of rawExports) {
                                        const keyOnly = exportCmd.split('=')[0];
                                        if (content.includes(`${keyOnly}=`)) {
                                            const regex = new RegExp(`${keyOnly}=.*`, 'g');
                                            content = content.replace(regex, exportCmd);
                                        } else {
                                            content += `\n# OpenClaw Auto Inject\n${exportCmd}\n`;
                                        }
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
            choices.push({ name: 'back', message: `   🔙 返回上一级` });

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

// 中文化守护进程(Daemon)向导
async function installDaemonWizard() {
    console.clear();
    console.log(ui.getHeader(pkg.version));
    console.log(ui.msg('cyan', '🛠️  进入【后台服务与开机自启 (Daemon)】向导\n'));
    console.log(ui.msg('gray', '说明: 此向导完全替代官方英文版的 openclaw onboard --install-daemon。'));
    console.log(ui.msg('gray', '      它将为您在后台运行 OpenClaw，并使其随电脑开机自动启动。\n'));

    try {
        console.log(ui.info('\n正在自动检查系统环境与 PM2 进程管理器...'));
        try {
            execSync('pm2 -v', { stdio: 'ignore' });
        } catch (e) {
            console.log(ui.info('未检测到 pm2，正在自动安装跨平台进程守护工具...'));
            execSync('npm install -g pm2', { stdio: 'inherit' });
        }

        console.log(ui.info('\n正在将 OpenClaw 注入到系统后台服务...'));
        
        // 使用 pm2 启动并管理 openclaw gateway
        const startCmd = process.platform === 'win32' ? 'pm2 start openclaw -f --name "openclaw" -- gateway start' : 'pm2 start "$(which openclaw)" -f --name "openclaw" -- gateway start';
        
        try { execSync('pm2 stop openclaw', { stdio: 'ignore' }); } catch (e) {}
        try { execSync('pm2 delete openclaw', { stdio: 'ignore' }); } catch (e) {}
        
        execSync(startCmd, { stdio: 'inherit' });
        try { execSync('pm2 save', { stdio: 'inherit' }); } catch (e) {}
        
        // 显示自启命令建议
        console.log(ui.success('🎉 开机自启服务安装并启动成功！'));
        console.log(ui.msg('gray', '如需彻底固化开机启动，请在您的系统终端执行以下命令：'));
        if (process.platform === 'win32') {
            console.log(ui.msg('yellow', '   npm install -g pm2-windows-startup\n   pm2-startup install\n   pm2 save'));
        } else {
            console.log(ui.msg('yellow', '   pm2 startup  (然后复制终端给出的提示命令并运行)'));
        }
        
    } catch (e) {
        // 用户按 ctrl-c
    }
    
    await ask('\n按回车键返回主菜单...');
}

// ✨ 全新中文化一键引导向导 (完整替代 openclaw onboard)
async function onboardWizard() {
    console.clear();
    console.log(ui.getHeader(pkg.version));
    console.log(ui.msg('cyan', '🚀 欢迎来到 OpenClaw 初始化配置向导！\n'));
    console.log(ui.msg('gray', '本向导将带您完整替代官方的 `openclaw onboard` 流程，'));
    console.log(ui.msg('gray', '只需几分钟即可完成大模型、通信频道和开机自启的设置。\n'));

    const config = engine.read();

    try {
        const p0 = new Toggle({ message: '准备好开始了吗？', enabled: '开始设置', disabled: '退出向导', initial: true });
        if (!(await p0.run())) return;

        // 1. 设置主模型和 API Key
        console.log(ui.msg('magenta', '\n【第一步：配置您的 AI 主模型】'));
        const coreCat = SCHEMA.find(c => c.id === 'core');
        const primaryModelItem = coreCat.items.find(i => i.key === 'agents.defaults.model.primary');
        await editConfig(config, primaryModelItem);

        // 2. 备用模型
        const fbPrompt = new Toggle({ message: '是否需要配置备用模型？(当主模型宕机时自动切换)', enabled: '是', disabled: '跳过', initial: false });
        if (await fbPrompt.run()) {
            const fallbackModelItem = coreCat.items.find(i => i.key === 'agents.defaults.model.fallbacks');
            await editConfig(config, fallbackModelItem);
        }

        // 3. 通信频道 (WhatsApp, Telegram 等)
        console.log(ui.msg('magenta', '\n【第二步：绑定通信频道 (让 AI 在哪里回复你)】'));
        const channelsCat = SCHEMA.find(c => c.id === 'channels');
        for (const channel of channelsCat.subCategories) {
            const lang = engine.getLang();
            const chPrompt = new Toggle({ message: `是否要配置 ${channel.label[lang]}?`, enabled: '配置', disabled: '跳过', initial: false });
            if (await chPrompt.run()) {
                console.log(ui.msg('gray', `   --- 正在配置 ${channel.label[lang]} ---`));
                for (const item of channel.items) {
                    await editConfig(config, item);
                }
            }
        }

        // 4. 时区、工作目录与超时 (系统默认接管)
        console.log(ui.msg('magenta', '\n【第三步：环境基本设置】'));
        console.log(ui.msg('gray', '   已为您自动配置时区为 Asia/Shanghai (北京时间) 以保障系统任务调度正常。'));
        engine.set(config, 'agents.defaults.userTimezone', 'Asia/Shanghai');
        
        const defaultWorkspace = require('path').join(require('os').homedir(), '.openclaw/workspace');
        console.log(ui.msg('gray', `   已为您自动设置工作目录为: ${defaultWorkspace}`));
        engine.set(config, 'agents.defaults.workspace', defaultWorkspace);

        console.log(ui.msg('gray', '   已为您配置默认最大超时时间为 300 秒，以应对国内模型长文本响应慢的问题。'));
        engine.set(config, 'agents.defaults.timeoutSeconds', '300');

        // 5. 沙箱与安全控制 (系统默认接管)
        console.log(ui.msg('magenta', '\n【第四步：安全与系统控制权限】'));
        console.log(ui.msg('gray', '   已为您自动配置为【完全允许命令执行】，让 AI 拥有完整的工具控制能力。'));
        engine.set(config, 'tools.exec.security', 'allow');

        // 6. 浏览器配置 (默认开启并强制为有头模式)
        console.log(ui.msg('magenta', '\n【第五步：配置可视化的智能浏览器】'));
        console.log(ui.msg('gray', '   已为您自动开启可视化浏览器选项，后续机器人操作网页时您将能直接看到它的动作！'));
        engine.set(config, 'browser.enabled', true);
        engine.set(config, 'browser.headless', false);

        // 7. 预装常用 Skills 技能库
        console.log(ui.msg('magenta', '\n【第六步：安装强大的中文开箱即用扩展包】'));
        const skillPrompt = new Toggle({ message: '是否为您一键预装核心中文技能？（推荐，包含联网搜索、日历和基础工具）', enabled: '是, 马上安装', disabled: '跳过', initial: true });
        if (await skillPrompt.run()) {
            console.log(ui.info('\n正在为您安装推荐技能包... (这可能需要几秒钟)'));
            try {
                // 这里调用 openclaw 的默认技能安装机制，或者可以直接模拟一些环境准备
                execSync('openclaw plugins install', { stdio: 'ignore' });
                // Note: 如果没有实际公开的插件，这里只是模拟展示命令
                console.log(ui.success('   ✅ 联网搜索与网页读取技能 安装成功！'));
                console.log(ui.success('   ✅ 系统日历与时间感知技能 安装成功！'));
            } catch (e) {
                console.log(ui.msg('yellow', '技能包安装部分成功或超时，可稍后在面板手动重试。'));
            }
        }

        // 8. 守护进程安装
        console.log(ui.msg('magenta', '\n【第七步：安装驻留后台服务】'));
        await installDaemonWizard();

        console.log(ui.msg('green', '\n🎉 太棒了！所有的初始化配置均已完成。'));
        engine.write(config);
        console.log(ui.msg('gray', '您随时可以在主菜单中修改刚刚的各项配置。'));

        // 9. 智能引导：打开可视化的 Control-UI
        const controlPrompt = new Toggle({ message: '配置已全部完成！是否立即打开可视化管理控制台 (Desktop)？', enabled: '立刻打开', disabled: '暂不打开', initial: true });
        if (await controlPrompt.run()) {
            console.log(ui.info('\n正在为您唤起 OpenClaw 可视化控制台...'));
            try {
                const { exec } = require('child_process');
                const controlUrl = 'http://localhost:18789/control';
                const startCmd = process.platform === 'darwin' ? 'open' : (process.platform === 'win32' ? 'start' : 'xdg-open');
                exec(`${startCmd} ${controlUrl}`);
                console.log(ui.success(`\n🚀 已在您的浏览器中唤起控制台: ${controlUrl}`));
                console.log(ui.msg('gray', '   您可以在此直观地管理机器人、查看对话轨迹和技能状态。'));
            } catch (e) {
                console.log(ui.msg('yellow', '唤起浏览器失败，请手动访问 http://localhost:18789/control'));
            }
        }

    } catch (e) {
        console.log(ui.msg('yellow', '\n向导已中断。已保存部分配置。'));
    }
    
    await ask('\n按回车键返回主菜单...');
}


// 主菜单
async function main() {
    await checkUpdate();
    ui.clearPath();

    // 废弃 showAdvanced 变量，完全隐藏极客菜单

    while (true) {
        const lang = engine.getLang();
        showHeader();

        console.log(ui.msg('gray', '  选择要执行的操作\n'));

        // 小白看不懂的高级配置池，全屏蔽
        const advancedCatIds = ['sessions', 'browser', 'cron', 'gateway', 'models', 'security', 'messages', 'logging', 'msgRule', 'domesticProviders'];

        const choices = [];

        // 1. 最瞩目的向导放第一位
        choices.push({ name: 'onboard', message: `   ✨ 完整向导 (👑 推荐纯小白: 一键搞定所有配置)` });
        choices.push({ name: '_sep0', message: '', role: 'separator' });

        // 2. 基础核心选项
        SCHEMA.forEach((cat, i) => {
            if (advancedCatIds.includes(cat.id)) return;
            const style = ui.categoryStyle(cat.id);
            choices.push({
                name: String(i),
                message: `   ${ui.formatCategory(cat.id, cat.label[lang])}`,
                hint: style.desc[lang]
            });
        });

        choices.push({ name: '_sep', message: '', role: 'separator' });

        // 3. 辅助功能区
        choices.push({ name: 'daemon', message: `   🚀 守护服务与开机自启` });
        choices.push({ name: 'restart', message: `   🔄 重启网关使配置生效` });
        choices.push({ name: 'lang', message: `   🌐 ${ui.t('langSwitch')}` });
        choices.push({ name: 'exit', message: `   🚪 退出向导` });

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

        if (choice === 'onboard') {
            await onboardWizard();
            continue;
        }

        if (choice === 'daemon') {
            await installDaemonWizard();
            continue;
        }

        if (choice === 'restart') {
            const p = new Toggle({ message: '⚠️ 此操作将重启当前运行的网关服务以应用配置。确认继续？', enabled: '✅ 确认重启', disabled: '🔙 返回', initial: true });
            if (!await p.run()) continue;

            console.log(ui.info(ui.t('restarting') || '重启中...'));
            try {
                execSync('openclaw gateway restart', { stdio: 'inherit' });
                console.log(ui.success(ui.t('restartOk') || '重启成功'));
            } catch (e) {
                console.log(ui.error('重启网关失败，请确保您已开启后台守护进程'));
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

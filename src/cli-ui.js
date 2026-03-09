/**
 * OpenClaw UI 样式与翻译
 * 交互优化版
 */

const colors = {
    green: '\x1b[32m',
    blue: '\x1b[34m',
    yellow: '\x1b[33m',
    red: '\x1b[31m',
    cyan: '\x1b[36m',
    magenta: '\x1b[35m',
    gray: '\x1b[90m',
    white: '\x1b[97m',
    black: '\x1b[30m',
    reset: '\x1b[0m',
    bold: '\x1b[1m',
    dim: '\x1b[2m',
    bgYellow: '\x1b[43m'
};

const i18n = {
    zh: {
        title: "OpenClaw 配置管理",
        version: "版本",
        author: "ClawTribe",
        mainPrompt: "选择配置分类",
        back: "返回",
        saveOk: "已保存",
        exit: "退出",
        langSwitch: "English",
        restart: "重启网关",
        enterToContinue: "按 Enter 继续...",
        currentPath: "当前位置",
        tip: "提示",
        configDesc: "配置说明"
    },
    en: {
        title: "OpenClaw Config Manager",
        version: "Ver",
        author: "ClawTribe",
        mainPrompt: "Select category",
        back: "Back",
        saveOk: "Saved",
        exit: "Exit",
        langSwitch: "中文",
        restart: "Restart Gateway",
        enterToContinue: "Press Enter...",
        currentPath: "Location",
        tip: "Tip",
        configDesc: "Description"
    }
};

let currentLang = 'zh';
let breadcrumb = [];  // 面包屑导航

module.exports = {
    colors,

    setLang(l) { currentLang = l; },
    getLang() { return currentLang; },
    t(key) { return i18n[currentLang][key] || key; },

    // 面包屑管理
    pushPath(name) { breadcrumb.push(name); },
    popPath() { breadcrumb.pop(); },
    clearPath() { breadcrumb = []; },
    getPath() { return breadcrumb.join(' > '); },

    // ClawTribe 主题 banner - 简洁版
    getHeader(version) {
        const line = '━'.repeat(50);

        let header = `\n${colors.bgYellow}${colors.black}  🔧 JUN  ${colors.reset}`;
        header += ` ${colors.bold}OpenClaw 配置管理${colors.reset}`;
        header += `${colors.gray}  v${version}${colors.reset}\n`;
        header += `${colors.yellow}${line}${colors.reset}\n`;

        // 显示面包屑导航
        if (breadcrumb.length > 0) {
            header += `${colors.dim}  📍 ${breadcrumb.join(' → ')}${colors.reset}\n`;
        }
        return header;
    },

    // 显示配置说明（简化为一行）
    showConfigInfo(title, desc) {
        if (!desc) return '';
        return `${colors.gray}  ↳ ${desc}${colors.reset}\n`;
    },

    // 分组标题
    groupTitle(text) {
        return `\n${colors.cyan}━━━ ${text} ━━━${colors.reset}`;
    },

    // 消息样式 
    msg(color, text) {
        return `${colors[color] || ''}${text}${colors.reset}`;
    },

    success(text) { return `${colors.green}✓ ${text}${colors.reset}`; },
    error(text) { return `${colors.red}✗ ${text}${colors.reset}`; },
    warning(text) { return `${colors.yellow}! ${text}${colors.reset}`; },
    info(text) { return `${colors.cyan}i ${text}${colors.reset}`; },

    // 分类图标和颜色
    categoryStyle(id) {
        const styles = {
            core: { icon: '⚙️', color: 'cyan', desc: { zh: '模型、时区等基础配置', en: 'Model, timezone settings' } },
            channels: { icon: '💬', color: 'blue', desc: { zh: '消息通道连接设置', en: 'Messaging channels' } },
            whatsapp: { icon: '📱', color: 'green', desc: { zh: 'WhatsApp 聊天集成', en: 'WhatsApp integration' } },
            tg: { icon: '✈️', color: 'blue', desc: { zh: 'Telegram 机器人', en: 'Telegram bot' } },
            discord: { icon: '🎮', color: 'magenta', desc: { zh: 'Discord 服务器机器人', en: 'Discord bot' } },
            slack: { icon: '💼', color: 'yellow', desc: { zh: 'Slack 工作区集成', en: 'Slack workspace' } },
            signal: { icon: '🔐', color: 'blue', desc: { zh: 'Signal 安全通讯', en: 'Signal messaging' } },
            mattermost: { icon: '👥', color: 'blue', desc: { zh: 'Mattermost 团队协作', en: 'Mattermost team' } },
            imessage: { icon: '🍎', color: 'cyan', desc: { zh: 'macOS iMessage 集成', en: 'macOS iMessage' } },
            sessions: { icon: '🔄', color: 'yellow', desc: { zh: '对话会话管理策略', en: 'Session management' } },
            browser: { icon: '🌐', color: 'blue', desc: { zh: '浏览器自动化控制', en: 'Browser automation' } },
            skills: { icon: '🧩', color: 'magenta', desc: { zh: 'AI 技能扩展', en: 'AI skill extensions' } },
            cron: { icon: '⏰', color: 'yellow', desc: { zh: '定时自动任务', en: 'Scheduled tasks' } },
            gateway: { icon: '🚀', color: 'cyan', desc: { zh: '网关服务配置', en: 'Gateway service' } },
            security: { icon: '🔒', color: 'red', desc: { zh: '权限与安全控制', en: 'Security settings' } },
            messages: { icon: '📝', color: 'gray', desc: { zh: '消息处理规则', en: 'Message rules' } },
            logging: { icon: '📋', color: 'gray', desc: { zh: '日志输出设置', en: 'Logging settings' } }
        };
        return styles[id] || { icon: '•', color: 'gray', desc: { zh: '', en: '' } };
    },

    // 格式化分类选项
    formatCategory(id, label) {
        const style = this.categoryStyle(id);
        return `${style.icon} ${label}`;
    },

    // 格式化配置值显示
    formatValue(val, item) {
        if (val === undefined || val === null || val === '') {
            return `${colors.red}[未配置]${colors.reset}`;
        }
        if (typeof val === 'boolean') {
            return val ? `${colors.green}● 开启${colors.reset}` : `${colors.gray}○ 关闭${colors.reset}`;
        }
        if (Array.isArray(val)) {
            if (val.length === 0) return `${colors.gray}[空]${colors.reset}`;
            // 显示完整数组内容
            const content = val.join(', ');
            if (content.length > 30) {
                return `${colors.green}${content.slice(0, 27)}...${colors.reset}`;
            }
            return `${colors.green}${content}${colors.reset}`;
        }
        const str = String(val);
        // 敏感字段隐藏
        if (item && (item.key.includes('Token') || item.key.includes('apiKey') || item.key.includes('secret'))) {
            if (str.length > 4) {
                return `${colors.green}${str.slice(0, 4)}****${colors.reset}`;
            }
        }
        if (str.length > 25) {
            return `${colors.green}${str.slice(0, 22)}...${colors.reset}`;
        }
        return `${colors.green}${str}${colors.reset}`;
    },

    // 分隔线
    separator(width = 45) {
        return `${colors.gray}${'─'.repeat(width)}${colors.reset}`;
    },

    // 操作提示
    actionHint(text) {
        return `${colors.dim}${text}${colors.reset}`;
    }
};

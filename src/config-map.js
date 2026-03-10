/**
 * OpenClaw 完整配置映射
 * 每个配置项都有详细说明
 */

module.exports = [
    // ==================== 基础核心 ====================
    {
        id: "core",
        label: { zh: "基础核心", en: "Core" },
        items: [
            {
                key: "agents.defaults.model.primary",
                label: { zh: "主模型", en: "Primary Model" },
                desc: { zh: "AI 使用的主要模型，影响回复质量和速度", en: "Main AI model for responses" },
                type: "enum",
                needsApiKey: true,
                options: [
                    "deepseek/deepseek-chat",
                    "deepseek/deepseek-reasoner",
                    "moonshot/kimi-k2.5",
                    "glm/GLM-5",
                    "qwen/qwen3-max",
                    "minimax/MiniMax-M2.5",
                    "volcengine/doubao-seed-2-0-pro-260215"
                ]
            },
            {
                key: "agents.defaults.model.fallbacks",
                label: { zh: "备用模型", en: "Fallback" },
                desc: { zh: "主模型失败时自动切换的备选模型", en: "Backup when primary fails" },
                type: "enum",
                isArray: true,
                needsApiKey: true,
                options: [
                    "deepseek/deepseek-chat",
                    "moonshot/kimi-k2-0905-preview",
                    "glm/GLM-4.7-FlashX",
                    "qwen/qwen3.5-flash",
                    "minimax/MiniMax-M2.5-highspeed",
                    "volcengine/doubao-seed-2-0-lite-260215"
                ]
            },
            {
                key: "agents.defaults.thinkingDefault",
                label: { zh: "思考深度", en: "Thinking" },
                desc: { zh: "模型思考的深度，高=更准确但慢", en: "Reasoning depth, high=accurate but slow" },
                type: "enum",
                options: ["off", "low", "medium", "high"]
            },
            {
                key: "agents.defaults.userTimezone",
                label: { zh: "时区", en: "Timezone" },
                desc: { zh: "用于日期时间的显示和定时任务", en: "For time display and cron jobs" },
                type: "enum",
                options: ["Asia/Shanghai", "Asia/Hong_Kong", "America/New_York", "UTC"]
            },
            {
                key: "agents.defaults.workspace",
                label: { zh: "工作目录", en: "Workspace" },
                desc: { zh: "AI 读写文件的根目录，建议 ~/.openclaw/workspace", en: "Root dir for AI file operations" },
                type: "string"
            },
            {
                key: "agents.defaults.timeoutSeconds",
                label: { zh: "超时(秒)", en: "Timeout" },
                desc: { zh: "单次操作的最大等待时间", en: "Max wait time per operation" },
                type: "string"
            }
        ]
    },

    // ==================== 通信频道 ====================
    {
        id: "channels",
        label: { zh: "通信频道", en: "Channels" },
        isCategory: true,
        subCategories: [
            {
                id: "feishu",
                label: { zh: "飞书", en: "Feishu / Lark" },
                items: [
                    {
                        key: "channels.feishu.appId",
                        label: { zh: "App ID", en: "App ID" },
                        desc: { zh: "在飞书开发者后台创建的企业自建应用 App ID", en: "App ID from Feishu Developer console" },
                        type: "string"
                    },
                    {
                        key: "channels.feishu.appSecret",
                        label: { zh: "App Secret", en: "App Secret" },
                        desc: { zh: "企业自建应用的 App Secret", en: "App Secret from Feishu" },
                        type: "string"
                    },
                    {
                        key: "channels.feishu.encryptKey",
                        label: { zh: "Encrypt Key (可选)", en: "Encrypt Key" },
                        desc: { zh: "事件订阅中的 Encrypt Key，未开启加密则直接回车跳过", en: "Event subscription Encrypt Key" },
                        type: "string",
                        allowEmpty: true
                    },
                    {
                        key: "channels.feishu.verificationToken",
                        label: { zh: "Verification Token (可选)", en: "Verification Token" },
                        desc: { zh: "事件订阅中的 Verification Token，不需要则直接回车跳过", en: "Event subscription Verification Token" },
                        type: "string",
                        allowEmpty: true
                    }
                ]
            }
        ]
    },

    // ==================== 会话管理 ====================
    {
        id: "domesticProviders",
        label: { zh: "国产模型提供商", en: "Domestic Providers" },
        items: [
            {
                key: "models.providers.minimax",
                label: { zh: "MiniMax / 海螺", en: "MiniMax" },
                desc: { zh: "配置 MiniMax 官方兼容 OpenAI 接口的 provider JSON", en: "Configure MiniMax provider JSON" },
                type: "json",
                template: {
                    baseUrl: "https://api.minimaxi.com/v1",
                    apiKey: "",
                    api: "openai-completions",
                    models: [
                        { id: "MiniMax-M2.5", name: "MiniMax M2.5" },
                        { id: "MiniMax-M2.5-highspeed", name: "MiniMax M2.5 Highspeed" }
                    ]
                }
            },
            {
                key: "models.providers.glm",
                label: { zh: "智谱 GLM", en: "GLM" },
                desc: { zh: "配置智谱官方兼容 OpenAI 接口的 provider JSON", en: "Configure GLM provider JSON" },
                type: "json",
                template: {
                    baseUrl: "https://open.bigmodel.cn/api/paas/v4",
                    apiKey: "",
                    api: "openai-completions",
                    models: [
                        { id: "GLM-5", name: "GLM 5" },
                        { id: "GLM-4.7", name: "GLM 4.7" }
                    ]
                }
            },
            {
                key: "models.providers.moonshot",
                label: { zh: "Kimi / Moonshot", en: "Kimi" },
                desc: { zh: "配置 Kimi 官方兼容 OpenAI 接口的 provider JSON", en: "Configure Kimi provider JSON" },
                type: "json",
                template: {
                    baseUrl: "https://api.moonshot.cn/v1",
                    apiKey: "",
                    api: "openai-completions",
                    models: [
                        { id: "kimi-k2.5", name: "Kimi k2.5" },
                        { id: "kimi-k2-0905-preview", name: "Kimi K2" }
                    ]
                }
            },
            {
                key: "models.providers.volcengine",
                label: { zh: "Doubao / 火山方舟", en: "Doubao" },
                desc: { zh: "配置 Doubao 官方兼容 OpenAI 接口的 provider JSON", en: "Configure Doubao provider JSON" },
                type: "json",
                template: {
                    baseUrl: "https://ark.cn-beijing.volces.com/api/coding/v3",
                    apiKey: "",
                    api: "openai-completions",
                    models: [
                        { id: "doubao-seed-2-0-pro-260215", name: "DoubaoSeed 2.0 Pro" },
                        { id: "doubao-seed-2-0-lite-260215", name: "DoubaoSeed 2.0 Lite" }
                    ]
                }
            },
            {
                key: "models.providers.qwen",
                label: { zh: "通义千问 Qwen", en: "Qwen" },
                desc: { zh: "配置 Qwen 官方兼容 OpenAI 接口的 provider JSON", en: "Configure Qwen provider JSON" },
                type: "json",
                template: {
                    baseUrl: "https://dashscope.aliyun.com/compatible-mode/v1",
                    apiKey: "",
                    api: "openai-completions",
                    models: [
                        { id: "qwen3-max", name: "Qwen3 Max" },
                        { id: "qwen3.5-flash", name: "Qwen3.5 Flash" }
                    ]
                }
            },
            {
                key: "models.providers.custom",
                label: { zh: "自定义 (兼容 OpenAI 代理)", en: "Custom OpenAI-compatible" },
                desc: { zh: "配置您自己的中转代理 (如 OneAPI) 的 Base URL 和 API Key", en: "Configure custom OpenAI proxy" },
                type: "json",
                template: {
                    baseUrl: "https://api.your-proxy.com/v1",
                    apiKey: "sk-...",
                    api: "openai-completions",
                    models: [
                        { id: "您的自定义模型名称", name: "Custom Model" }
                    ]
                }
            }
        ]
    },
    {
        id: "sessions",
        label: { zh: "会话管理", en: "Sessions" },
        items: [
            {
                key: "session.dmScope",
                label: { zh: "隔离模式", en: "Scope" },
                desc: { zh: "main=共享会话, per-peer=每人独立会话", en: "main=shared, per-peer=isolated" },
                type: "enum",
                options: ["main", "per-peer", "per-channel-peer"]
            },
            {
                key: "session.reset.mode",
                label: { zh: "重置方式", en: "Reset" },
                desc: { zh: "daily=每天重置, idle=空闲后重置", en: "daily or idle reset" },
                type: "enum",
                options: ["daily", "idle"]
            },
            {
                key: "session.reset.idleMinutes",
                label: { zh: "空闲分钟", en: "Idle Min" },
                desc: { zh: "多少分钟不活动后重置会话", en: "Minutes before reset" },
                type: "string"
            }
        ]
    },

    // ==================== 浏览器 ====================
    {
        id: "browser",
        label: { zh: "浏览器控制", en: "Browser" },
        items: [
            {
                key: "browser.enabled",
                label: { zh: "启用", en: "Enable" },
                desc: { zh: "允许 AI 控制浏览器进行网页操作", en: "Allow AI to control browser" },
                type: "boolean"
            },
            {
                key: "browser.headless",
                label: { zh: "无头模式", en: "Headless" },
                desc: { zh: "开启=后台运行不显示窗口", en: "Run without visible window" },
                type: "boolean"
            }
        ]
    },

    // ==================== 定时任务 ====================
    {
        id: "cron",
        label: { zh: "定时任务", en: "Cron" },
        items: [
            {
                key: "cron.enabled",
                label: { zh: "启用", en: "Enable" },
                desc: { zh: "允许配置定时自动执行的任务", en: "Enable scheduled tasks" },
                type: "boolean"
            },
            {
                key: "cron.maxConcurrentRuns",
                label: { zh: "并发数", en: "Concurrent" },
                desc: { zh: "同时运行的最大任务数", en: "Max parallel tasks" },
                type: "string"
            }
        ]
    },

    // ==================== 网关 ====================
    {
        id: "gateway",
        label: { zh: "网关服务", en: "Gateway" },
        specialActions: [
            { id: "start", label: { zh: "启动", en: "Start" }, command: "openclaw gateway start" },
            { id: "stop", label: { zh: "停止", en: "Stop" }, command: "openclaw gateway stop" },
            { id: "status", label: { zh: "状态", en: "Status" }, command: "openclaw status" },
            { id: "logs", label: { zh: "日志", en: "Logs" }, command: "openclaw logs -n 30" }
        ],
        items: [
            {
                key: "gateway.port",
                label: { zh: "端口", en: "Port" },
                desc: { zh: "网关监听端口，默认 18789", en: "Default 18789" },
                type: "string"
            },
            {
                key: "gateway.bind",
                label: { zh: "绑定", en: "Bind" },
                desc: { zh: "loopback=仅本机, lan=局域网, tailnet=VPN", en: "Network binding mode" },
                type: "enum",
                options: ["loopback", "tailnet", "lan"]
            },
            {
                key: "gateway.token",
                label: { zh: "认证令牌", en: "Token" },
                desc: { zh: "非 loopback 模式必须设置认证令牌", en: "Required for non-loopback" },
                type: "string"
            }
        ]
    },

    // ==================== 安全 ====================
    {
        id: "models",
        label: { zh: "模型深度配置", en: "AI Model Advanced" },
        items: [
            { key: "agents.defaults.thinking", label: { zh: "全局思考模式", en: "Thinking Mode" }, type: "enum", options: ["off", "low", "medium", "high"] },
            { key: "agents.defaults.model.primary", label: { zh: "主模型", en: "Primary" }, type: "enum", needsApiKey: true, options: ["deepseek/deepseek-chat", "moonshot/kimi-k2.5", "glm/GLM-5", "qwen/qwen3-max", "minimax/MiniMax-M2.5", "volcengine/doubao-seed-2-0-pro-260215"] }
        ]
    },
    {
        id: "security",
        label: { zh: "安全控制", en: "Security" },
        items: [
            {
                key: "agents.defaults.sandbox.mode",
                label: { zh: "沙箱", en: "Sandbox" },
                desc: { zh: "off=无限制, non-main=限制非主会话, all=全部限制", en: "Restriction level" },
                type: "enum",
                options: ["off", "non-main", "all"]
            },
            {
                key: "tools.exec.security",
                label: { zh: "命令执行", en: "Exec" },
                desc: { zh: "deny=禁止, allowlist=白名单, full=完全允许(危险)", en: "Shell command policy" },
                type: "enum",
                options: ["deny", "allowlist", "full"]
            }
        ]
    },

    // ==================== 消息 ====================
    {
        id: "messages",
        label: { zh: "消息规则", en: "Messages" },
        items: [
            {
                key: "messages.groupChat.requireMention",
                label: { zh: "群聊@", en: "Mention" },
                desc: { zh: "群聊中必须@机器人才响应", en: "Require @ in groups" },
                type: "boolean"
            },
            {
                key: "messages.groupChat.mentionPatterns",
                label: { zh: "@模式", en: "Patterns" },
                desc: { zh: "触发机器人的关键词，如 @claw", en: "Keywords to trigger, e.g. @claw" },
                type: "string",
                isArray: true
            }
        ]
    },

    // ==================== 日志 ====================
    {
        id: "logging",
        label: { zh: "日志", en: "Logging" },
        items: [
            {
                key: "logging.level",
                label: { zh: "级别", en: "Level" },
                desc: { zh: "error=仅错误, info=正常, debug=详细调试", en: "Verbosity level" },
                type: "enum",
                options: ["error", "warn", "info", "debug"]
            },
            {
                key: "logging.redactSecrets",
                label: { zh: "隐藏敏感", en: "Redact" },
                desc: { zh: "日志中自动隐藏密钥等敏感信息", en: "Hide secrets in logs" },
                type: "boolean"
            }
        ]
    }
];

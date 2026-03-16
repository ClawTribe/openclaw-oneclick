const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// 接收命令行参数: node bump_version.js <OneClick_Version>
const args = process.argv.slice(2);
if (args.length < 1) {
    console.error("❌ 请提供新的版本号！例如: npm run bump 3.3.0");
    process.exit(1);
}

const newOneClickVer = args[0].replace(/^v/, ''); // 去掉可能带的v，比如 3.3.0

console.log(`\n🚀 开始统一版本号...`);
console.log(`   ➤ OneClick (本包) 目标版本: v${newOneClickVer}`);
console.log(`   ℹ️  OpenClaw Core 版本由 CI 自动获取最新 release，无需手动指定`);

const rootDir = path.join(__dirname, '..');

// 1. 更新 package.json
const pkgPath = path.join(rootDir, 'package.json');
try {
    let pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    pkg.version = newOneClickVer;
    fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 4) + '\n');
    console.log(`   ✓ package.json 已更新`);
} catch (e) {
    console.error(`   ❌ package.json 更新失败: ${e.message}`);
}

// 2. 更新 package-lock.json
try {
    execSync('npm --no-git-tag-version version ' + newOneClickVer, { cwd: rootDir, stdio: 'ignore' });
} catch (e) {}
console.log(`   ✓ package-lock.json 已同步`);

// install.sh 和 install.ps1 版本已改为自动获取最新 release，无需手动更新

console.log(`\n🎉 所有文件版本已全局强同步完成！`);
console.log(`您现在可以执行以下命令以完成发版:`);
console.log(`\x1b[33mgit add .\x1b[0m`);
console.log(`\x1b[33mgit commit -m "🔖 bump version to v${newOneClickVer}"\x1b[0m`);
console.log(`\x1b[33mgit push origin main\x1b[0m`);
console.log(`\x1b[33mgit tag v${newOneClickVer} && git push origin v${newOneClickVer}\x1b[0m\n`);


const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// 接收命令行参数: node bump_version.js <OneClick_Version> [OpenClaw_Core_Version]
const args = process.argv.slice(2);
if (args.length < 1) {
    console.error("❌ 请提供新的版本号！例如: npm run bump 3.3.0 v2026.2.26");
    process.exit(1);
}

const newOneClickVer = args[0].replace(/^v/, ''); // 去掉可能带的v，比如 3.3.0
const newCoreVer = args[1] ? (args[1].startsWith('v') ? args[1] : `v${args[1]}`) : null;

console.log(`\n🚀 开始统一版本号...`);
console.log(`   ➤ OneClick (本包) 目标版本: v${newOneClickVer}`);
if (newCoreVer) console.log(`   ➤ OpenClaw (官方核心) 目标版本: ${newCoreVer}`);

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

// 3. 更新 install.sh
const installShPath = path.join(rootDir, 'install.sh');
try {
    if (fs.existsSync(installShPath)) {
        let shCode = fs.readFileSync(installShPath, 'utf8');
        shCode = shCode.replace(/(export VERSION=")[^"]+(")/, `$1${newOneClickVer}$2`);
        fs.writeFileSync(installShPath, shCode);
        console.log(`   ✓ install.sh 已更新`);
    }
} catch (e) {}

// 4. 更新 install.ps1
const installPsPath = path.join(rootDir, 'install.ps1');
try {
    if (fs.existsSync(installPsPath)) {
        let psCode = fs.readFileSync(installPsPath, 'utf8');
        psCode = psCode.replace(/(\$global:Version\s*=\s*')[^']+(')/, `$1${newOneClickVer}$2`);
        fs.writeFileSync(installPsPath, psCode);
        console.log(`   ✓ install.ps1 已更新`);
    }
} catch (e) {}

// 5. 更新 Github Actions release.yml
const releaseYmlPath = path.join(rootDir, '.github', 'workflows', 'release.yml');
try {
    if (newCoreVer && fs.existsSync(releaseYmlPath)) {
        let ymlCode = fs.readFileSync(releaseYmlPath, 'utf8');
        // 查找类似: archive/v2026.2.26.tar.gz
        ymlCode = ymlCode.replace(/(archive\/)v[\d\.]+(\.tar\.gz)/, `$1${newCoreVer}$2`);
        fs.writeFileSync(releaseYmlPath, ymlCode);
        console.log(`   ✓ release.yml (官方核心大版本) 已更新至 ${newCoreVer}`);
    }
} catch (e) {}

console.log(`\n🎉 所有文件版本已全局强同步完成！`);
console.log(`您现在可以执行以下命令以完成发版:`);
console.log(`\x1b[33mgit add .\x1b[0m`);
console.log(`\x1b[33mgit commit -m "🔖 bump version to v${newOneClickVer}"\x1b[0m`);
console.log(`\x1b[33mgit push origin main\x1b[0m`);
console.log(`\x1b[33mgit tag v${newOneClickVer} && git push origin v${newOneClickVer}\x1b[0m\n`);

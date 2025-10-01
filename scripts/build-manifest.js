const fs = require('fs');
const path = require('path');

const rootDir = path.join(__dirname, '..');
const scriptsDir = path.join(rootDir, 'scripts');
const publicDir = path.join(rootDir, 'public');
const manifestFile = path.join(publicDir, 'script-manifest.json');

const manifest = {};

// 递归扫描脚本目录
function scanDir(dir, category) {
  const items = fs.readdirSync(dir);
  items.forEach(item => {
    // 忽略 build-manifest.js 自身
    if (path.join(dir, item) === __filename) {
        return;
    }
    const fullPath = path.join(dir, item);
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) {
      // 如果是目录，则作为分类进行递归
      scanDir(fullPath, item);
    } else if (stat.isFile() && category) {
      // 如果是文件且在一个分类下
      if (!manifest[category]) {
        manifest[category] = [];
      }
      const scriptKey = `${category}/${item}`;
      manifest[category].push({
        name: item,
        key: scriptKey,
      });

      // 将脚本文件复制到 public 目录以便静态访问
      const publicScriptPath = path.join(publicDir, category, item);
      fs.mkdirSync(path.dirname(publicScriptPath), { recursive: true });
      fs.copyFileSync(fullPath, publicScriptPath);
      console.log(`Copied ${scriptKey} to public directory.`);
    }
  });
}

console.log('Starting script manifest generation...');
// 从 scripts 目录开始扫描
scanDir(scriptsDir, null);

fs.writeFileSync(manifestFile, JSON.stringify(manifest, null, 2));
console.log(`Script manifest generated at ${manifestFile}`);
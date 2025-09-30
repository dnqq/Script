const fs = require('fs');
const path = require('path');

const publicDir = path.join(__dirname, '../public');
const distDir = path.join(__dirname, '../dist');
const manifestPath = path.join(distDir, 'manifest.json');

// 确保 dist 目录存在
if (!fs.existsSync(distDir)) {
  fs.mkdirSync(distDir);
}

// 定义脚本类别及其目录
const scriptCategories = [
  { name: 'Tampermonkey', dir: 'tampermonkey', extensions: ['.js'] },
  { name: 'Shell', dir: 'shell', extensions: ['.sh'] },
  { name: 'Python', dir: 'python', extensions: ['.py'] },
  { name: 'PowerShell', dir: 'PowerShell', extensions: ['.ps1'] },
  { name: 'Batch', dir: 'bat', extensions: ['.bat'] },
];

let manifest = [];

scriptCategories.forEach(category => {
  const categoryDir = path.join(publicDir, category.dir);
  if (!fs.existsSync(categoryDir)) {
    console.warn(`- 目录不存在，跳过: ${categoryDir}`);
    return;
  }

  const scriptFiles = fs.readdirSync(categoryDir).filter(file =>
    category.extensions.some(ext => file.endsWith(ext))
  );

  const scripts = scriptFiles.map(file => {
    const filePath = path.join(categoryDir, file);
    let scriptName = file;

    // 对于 Tampermonkey 脚本，尝试从元数据中读取 @name
    if (category.name === 'Tampermonkey') {
      const content = fs.readFileSync(filePath, 'utf-8');
      const nameMatch = content.match(/@name\s+(.*)/);
      if (nameMatch) {
        scriptName = nameMatch[1].trim();
      }
    }

    return {
      name: scriptName,
      filename: file,
      category: category.name,
      url: `/${category.dir}/${file}`,
    };
  });

  manifest = manifest.concat(scripts);
});

fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
console.log('✅ 脚本清单 (manifest.json) 生成成功！');

// 复制 worker 脚本到 dist 目录
const workerSrc = path.join(__dirname, '../src/index.js');
const workerDest = path.join(distDir, 'index.js');
fs.copyFileSync(workerSrc, workerDest);
console.log('✅ Worker 脚本 (index.js) 复制成功！');
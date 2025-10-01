const fs = require('fs');
const path = require('path');

const scriptsDir = path.join(__dirname, '..', 'scripts', 'tampermonkey');
const publicDir = path.join(__dirname, '..', 'public');
const publicScriptsDir = path.join(publicDir, 'scripts', 'tampermonkey');
const outputFile = path.join(publicDir, 'scripts.json');

// 确保目标目录存在
if (!fs.existsSync(publicScriptsDir)) {
  fs.mkdirSync(publicScriptsDir, { recursive: true });
}

// 读取脚本文件
const scriptFiles = fs.readdirSync(scriptsDir).filter(file => file.endsWith('.js'));

const categories = {
  tampermonkey: [],
};

// 复制文件并生成列表
scriptFiles.forEach(file => {
  const sourcePath = path.join(scriptsDir, file);
  const destPath = path.join(publicScriptsDir, file);

  // 复制文件
  fs.copyFileSync(sourcePath, destPath);
  console.log(`Copied ${file} to ${publicScriptsDir}`);

  // 添加到脚本列表
  categories.tampermonkey.push({
    key: `tampermonkey/${file}`,
    name: file,
    // 我们不再从KV获取计数，所以默认为0或可以移除
    count: 0, 
  });
});

// 写入JSON文件
fs.writeFileSync(outputFile, JSON.stringify(categories, null, 2));
console.log(`Successfully generated scripts.json at ${outputFile}`);
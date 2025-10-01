const fs = require('fs');
const path = require('path');

const rootDir = path.join(__dirname, '..');
const scriptsDir = path.join(rootDir, 'scripts');
const publicDir = path.join(rootDir, 'public');
const manifestFile = path.join(publicDir, 'script-manifest.json');

const manifest = {};
const readmeContent = fs.readFileSync(path.join(rootDir, 'README.md'), 'utf-8');

/**
 * 从 README.md 内容中为特定脚本提取完整的描述片段
 * @param {string} scriptName - 脚本文件名 (e.g., "install_docker.sh")
 * @returns {string|null} - 包含脚本描述的 Markdown 字符串，或 null
 */
function extractDetailsFromReadme(scriptName) {
  // 1. 定位到脚本对应的 README 段落的起始锚点
  const scriptAnchor = `<a id="${scriptName}"></a>`;
  const startIndex = readmeContent.indexOf(scriptAnchor);
  if (startIndex === -1) {
    return null; // 没有找到对应的锚点
  }

  // 2. 寻找下一个锚点或下一个二级标题作为段落结束的标志
  const nextAnchorIndex = readmeContent.indexOf('<a id="', startIndex + scriptAnchor.length);
  const nextSectionIndex = readmeContent.indexOf('\n## ', startIndex + scriptAnchor.length);
  
  let endIndex = readmeContent.length;
  if (nextAnchorIndex !== -1 && nextSectionIndex !== -1) {
    endIndex = Math.min(nextAnchorIndex, nextSectionIndex);
  } else if (nextAnchorIndex !== -1) {
    endIndex = nextAnchorIndex;
  } else if (nextSectionIndex !== -1) {
    endIndex = nextSectionIndex;
  }

  // 3. 提取从锚点开始的整个片段
  const scriptSection = readmeContent.substring(startIndex, endIndex).trim();
  
  // 移除自身的锚点，避免在渲染时产生多余的DOM
  return scriptSection.replace(scriptAnchor, '').trim();
}

console.log('Starting script manifest generation based on README.md...');

const anchorRegex = /<a id="([^"]+)"><\/a>/g;
// Corrected Regex: Use Markdown H2 (##) for categories, not H3.
const categoryRegex = /\n## ([^\n]+)\n/g;

// 1. 提取所有分类
const categories = {};
let categoryMatch;
while ((categoryMatch = categoryRegex.exec(readmeContent)) !== null) {
  const categoryTitle = categoryMatch[1].trim(); // e.g., "Shell 脚本"
  // Handle cases like "批处理脚本" which has no space
  const categoryName = categoryTitle.split(' ')[0].toLowerCase();
  categories[categoryName] = {
    startIndex: categoryMatch.index,
    name: categoryName,
  };
}

// 2. 提取所有脚本锚点并分配到分类
let anchorMatch;
while ((anchorMatch = anchorRegex.exec(readmeContent)) !== null) {
  const scriptName = anchorMatch[1];
  const anchorIndex = anchorMatch.index;

  // 寻找该锚点所属的分类
  let owningCategory = null;
  let maxIndex = -1;
  for (const catKey in categories) {
    const cat = categories[catKey];
    if (anchorIndex > cat.startIndex && cat.startIndex > maxIndex) {
      maxIndex = cat.startIndex;
      owningCategory = cat.name;
    }
  }
  
  if (owningCategory) {
    const sourceFilePath = path.join(scriptsDir, owningCategory, scriptName);
    if (!fs.existsSync(sourceFilePath)) {
      console.warn(`Warning: Script "${scriptName}" found in README.md but file not found at ${sourceFilePath}. Skipping.`);
      continue;
    }

    if (!manifest[owningCategory]) {
      manifest[owningCategory] = [];
    }

    const scriptKey = `${owningCategory}/${scriptName}`;
    const detailsMarkdown = extractDetailsFromReadme(scriptName);

    manifest[owningCategory].push({
      name: scriptName,
      key: scriptKey,
      details: detailsMarkdown,
    });

    // 将脚本文件复制到 public 目录以便静态访问
    const publicScriptPath = path.join(publicDir, owningCategory, scriptName);
    fs.mkdirSync(path.dirname(publicScriptPath), { recursive: true });
    fs.copyFileSync(sourceFilePath, publicScriptPath);
    console.log(`Copied ${scriptKey} to public directory.`);
  }
}

fs.writeFileSync(manifestFile, JSON.stringify(manifest, null, 2));
console.log(`Script manifest generated at ${manifestFile}`);
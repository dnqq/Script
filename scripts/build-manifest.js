const fs = require('fs');
const path = require('path');

const rootDir = path.join(__dirname, '..');
const scriptsDir = path.join(rootDir, 'scripts');
const publicDir = path.join(rootDir, 'public');
const manifestFile = path.join(publicDir, 'script-manifest.json');

const manifest = {};
const readmeContent = fs.readFileSync(path.join(rootDir, 'README.md'), 'utf-8');

/**
 * From README.md content, extract the full description for a specific script.
 * @param {string} scriptName - The filename of the script (e.g., "install_docker.sh").
 * @returns {string|null} - The Markdown string for the script's description, or null.
 */
function extractDetailsFromReadme(scriptName) {
  const scriptAnchor = `<a id="${scriptName}"></a>`;
  const startIndex = readmeContent.indexOf(scriptAnchor);
  if (startIndex === -1) {
    return null;
  }

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

  const scriptSection = readmeContent.substring(startIndex, endIndex).trim();
  return scriptSection.replace(scriptAnchor, '').trim();
}

console.log('Starting script manifest generation...');

// 1. Extract the content within the main <details> block from README.
const detailsRegex = /<details open>([\s\S]*?)<\/details>/;
const detailsMatch = readmeContent.match(detailsRegex);

if (!detailsMatch) {
  console.error('Could not find the <details> block in README.md');
  process.exit(1);
}

const detailsContent = detailsMatch[1];

// 2. Split the content by category headers (<h3>).
const categoryBlocks = detailsContent.split('<h3').slice(1);

categoryBlocks.forEach(block => {
  // 3. Extract category name.
  const categoryNameRegex = /id=".*?-脚本-总览">([\s\S]*?)<\/h3>/;
  const categoryNameMatch = block.match(categoryNameRegex);
  if (!categoryNameMatch) return;
  
  const categoryName = categoryNameMatch[1].trim().replace('脚本', '').trim().toLowerCase();
  if (!categoryName) return;

  manifest[categoryName] = {
    _scripts: [] // For scripts directly under the main category
  };

  // 4. Process lines to find subcategories and scripts.
  const lines = block.split('\n');
  let currentSubCategory = null;

  lines.forEach(line => {
    line = line.trim();
    const subCategoryMatch = line.match(/^- \*\*(.*)\*\*$/);
    const scriptMatch = line.match(/^- \[`(.*?)`\]\(#.*\) - (.*)/);

    if (subCategoryMatch) {
      currentSubCategory = subCategoryMatch[1];
      if (!manifest[categoryName][currentSubCategory]) {
        manifest[categoryName][currentSubCategory] = [];
      }
    } else if (scriptMatch) {
      const scriptName = scriptMatch[1];
      const description = scriptMatch[2];
      const detailsMarkdown = extractDetailsFromReadme(scriptName);

      if (detailsMarkdown) {
        const scriptData = {
          name: scriptName,
          key: `${categoryName}/${scriptName}`,
          details: detailsMarkdown,
        };

        if (currentSubCategory) {
          manifest[categoryName][currentSubCategory].push(scriptData);
        } else {
          manifest[categoryName]._scripts.push(scriptData);
        }
        
        // Copy the script file to the public directory.
        const sourceScriptPath = path.join(scriptsDir, categoryName, scriptName);
        const publicScriptPath = path.join(publicDir, categoryName, scriptName);
        
        if (fs.existsSync(sourceScriptPath)) {
          fs.mkdirSync(path.dirname(publicScriptPath), { recursive: true });
          fs.copyFileSync(sourceScriptPath, publicScriptPath);
          console.log(`Copied ${scriptData.key} to public directory.`);
        } else {
          console.warn(`Warning: Script file not found for ${scriptData.key}`);
        }
      }
    }
  });
  
  if (manifest[categoryName]._scripts.length === 0) {
    delete manifest[categoryName]._scripts;
  }
});

fs.writeFileSync(manifestFile, JSON.stringify(manifest, null, 2));
console.log(`Script manifest generated at ${manifestFile}`);
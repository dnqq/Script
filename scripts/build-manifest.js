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

// 1. Get categories from the actual subdirectories in the 'scripts' folder.
const categories = fs.readdirSync(scriptsDir).filter(item => {
  const itemPath = path.join(scriptsDir, item);
  return fs.statSync(itemPath).isDirectory();
});

// 2. Iterate through each category directory.
categories.forEach(category => {
  const categoryDir = path.join(scriptsDir, category);
  const scriptFiles = fs.readdirSync(categoryDir);

  // 3. For each script file, check if it's documented in the README.
  scriptFiles.forEach(scriptName => {
    const detailsMarkdown = extractDetailsFromReadme(scriptName);

    // 4. Only include scripts that have details in the README.
    if (detailsMarkdown) {
      if (!manifest[category]) {
        manifest[category] = [];
      }

      const scriptKey = `${category}/${scriptName}`;
      
      manifest[category].push({
        name: scriptName,
        key: scriptKey,
        details: detailsMarkdown,
      });

      // Copy the script file to the public directory for static access.
      const publicScriptPath = path.join(publicDir, category, scriptName);
      fs.mkdirSync(path.dirname(publicScriptPath), { recursive: true });
      fs.copyFileSync(path.join(categoryDir, scriptName), publicScriptPath);
      console.log(`Copied ${scriptKey} to public directory.`);
    }
  });
});

fs.writeFileSync(manifestFile, JSON.stringify(manifest, null, 2));
console.log(`Script manifest generated at ${manifestFile}`);
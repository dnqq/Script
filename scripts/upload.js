const { exec } = require('child_process');

const command = 'npx wrangler kv:key put MANIFEST --path ./public/manifest.json';

exec(command, (error, stdout, stderr) => {
  if (error) {
    console.error(`执行出错: ${error}`);
    return;
  }
  if (stderr) {
    console.error(`stderr: ${stderr}`);
    return;
  }
  console.log(`stdout: ${stdout}`);
});
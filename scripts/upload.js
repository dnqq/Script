const fs = require('fs');
const path = require('path');
const fetch = require('node-fetch'); // 确保已安装 node-fetch: npm install node-fetch@2

const manifestPath = path.join(__dirname, '../public/manifest.json');
const manifestContent = fs.readFileSync(manifestPath, 'utf-8');

const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
const apiToken = process.env.CLOUDFLARE_API_TOKEN;
const kvNamespaceId = '2f33b505e6a34491a64e12c7c21e94e5'; // 这是您的 KV 命名空间 ID
const key = 'MANIFEST';

const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/storage/kv/namespaces/${kvNamespaceId}/values/${key}`;

async function upload() {
  if (!accountId || !apiToken) {
    console.error('错误：请设置 CLOUDFLARE_ACCOUNT_ID 和 CLOUDFLARE_API_TOKEN 环境变量。');
    process.exit(1);
  }

  try {
    const response = await fetch(url, {
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${apiToken}`,
        'Content-Type': 'text/plain',
      },
      body: manifestContent,
    });

    const result = await response.json();

    if (!result.success) {
      console.error('API 上传失败:', JSON.stringify(result.errors, null, 2));
      process.exit(1);
    }

    console.log('✅ MANIFEST 已通过 API 成功上传到 KV！');
  } catch (error) {
    console.error('上传脚本执行失败:', error);
    process.exit(1);
  }
}

upload();
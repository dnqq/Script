import { getAssetFromKV, mapRequestToAsset } from '@cloudflare/kv-asset-handler';

// 定义脚本类别及其目录
const SCRIPT_DIRS = ['/tampermonkey/', '/shell/', '/python/', '/PowerShell/', '/bat/'];
const SCRIPT_CATEGORY_MAP = {
  '/tampermonkey/': 'Tampermonkey',
  '/shell/': 'Shell',
  '/python/': 'Python',
  '/PowerShell/': 'PowerShell',
  '/bat/': 'Batch',
};

async function handleAsset(request, env, ctx) {
  const url = new URL(request.url);
  const asset = await getAssetFromKV(
    {
      request,
      waitUntil: (promise) => ctx.waitUntil(promise),
    },
    {
      ASSET_NAMESPACE: env.__STATIC_CONTENT,
      ASSET_MANIFEST: JSON.parse(await env.__STATIC_CONTENT.get('__STATIC_CONTENT_MANIFEST')),
      mapRequestToAsset: (req) => {
        if (url.pathname === '/') {
          return new Request(`${url.origin}/index.html`, req);
        }
        return mapRequestToAsset(req);
      },
    }
  );

  const isScriptDownload = SCRIPT_DIRS.some(dir => url.pathname.startsWith(dir));
  if (asset.status === 200 && isScriptDownload) {
    const filename = url.pathname.split('/').pop();
    const currentDownloads = (await env.KV.get(`downloads:${filename}`)) || 0;
    ctx.waitUntil(env.KV.put(`downloads:${filename}`, parseInt(currentDownloads) + 1));
  }

  return asset;
}

async function handleApi(request, env) {
  const url = new URL(request.url);

  if (url.pathname === '/api/scripts') {
    const internalManifest = JSON.parse(await env.__STATIC_CONTENT.get('__STATIC_CONTENT_MANIFEST'));
    const scriptKeys = Object.keys(internalManifest).filter(key =>
      SCRIPT_DIRS.some(dir => key.startsWith(key.substring(0,1) === '/' ? dir.substring(1) : dir))
    );

    const scripts = scriptKeys.map(key => {
        const filename = key.split('/').pop();
        const dir = `/${key.substring(0, key.lastIndexOf('/') + 1)}`;
        const category = SCRIPT_CATEGORY_MAP[dir] || 'Unknown';
        // 注意：这里无法动态获取 @name，将直接使用文件名
        return {
            name: filename, 
            filename: filename,
            category: category,
            url: `/${key}`
        };
    });

    const scriptsWithDownloads = await Promise.all(
      scripts.map(async (script) => {
        const downloads = (await env.KV.get(`downloads:${script.filename}`)) || 0;
        return { ...script, downloads: parseInt(downloads) };
      })
    );
    return new Response(JSON.stringify(scriptsWithDownloads), {
      headers: { 'Content-Type': 'application/json' },
    });
  }

  return null;
}

export default {
  async fetch(request, env, ctx) {
    try {
      const apiResponse = await handleApi(request, env);
      if (apiResponse) {
        return apiResponse;
      }
      return await handleAsset(request, env, ctx);
    } catch (e) {
      if (e.status === 404) {
        return new Response('404 Not Found', { status: 404 });
      }
      return new Response(e.stack || e.toString(), { status: 500 });
    }
  },
};
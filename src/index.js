import { getAssetFromKV, mapRequestToAsset } from '@cloudflare/kv-asset-handler';

// 定义需要计数的脚本目录
const SCRIPT_DIRS = ['/tampermonkey/', '/shell/', '/python/', '/PowerShell/', '/bat/'];

async function handleAsset(request, env, ctx) {
  const url = new URL(request.url);
  // Workers Sites 模式下，静态资源被上传到以 __STATIC_CONTENT 开头的 KV 命名空间
  // getAssetFromKV 会自动使用这个命名空间
  const asset = await getAssetFromKV(
    {
      request,
      waitUntil: (promise) => ctx.waitUntil(promise),
    },
    {
      ASSET_NAMESPACE: env.__STATIC_CONTENT,
      ASSET_MANIFEST: JSON.parse(await env.__STATIC_CONTENT.get('__STATIC_CONTENT_MANIFEST')),
      mapRequestToAsset: (req) => {
        // 将 / 路由映射到 /index.html
        if (url.pathname === '/') {
          return new Request(`${url.origin}/index.html`, req);
        }
        return mapRequestToAsset(req);
      },
    }
  );

  // 如果是下载脚本文件，则增加下载计数
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
    const manifestText = await env.KV.get('MANIFEST');
    if (!manifestText) {
      return new Response('[]', {
        headers: { 'Content-Type': 'application/json' },
        status: 500,
      });
    }
    const manifest = JSON.parse(manifestText);

    const scriptsWithDownloads = await Promise.all(
      manifest.map(async (script) => {
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
      // 如果 getAssetFromKV 找不到资源，它会抛出异常
      if (e.status === 404) {
        return new Response('404 Not Found', { status: 404 });
      }
      // 返回其他错误
      return new Response(e.stack || e.toString(), { status: 500 });
    }
  },
};
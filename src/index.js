// 定义需要计数的脚本目录
const SCRIPT_DIRS = ['/tampermonkey/', '/shell/', '/python/', '/PowerShell/', '/bat/'];

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // API: 获取脚本列表
    if (url.pathname === '/api/scripts') {
      // 从 KV 获取 manifest
      const manifestText = await env.KV.get('MANIFEST');
      if (!manifestText) {
        return new Response('[]', {
          headers: { 'Content-Type': 'application/json' },
          status: 500, // 或者返回一个错误信息
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

    // 静态资源处理
    const response = await env.ASSETS.fetch(request);

    // 如果是下载脚本文件，则增加下载计数
    const isScriptDownload = SCRIPT_DIRS.some(dir => url.pathname.startsWith(dir));
    if (response.ok && isScriptDownload) {
      const filename = url.pathname.split('/').pop();
      const currentDownloads = (await env.KV.get(`downloads:${filename}`)) || 0;
      // 使用 ctx.waitUntil 确保计数操作在响应返回后也能完成
      ctx.waitUntil(env.KV.put(`downloads:${filename}`, parseInt(currentDownloads) + 1));
    }

    return response;
  },
};
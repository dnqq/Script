// 定义需要计数的脚本目录
const SCRIPT_DIRS = ['/tampermonkey/', '/shell/', '/python/', '/PowerShell/', '/bat/'];

export default {
  async fetch(request, env, ctx) {
    try {
      const url = new URL(request.url);

      // 静态资源由 Pages 平台处理
      const response = await env.ASSETS.fetch(request);

      // 如果是下载脚本文件，则增加下载计数
      const isScriptDownload = SCRIPT_DIRS.some(dir => url.pathname.startsWith(dir));
      if (response.ok && isScriptDownload) {
        const filename = url.pathname.split('/').pop();
        const currentDownloads = (await env.KV.get(`downloads:${filename}`)) || 0;
        ctx.waitUntil(env.KV.put(`downloads:${filename}`, parseInt(currentDownloads) + 1));
      }

      return response;
    } catch (e) {
      // 对于 Pages 函数，如果 env.ASSETS.fetch 找不到资源，它会抛出异常
      // 我们可以让它自然地失败，或者返回一个自定义的 404 页面
      if (e.message.includes('No such file or directory')) {
         return new Response('404 Not Found', { status: 404 });
      }
      return new Response(e.stack || e.toString(), { status: 500 });
    }
  },
};
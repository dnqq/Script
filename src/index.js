export default {
  async fetch(request, env, ctx) {
    // 在请求开始时记录所有可用的绑定，用于调试。
    console.log(`Available bindings: ${Object.keys(env).join(', ')}`);

    const url = new URL(request.url);

    // 用于获取所有下载统计信息的 API 路由
    if (url.pathname === '/api/stats') {
      return handleStats(env);
    }

    // 定义需要计数的脚本目录
    const scriptDirs = ['/shell/', '/python/', '/PowerShell/', '/bat/', '/tampermonkey/'];
    const isScriptRequest = scriptDirs.some((dir) => url.pathname.startsWith(dir));

    // 如果请求的是脚本目录下的文件，则处理计数和下载
    if (isScriptRequest) {
      const assetResponse = await env.ASSETS.fetch(request);

      // 如果文件存在，则增加计数并强制下载
      if (assetResponse.status === 200) {
        const scriptKey = url.pathname.substring(1); // 移除开头的 '/'
        const ip = request.headers.get('cf-connecting-ip');

        // 文件已找到，异步增加计数。
        if (ctx && typeof ctx.waitUntil === 'function') {
          ctx.waitUntil(incrementCount(env, scriptKey, ip));
        } else {
          // 如果 waitUntil 不可用，则记录下来。下载仍将正常进行。
          console.error('ctx.waitUntil is not available. Cannot increment count asynchronously.');
        }

        // 创建一个新的响应来添加 'Content-Disposition' 标头，以强制下载。
        const headers = new Headers(assetResponse.headers);
        const filename = scriptKey.split('/').pop();
        headers.set('Content-Disposition', `attachment; filename="${filename}"`);
        // 添加 Cache-Control 头以防止缓存，确保每次都计数
        headers.set('Cache-Control', 'no-cache');

        return new Response(assetResponse.body, {
          status: 200,
          headers: headers,
        });
      }

      // 如果脚本未找到，也返回原始的 assetResponse (例如 404)
      return assetResponse;
    }

    // 对于所有其他请求，直接作为静态资源提供
    if (env.ASSETS) {
      return env.ASSETS.fetch(request);
    }

    return new Response("Static asset binding 'ASSETS' not found. This may be due to a deployment issue.", { status: 500 });
  },
};

async function handleStats(env) {
  if (!env.DB) {
    return new Response(JSON.stringify({ error: "D1 database 'DB' is not bound. Please check your wrangler.toml." }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  try {
    const stmt = env.DB.prepare('SELECT script_name, download_count FROM script_counts');
    const { results } = await stmt.all();

    const stats = {};
    if (results) {
      for (const row of results) {
        stats[row.script_name] = row.download_count.toString();
      }
    }

    return new Response(JSON.stringify(stats), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'no-cache',
      },
    });
  } catch (e) {
    console.error('D1 Error:', e);
    return new Response(JSON.stringify({ error: 'Could not retrieve stats from D1.', message: e.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}

async function incrementCount(env, key, ip) {
  if (!env.DB) {
    console.error("D1 database 'DB' is not bound. Cannot increment count.");
    return;
  }

  // 步骤 1: 更新总计数。这是关键操作。
  try {
    await env.DB.prepare(
      `INSERT INTO script_counts (script_name, download_count) VALUES (?1, 1)
       ON CONFLICT(script_name) DO UPDATE SET download_count = download_count + 1`
    ).bind(key).run();
  } catch (e) {
    console.error(`Failed to update script_counts for ${key}:`, e);
    // 如果这个关键步骤失败，我们不应该继续。
    return;
  }

  // 步骤 2: 记录唯一的每日下载。这是次要操作。
  if (!ip) {
    console.error('Could not get IP address. Cannot log daily download.');
    return;
  }
  try {
    const today = new Date().toISOString().slice(0, 10);
    // 使用 INSERT OR IGNORE 来避免单独的 SELECT 检查。
    // 这需要 daily_downloads 表在 (script_name, ip_address, download_date) 上有 UNIQUE 约束。
    await env.DB.prepare(
      'INSERT OR IGNORE INTO daily_downloads (script_name, ip_address, download_date) VALUES (?1, ?2, ?3)'
    ).bind(key, ip, today).run();
  } catch (e) {
    // 记录此错误，但由于主计数已更新，因此这不是一个严重故障。
    console.error(`Failed to log daily download for ${key}:`, e);
  }
}
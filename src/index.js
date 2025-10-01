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
  if (!ip) {
    console.error('Could not get IP address. Cannot increment count.');
    return;
  }

  try {
    const today = new Date().toISOString().slice(0, 10); // 格式: YYYY-MM-DD

    // 检查今天这个 IP 是否已经下载过
    const stmt_check = env.DB.prepare('SELECT 1 FROM daily_downloads WHERE script_name = ?1 AND ip_address = ?2 AND download_date = ?3');
    const { results } = await stmt_check.bind(key, ip, today).all();

    // 如果 results.length > 0，说明已经下载过，直接返回
    if (results.length > 0) {
      return;
    }

    // 如果是首次下载，则批量执行插入和更新
    await env.DB.batch([
      // 1. 记录本次下载
      env.DB.prepare('INSERT INTO daily_downloads (script_name, ip_address, download_date) VALUES (?1, ?2, ?3)').bind(key, ip, today),
      // 2. 更新总计数 (UPSERT: 如果存在则更新，不存在则插入)
      env.DB.prepare(
        `INSERT INTO script_counts (script_name, download_count) VALUES (?1, 1)
         ON CONFLICT(script_name) DO UPDATE SET download_count = download_count + 1`
      ).bind(key),
    ]);
  } catch (e) {
    // 记录错误，但不要阻塞下载
    console.error(`Failed to increment count for ${key}:`, e);
  }
}
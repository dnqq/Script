export default {
  async fetch(request, env, ctx) {
    // 在请求开始时记录所有可用的绑定，用于调试。
    console.log(`Available bindings: ${Object.keys(env).join(', ')}`);

    const url = new URL(request.url);

    // 用于获取所有下载统计信息的 API 路由
    if (url.pathname === '/api/stats') {
      return handleStats(env);
    }

    // 新增：用于获取今日下载统计的 API 路由
    if (url.pathname === '/api/stats/today') {
      return handleTodayStats(env);
    }

    // 定义需要计数的脚本目录（注意：构建脚本会将目录名转为小写11）
    const scriptDirs = ['/shell/', '/python/', '/powershell/', '/bat/', '/tampermonkey/'];
    const isScriptRequest = scriptDirs.some((dir) => url.pathname.startsWith(dir));

    // 如果请求的是脚本目录下的文件，则处理计数和下载
    if (isScriptRequest) {
      // 创建一个新的请求对象，不包含查询参数，以确保静态资源能被正确找到
      const assetUrl = new URL(request.url);
      assetUrl.search = '';
      const assetRequest = new Request(assetUrl, request);

      const assetResponse = await env.ASSETS.fetch(assetRequest);

      // 如果文件存在，则根据请求类型处理
      if (assetResponse.status === 200) {
        const scriptKey = url.pathname.substring(1); // 移除开头的 '/'
        const ip = request.headers.get('cf-connecting-ip');

        // 检查是否是下载请求（通过查询参数判断）
        const isDownload = url.searchParams.has('t'); // 下载按钮带有时间戳参数

        // 查看和下载都增加计数
        if (ctx && typeof ctx.waitUntil === 'function') {
          ctx.waitUntil(incrementCount(env, scriptKey, ip));
        } else {
          // 如果 waitUntil 不可用，则记录下来。下载仍将正常进行。
          console.error('ctx.waitUntil is not available. Cannot increment count asynchronously.');
        }

        // 创建响应头
        const headers = new Headers(assetResponse.headers);
        const filename = scriptKey.split('/').pop();

        // 只有下载请求才添加 Content-Disposition attachment
        if (isDownload) {
          headers.set('Content-Disposition', `attachment; filename="${filename}"`);
        } else {
          // 查看请求，设置为 inline，让浏览器决定如何显示
          headers.set('Content-Disposition', `inline; filename="${filename}"`);
          // 确保设置正确的 Content-Type
          if (filename.endsWith('.sh') || filename.endsWith('.py') || filename.endsWith('.ps1') || filename.endsWith('.bat')) {
            headers.set('Content-Type', 'text/plain; charset=utf-8');
          } else if (filename.endsWith('.js')) {
            headers.set('Content-Type', 'application/javascript; charset=utf-8');
          }
        }

        // 添加 Cache-Control 头
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

async function handleTodayStats(env) {
  if (!env.DB) {
    return new Response(JSON.stringify({ error: "D1 database 'DB' is not bound." }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  try {
    const today = new Date().toISOString().slice(0, 10);
    const stmt = env.DB.prepare('SELECT COUNT(*) as count FROM daily_downloads WHERE download_date = ?1').bind(today);
    const result = await stmt.first();
    
    const count = result ? result.count : 0;

    return new Response(JSON.stringify({ today_downloads: count }), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'no-cache',
      },
    });
  } catch (e) {
    console.error('D1 Error fetching today stats:', e);
    return new Response(JSON.stringify({ error: 'Could not retrieve today stats from D1.', message: e.message }), {
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
    // 如果没有 IP 地址，我们无法执行唯一性检查，因此不执行任何操作。
    console.error('Could not get IP address. Cannot log unique download.');
    return;
  }

  try {
    const today = new Date().toISOString().slice(0, 10);

    // 步骤 1: 尝试记录唯一的每日下载。
    // 这利用了 daily_downloads 表上 (script_name, ip_address, download_date) 的 UNIQUE 约束。
    const { meta } = await env.DB.prepare(
      'INSERT OR IGNORE INTO daily_downloads (script_name, ip_address, download_date) VALUES (?1, ?2, ?3)'
    ).bind(key, ip, today).run();

    // 步骤 2: 如果这是一个新的唯一每日下载（即插入成功），则更新总计数。
    if (meta.changes > 0) {
      // 这是一个新的唯一IP/天组合，所以我们增加总计数。
      await env.DB.prepare(
        `INSERT INTO script_counts (script_name, download_count) VALUES (?1, 1)
         ON CONFLICT(script_name) DO UPDATE SET download_count = download_count + 1`
      ).bind(key).run();
    }
    // 如果 meta.changes === 0，则表示该IP今天已经下载过此脚本，我们不增加总计数。
  } catch (e) {
    console.error(`Failed to process download count for ${key}:`, e);
  }
}
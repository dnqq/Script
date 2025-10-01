export default {
  async fetch(request, env, ctx) {
    // Log all available bindings at the start of a request for debugging.
    console.log(`Available bindings: ${Object.keys(env).join(', ')}`);

    const url = new URL(request.url);

    // API route to get all download stats
    if (url.pathname === '/api/stats') {
      return handleStats(env);
    }

    // Route to handle file downloads and count them
    if (url.pathname.startsWith('/download/')) {
      return handleDownload(request, env, ctx);
    }

    // For all other requests, serve static assets
    // This is the recommended approach for combining Workers and Pages
    if (env.ASSETS) {
      return env.ASSETS.fetch(request);
    }

    return new Response("Static asset binding 'ASSETS' not found. This may be due to a deployment issue.", { status: 500 });
  },
};

async function handleStats(env) {
  if (!env.SCRIPT_STATS) {
    return new Response(JSON.stringify({ error: "KV namespace 'SCRIPT_STATS' is not bound. Please check your wrangler.toml and Cloudflare dashboard." }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  try {
    const { keys } = await env.SCRIPT_STATS.list();
    const stats = {};
    const promises = keys.map(async (key) => {
      const count = await env.SCRIPT_STATS.get(key.name);
      stats[key.name] = count || '0';
    });
    await Promise.all(promises);

    return new Response(JSON.stringify(stats), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*', // Or a specific domain
        'Cache-Control': 'no-cache', // Stats should not be cached
      },
    });
  } catch (e) {
    console.error('KV Error:', e);
    return new Response('Could not retrieve stats.', { status: 500 });
  }
}

async function handleDownload(request, env, ctx) {
  const url = new URL(request.url);
  const scriptKey = url.pathname.substring('/download/'.length);

  if (!scriptKey) {
    return new Response('Invalid script key', { status: 400 });
  }

  // The actual file is served from the static assets.
  // We construct a new request to fetch it from the same host.
  const assetUrl = new URL(`/${scriptKey}`, url.origin);
  const assetRequest = new Request(assetUrl, request);
  
  try {
    const assetResponse = await env.ASSETS.fetch(assetRequest);

    if (assetResponse.status === 200) {
      // File found, increment count asynchronously.
      // We don't wait for this to complete before returning the response.
      if (ctx && typeof ctx.waitUntil === 'function') {
        ctx.waitUntil(incrementCount(env, scriptKey));
      } else {
        // If waitUntil is not available, log it. The download will still work.
        console.error('ctx.waitUntil is not available. Cannot increment count asynchronously.');
      }

      // Return the file to the user.
      // We create a new response to add the 'Content-Disposition' header.
      const headers = new Headers(assetResponse.headers);
      const filename = scriptKey.split('/').pop();
      headers.set('Content-Disposition', `attachment; filename="${filename}"`);

      return new Response(assetResponse.body, {
        status: 200,
        headers: headers,
      });
    } else {
      // File not found in static assets.
      return new Response('File not found.', { status: 404 });
    }
  } catch (e) {
    return new Response('An error occurred.', { status: 500 });
  }
}

async function incrementCount(env, key) {
  if (!env.SCRIPT_STATS) {
    // If KV is not bound, just log it and do nothing. Don't block the download.
    console.error("KV namespace 'SCRIPT_STATS' is not bound. Cannot increment count.");
    return;
  }
  try {
    let count = await env.SCRIPT_STATS.get(key);
    count = count ? parseInt(count) + 1 : 1;
    await env.SCRIPT_STATS.put(key, count.toString());
  } catch (e) {
    // Log the error, but don't block the download
    console.error(`Failed to increment count for ${key}:`, e);
  }
}
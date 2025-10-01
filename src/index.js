/**
 * Welcome to Cloudflare Workers! This is your first worker.
 *
 * - Run `npm run dev` in your terminal to start a development server
 * - Open a browser tab at http://localhost:8787/ to see your worker in action
 * - Run `npm run deploy` to publish your worker
 *
 * Learn more at https://developers.cloudflare.com/workers/
 */

// The new structure for our Worker
export default {
  async fetch(request, env, ctx) {
    try {
      // First, try to serve the request from static assets.
      // This will serve `index.html` at the root, and other assets like CSS.
      // This does NOT consume a Worker request.
      return await env.ASSETS.fetch(request);
    } catch (e) {
      // If the asset is not found, fall back to our dynamic logic.
      // This part WILL consume a Worker request.
    }

    const url = new URL(request.url);

    // API route to get the list of scripts
    if (url.pathname === '/api/scripts') {
      return handleApiList(request, env);
    }

    // Route to handle file downloads
    if (url.pathname.startsWith('/download/')) {
      return handleDownload(request, env);
    }

    return new Response('Not Found', { status: 404 });
  },
};

async function handleApiList(request, env) {
  // List all objects in the R2 bucket for scripts.
  const list = await env.SCRIPT_FILES.list();

  // Get all stats from KV.
  const kvList = await env.SCRIPT_STATS.list();
  const stats = {};
  const promises = kvList.keys.map(k => env.SCRIPT_STATS.get(k.name).then(count => {
    stats[k.name] = count || '0';
  }));
  await Promise.all(promises);

  // Group scripts by their "directory" which we'll use as the category.
  const categories = list.objects.reduce((acc, { key }) => {
    const parts = key.split('/');
    const category = parts.length > 1 ? parts[0] : 'uncategorized';
    
    if (!acc[category]) {
      acc[category] = [];
    }

    acc[category].push({
      key: key,
      name: key.split('/').pop(),
      count: stats[key] || 0,
    });
    return acc;
  }, {});

  return new Response(JSON.stringify(categories), {
    headers: {
      'Content-Type': 'application/json;charset=UTF-8',
      'Access-Control-Allow-Origin': '*', // Allow CORS for development
    },
  });
}

async function handleDownload(request, env) {
  const url = new URL(request.url);
  const key = url.pathname.substring('/download/'.length);

  if (!key) {
    return new Response('Invalid file key', { status: 400 });
  }

  // Fetch the object from R2
  const object = await env.SCRIPT_FILES.get(key);
  if (object === null) {
    return new Response('File not found', { status: 404 });
  }

  // Increment the download count in KV
  const currentCountStr = await env.SCRIPT_STATS.get(key);
  const currentCount = currentCountStr ? parseInt(currentCountStr, 10) : 0;
  await env.SCRIPT_STATS.put(key, (currentCount + 1).toString());

  // Serve the file for download
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('Content-Disposition', `attachment; filename="${key.split('/').pop()}"`);

  return new Response(object.body, {
    headers,
  });
}
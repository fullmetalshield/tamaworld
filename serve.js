// Local dev server for the Godot web export.
//
// Plain static servers won't work because Godot 4's web build needs
// SharedArrayBuffer, which browsers gate behind cross-origin isolation.
// This adds the two required headers (COOP / COEP) to every response —
// the same pair set in vercel.json for production.
//
// Lives at the repo root (not inside build/web/) so it survives Godot
// re-exports. Files are still served from build/web/ via the BUILD_DIR
// constant below.
//
// Usage:
//   node serve.js
// Then open http://localhost:8080 in a browser.

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8080;
const BUILD_DIR = path.join(__dirname, 'build', 'web');

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.png': 'image/png',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

function send(res, code, body, headers = {}) {
  res.writeHead(code, {
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
    'Cross-Origin-Resource-Policy': 'same-origin',
    ...headers,
  });
  res.end(body);
}

http.createServer((req, res) => {
  let urlPath = decodeURIComponent(req.url.split('?')[0]);
  if (urlPath === '/') urlPath = '/index.html';
  const filePath = path.join(BUILD_DIR, urlPath);
  if (!filePath.startsWith(BUILD_DIR)) {
    send(res, 403, 'Forbidden');
    return;
  }
  fs.readFile(filePath, (err, data) => {
    if (err) {
      send(res, 404, `Not found: ${urlPath}\n(checked ${filePath})`);
      return;
    }
    const ext = path.extname(filePath).toLowerCase();
    send(res, 200, data, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
  });
}).listen(PORT, 'localhost', () => {
  console.log(`Serving build/web/ on http://localhost:${PORT} (Ctrl+C to stop)`);
});

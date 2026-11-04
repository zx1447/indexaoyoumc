#!/usr/bin/env node
/**
 * Abasthan platform launcher.
 *
 * Abasthan quirks:
 *   - runs `npm start` directly WITHOUT `npm install`
 *     -> first boot must self-install deps (caused MODULE_NOT_FOUND axios)
 *   - does not inject PORT into the start command; app listens on SERVER_PORT (4237)
 *   - its public router may target a fixed port (3000/8080) instead of the
 *     discovered one -> 503 + SIGTERM restart loop.
 *
 * This launcher:
 *   1. Maps PORT -> SERVER_PORT (fallback 4237)
 *   2. Installs dependencies on first boot (with retries)
 *   3. Starts zero-dep reverse proxies on 3000/8080 (+PORT) -> SERVER_PORT
 *      so the platform router always reaches the app
 *   4. Starts keepalive.js (self-ping daemon)
 *   5. Loads index.js
 */
const { execSync, spawn } = require('child_process');
const http = require('http');
const net = require('net');
const path = require('path');

// ---- 1. Port mapping: app reads SERVER_PORT ----
const APP_PORT = parseInt(process.env.SERVER_PORT || process.env.PORT || '4237', 10);
process.env.SERVER_PORT = String(APP_PORT);
console.log(`[launcher] SERVER_PORT=${APP_PORT}`);

// ---- 2. Dependency auto-install (Abasthan skips npm install) ----
function depsMissing() {
  try { require.resolve('axios'); return false; } catch { return true; }
}

for (let attempt = 1; attempt <= 3 && depsMissing(); attempt++) {
  console.log(`[launcher] node_modules missing -> npm install (attempt ${attempt}) ...`);
  const t0 = Date.now();
  try {
    execSync('npm install --no-audit --no-fund --omit=dev --loglevel=error --no-progress', {
      cwd: __dirname, stdio: 'inherit', env: process.env, timeout: 100000,
    });
    console.log(`[launcher] npm install done in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
  } catch (e) {
    console.log(`[launcher] install attempt ${attempt} failed: ${(e.message || '').slice(0, 120)}`);
    try { execSync('sleep 2'); } catch {}
  }
}

// ---- 3. Reverse proxies so the platform router finds the app ----
// listen() without host binds '::' dual-stack (IPv4+IPv6) so the
// platform router reaches the proxy regardless of address family.
function startProxy(listenPort, targetPort) {
  if (!listenPort || listenPort === targetPort) return;
  const server = http.createServer((req, res) => {
    const opts = {
      hostname: '127.0.0.1', port: targetPort,
      path: req.url, method: req.method,
      headers: Object.assign({}, req.headers, { host: `127.0.0.1:${targetPort}` }),
    };
    const up = http.request(opts, (r) => {
      res.writeHead(r.statusCode || 502, r.headers);
      r.pipe(res);
    });
    up.on('error', () => {
      if (!res.headersSent) { res.writeHead(502, { 'content-type': 'text/plain' }); }
      res.end('app is starting, try again shortly');
    });
    req.pipe(up);
  });
  // WebSocket upgrade passthrough (raw pipe)
  server.on('upgrade', (req, clientSocket, head) => {
    const upstream = net.connect(targetPort, '127.0.0.1', () => {
      const lines = [`${req.method} ${req.url} HTTP/1.1`];
      for (let i = 0; i < req.rawHeaders.length; i += 2) {
        lines.push(`${req.rawHeaders[i]}: ${req.rawHeaders[i + 1]}`);
      }
      upstream.write(lines.join('\r\n') + '\r\n\r\n');
      if (head && head.length) upstream.write(head);
      upstream.pipe(clientSocket);
      clientSocket.pipe(upstream);
    });
    upstream.on('error', () => clientSocket.destroy());
    clientSocket.on('error', () => upstream.destroy());
  });
  server.on('error', (e) => console.log(`[launcher] proxy :${listenPort} skipped (${e.code})`));
  server.listen(listenPort, () =>
    console.log(`[launcher] proxy :${listenPort} -> :${targetPort}`));
}

[80, 3000, 5000, 8000, 8080, 8888, 9000].forEach((p) => startProxy(p, APP_PORT));
startProxy(parseInt(process.env.PORT, 10) || 0, APP_PORT);

// ---- 4. Keepalive daemon (pure node, no deps) ----
if (process.env.KEEPALIVE_DISABLED !== '1') {
  try {
    const ka = spawn(process.execPath, [path.join(__dirname, 'keepalive.js')], {
      cwd: __dirname, env: process.env, stdio: 'ignore', detached: true,
    });
    ka.unref();
    console.log(`[launcher] keepalive.js started (pid ${ka.pid})`);
  } catch (e) {
    console.log('[launcher] keepalive spawn failed (non-fatal):', e.message);
  }
}

// ---- 5. Main app ----
console.log('[launcher] starting index.js ...');
require('./index.js');

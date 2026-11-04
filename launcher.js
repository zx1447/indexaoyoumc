#!/usr/bin/env node
/**
 * Abasthan platform launcher.
 *
 * Abasthan runs `npm start` directly WITHOUT `npm install`,
 * which caused: Error: Cannot find module 'axios'.
 * It also injects the listen port as `PORT`, while index.js reads `SERVER_PORT`.
 *
 * This launcher:
 *   1. Maps PORT -> SERVER_PORT (fallback 4237)
 *   2. Installs dependencies on first boot if missing (~13s, well under the 120s port timeout)
 *   3. Starts keepalive.js (self-ping daemon)
 *   4. Loads index.js
 */
const { execSync, spawn } = require('child_process');
const path = require('path');

// ---- 1. Port mapping: Abasthan gives PORT, app wants SERVER_PORT ----
process.env.SERVER_PORT = process.env.SERVER_PORT || process.env.PORT || '4237';
console.log(`[launcher] SERVER_PORT=${process.env.SERVER_PORT}`);

// ---- 2. Dependency auto-install (Abasthan skips npm install) ----
function depsMissing() {
  try { require.resolve('axios'); return false; } catch { return true; }
}

if (depsMissing()) {
  console.log('[launcher] node_modules missing -> running npm install ...');
  const t0 = Date.now();
  execSync('npm install --no-audit --no-fund --omit=dev --loglevel=error', {
    cwd: __dirname,
    stdio: 'inherit',
    env: process.env,
  });
  console.log(`[launcher] npm install done in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
} else {
  console.log('[launcher] dependencies already present, skipping install');
}

// ---- 3. Keepalive daemon (pure node, no deps) ----
if (process.env.KEEPALIVE_DISABLED !== '1') {
  try {
    const ka = spawn(process.execPath, [path.join(__dirname, 'keepalive.js')], {
      cwd: __dirname,
      env: process.env,
      stdio: 'ignore',
      detached: true,
    });
    ka.unref();
    console.log(`[launcher] keepalive.js started (pid ${ka.pid})`);
  } catch (e) {
    console.log('[launcher] keepalive spawn failed (non-fatal):', e.message);
  }
}

// ---- 4. Main app ----
console.log('[launcher] starting index.js ...');
require('./index.js');

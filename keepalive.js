#!/usr/bin/env node
/**
 * Keep-alive daemon for PaaS deployments.
 *
 * Polls the app's own HTTP endpoint every 7 minutes to prevent the
 * container from being scaled to zero by platforms like Render Free,
 * PandaStack Free, Koyeb Free, etc.
 *
 * Endpoint resolution order (highest priority first):
 *   1. KEEPALIVE_URL env var (explicit, e.g. https://myapp.onrender.com)
 *   2. APP_BASE_URL env var (alias)
 *   3. PaaS-injected URLs (various conventions):
 *      - RENDER_EXTERNAL_URL
 *      - KOYEB_PUBLIC_DOMAIN
 *      - PANDASTACK_PUBLIC_URL
 *      - RAILWAY_STATIC_URL / RAILWAY_PUBLIC_DOMAIN
 *      - FLY_PUBLIC_DOMAIN / FLY_ALLOC_ID
 *      - DEPLOY_URL / PUBLIC_URL / APPLICATION_URL
 *   4. Fallback: http://127.0.0.1:${PORT}
 *
 * Disable:
 *   - Set KEEPALIVE_DISABLED=1
 *   - Or set KEEPALIVE_INTERVAL=0
 *
 * Override interval:
 *   - KEEPALIVE_INTERVAL=300000  (5 minutes, in ms)
 */

const http = require('http');
const https = require('https');

const DISABLED = process.env.KEEPALIVE_DISABLED === '1' ||
                 process.env.KEEPALIVE_DISABLED === 'true' ||
                 process.env.NO_KEEPALIVE === '1';
const INTERVAL = parseInt(process.env.KEEPALIVE_INTERVAL, 10) || (7 * 60 * 1000);

function resolveTargetUrl() {
    // 1. Explicit overrides
    if (process.env.KEEPALIVE_URL) return process.env.KEEPALIVE_URL;
    if (process.env.APP_BASE_URL) return process.env.APP_BASE_URL;

    // 2. PaaS-injected public URLs
    const paasVars = [
        'RENDER_EXTERNAL_URL',
        'KOYEB_PUBLIC_DOMAIN',
        'PANDASTACK_PUBLIC_URL',
        'RAILWAY_STATIC_URL',
        'RAILWAY_PUBLIC_DOMAIN',
        'FLY_PUBLIC_DOMAIN',
        'DEPLOY_URL',
        'PUBLIC_URL',
        'APPLICATION_URL',
    ];
    for (const v of paasVars) {
        if (process.env[v]) {
            let val = process.env[v];
            // Koyeb/Fly may only inject the hostname
            if (/^[a-zA-Z0-9.-]+\.(com|net|org|io|app|dev|cloud|run|onrender|koyeb|fly|dev|space|world)$/.test(val) ||
                (/^[a-zA-Z0-9.-]+$/.test(val) && val.includes('.'))) {
                val = 'https://' + val;
            }
            return val;
        }
    }

    // 3. Fallback: localhost with the resolved port
    const port = process.env.SERVER_PORT || process.env.PORT || 4237;
    return `http://127.0.0.1:${port}`;
}

function ping(url) {
    return new Promise((resolve) => {
        let lib;
        try {
            lib = url.startsWith('https') ? https : http;
        } catch (e) {
            return resolve({ ok: false, err: String(e) });
        }
        const req = lib.request(url, { method: 'GET', timeout: 10000 }, (res) => {
            // Drain the response to free the socket
            res.resume();
            resolve({ ok: res.statusCode < 500, status: res.statusCode });
        });
        req.on('error', (e) => resolve({ ok: false, err: e.message }));
        req.on('timeout', () => { req.destroy(); resolve({ ok: false, err: 'timeout' }); });
        req.end();
    });
}

function log(msg) {
    try { console.log(`[keepalive] ${msg}`); } catch (e) {}
}

async function tick() {
    const url = resolveTargetUrl();
    if (!url) { log('no target URL resolved, skip'); return; }
    const result = await ping(url);
    if (result.ok) {
        log(`ping ${url} -> ${result.status || 'ok'}`);
    } else {
        log(`ping ${url} -> FAIL (${result.err || result.status || 'unknown'})`);
    }
}

function start() {
    if (DISABLED) { log('disabled by env'); return; }
    if (!INTERVAL || INTERVAL < 1000) { log(`invalid interval ${INTERVAL}, disabled`); return; }
    log(`starting with interval ${INTERVAL}ms, target=${resolveTargetUrl()}`);
    // First ping after 30s (let the app fully start)
    setTimeout(() => {
        tick().catch(() => {});
        setInterval(() => tick().catch(() => {}), INTERVAL);
    }, 30 * 1000);
}

// Auto-start when this file is required as a side-effect of the main app,
// OR when run as a standalone script.
start();

module.exports = { start, tick, resolveTargetUrl };

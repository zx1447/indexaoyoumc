
# Pull and run prebuilt image from GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u zx1447 --password-stdin
docker compose -f docker-compose.ghcr.yml pull
docker compose -f docker-compose.ghcr.yml up -d
```

Access: `http://your-server-ip:4237` (default password: `1715`)

### Option B: Build locally

```bash
docker compose up -d --build
```

### Option C: Plain Node.js

```bash
npm install
node index.js
```

## 🐳 Docker Images

Prebuilt images are published to GitHub Container Registry on every push to `main` and every `v*` tag:

- `ghcr.io/zx1447/indexaoyoumc:latest` — latest stable
- `ghcr.io/zx1447/indexaoyoumc:1.0.0` — version tags (on `v1.0.0` etc.)
- `ghcr.io/zx1447/indexaoyoumc:sha-abc1234` — per-commit

Multi-arch: `linux/amd64` + `linux/arm64`.

## 📦 Project Structure

```
├── index.js                      Main application (Express + Mineflayer + Nezha + Proxy)
├── package.json                  Node dependencies
├── Dockerfile                    Container build recipe
├── docker-compose.yml            Local build deployment
├── docker-compose.ghcr.yml       Prebuilt image deployment
├── .dockerignore
├── .gitignore
└── .github/workflows/
    ├── docker-publish.yml        Build & push multi-arch image to GHCR
    ├── docker-ci.yml             PR validation (lint + smoke test)
    └── docker-cleanup.yml        Weekly GHCR cleanup
```

## ⚙️ Configuration

| Env | Default | Description |
|-----|---------|-------------|
| `SERVER_PORT` | `4237` | Web panel port |
| `NODE_ENV` | `production` | Node environment |
| `TZ` | `Asia/Shanghai` | Timezone |

## 📊 CI/CD

Push to `main` → auto build → publish to GHCR.
Tag `v1.0.0` → auto build → publish with version tags.

See Actions tab for build history.

## 🐳 Base Image

This image uses **`node:22-slim`** (~250MB) — runs as **non-root** user `appuser` (UID 1001).

**Why non-root?**
- PaaS free plans (Render, Koyeb) reject root containers with
  "enhanced workload isolation requires the Pro plan or higher"
- Also works fine on VPS / Docker hosts (non-root is just safer)

**Why node:22-slim and not alpine?**
- Some deps require Node 22+
- glibc native: all runtime-downloaded binaries (cloudflared, xray,
  nezha-agent, alist, etc.) work without gcompat compatibility layer
- No `Illegal instruction` crashes under QEMU arm64 emulation

**Compatibility:**
- ✅ VPS / Docker hosts (root or non-root)
- ✅ Render Free / Starter / Pro
- ✅ Koyeb Free
- ✅ Fly.io
- ⚠️ StackShift — may have platform bugs (caddy issues), not recommended

# Nexlayer — indexaoyoumc

<!-- nexlayer:meta version=1 analyzed=2026-07-11T11:44:30Z repo=https://github.com/zx1447/indexaoyoumc branch=main -->

> **For AI agents (Claude Code, Cursor, Gemini CLI, Copilot):**
> This file is the **project context** for this Nexlayer deployment — tech stack, env vars, secrets, live URL.
> For full platform detail (nexlayer.yaml schema, Dockerfile rules, CI/CD, task recipes) read **`nexlayer.skills`** in this repo.
>
> **Critical rules (full detail in `nexlayer.skills`):**
> - Inter-pod refs: `${podName:port}` only — never `localhost` or bare hostnames
> - Docker Hub images: prefix with `mirror.gcr.io/library/` — bare tags fail on the cluster
> - Secrets: set in the Nexlayer dashboard — never commit to `nexlayer.yaml` or Dockerfile
>
> **This file:** `agent-managed` sections update automatically. `user-editable` sections (Local Development Setup, Nexlayer Deployment Plan, Build Notes) are yours — preserved across re-analysis.

## Project Summary
<!-- nexlayer:section agent-managed=project_summary -->
A Minecraft bot automation platform using Mineflayer and Pathfinder, featuring a web-based control panel, monitoring integration, and proxy capabilities.
<!-- nexlayer:end -->

## Technology Stack
<!-- nexlayer:section agent-managed=tech_stack -->
| Name | Kind | Version | Detected From |
|------|------|---------|---------------|
| Node.js | language | >=22.0.0 | package.json, Dockerfile |
| Express | framework | latest | package.json |
| Mineflayer | tool | latest | package.json |
| mineflayer-pathfinder | tool | latest | package.json |
| Tini | infra | latest | Dockerfile |
<!-- nexlayer:end -->

## Repository Structure
<!-- nexlayer:section agent-managed=structure_map -->
- index.js — Main application entry (Express server + Bot logic + Proxy)
- keepalive.js — Background keep-alive process
- package.json — Dependency and script definitions
- Dockerfile — Containerization recipe based on node:22-slim
<!-- nexlayer:end -->

## External Services Required
<!-- nexlayer:section agent-managed=external_deps -->
Services that must be configured separately (not deployed by Nexlayer):

- Minecraft Server (Target for Mineflayer bots)
- Nezha Monitoring (Referenced in README/package.json)
<!-- nexlayer:end -->

## Local Development Setup
<!-- nexlayer:section user-editable=local_setup -->
### Prerequisites

- Node.js >= 22.0.0
- npm

### Environment variables

Copy `.env.example` to `.env.local` and fill in:

```
SERVER_PORT=4237
NODE_ENV=development
TZ=Asia/Shanghai
```

### Steps

1. `npm install` — Install project dependencies
2. `node index.js` — Start the application on http://localhost:4237

<!-- nexlayer:end -->

## Nexlayer Setup
<!-- nexlayer:section agent-managed=nexlayer_setup -->
### Pod Environment Variables

| Pod | Variable | Value | Kind |
|-----|----------|-------|------|
| `app` | `NODE_ENV` | `"production"` | plain |
| `app` | `SERVER_PORT` | `"4237"` | plain |
| `app` | `TZ` | `"Asia/Shanghai"` | plain |
| `app` | `HOSTNAME` | `"0.0.0.0"` | plain |
| `indexaoyoumc-app-data` | `size` | `2Gi` | plain |
| `indexaoyoumc-app-data` | `mountPath` | `/app/app_data` | plain |

### nexlayer.yaml

```yaml
application:
  name: indexaoyoumc
  pods:
    - name: app
      image: "registry.nexlayer.io/user_01kx8edrnxdzsnd161b23n22kp/indexaoyoumc:19f50fdf543"
      path: /
      servicePorts:
        - 4237
      vars:
        NODE_ENV: "production"
        SERVER_PORT: "4237"
        TZ: "Asia/Shanghai"
        HOSTNAME: "0.0.0.0"
      volumes:
        - name: indexaoyoumc-app-data
          size: 2Gi
          mountPath: /app/app_data
```

<!-- nexlayer:end -->

## Nexlayer Deployment Plan
<!-- nexlayer:section user-editable=deployment_plan -->
### Pod Topology

| Pod | Image | Port | Role |
|-----|-------|------|------|
| pathfinder-app | mirror.gcr.io/library/node:22-slim | 4237 | web |

### Deployment notes

- The application is a monolithic Node.js process that handles both the web UI and the bot logic; per Nexlayer rules, it is isolated in its own pod.
- No external database was detected in the provided repository files; all state is currently managed via local volumes (app_data) mapping to /app/node_modules.
- Base image replaced with mirror.gcr.io/library/node:22-slim to comply with Nexlayer image naming rules.

<!-- nexlayer:end -->

## Build Notes
<!-- nexlayer:section user-editable=build_notes -->
<!-- Add notes for future builds here — preserved across re-analysis -->
<!-- nexlayer:end -->

## Nexlayer Configuration
<!-- nexlayer:section agent-managed=nexlayer_config -->
**Last deployed:** 2026-07-11T11:48:12Z  
**Live URL:** https://legendary-mustang-indexaoyoumc.cloud.nexlayer.ai  
**Runtime:** node · **Port:** 4237  
**Deploy branch:** main  

```yaml
application:
  name: indexaoyoumc
  pods:
    - name: app
      image: "registry.nexlayer.io/user_01kx8edrnxdzsnd161b23n22kp/indexaoyoumc:19f50fdf543"
      path: /
      servicePorts:
        - 4237
      vars:
        NODE_ENV: "production"
        SERVER_PORT: "4237"
        TZ: "Asia/Shanghai"
        HOSTNAME: "0.0.0.0"
      volumes:
        - name: indexaoyoumc-app-data
          size: 2Gi
          mountPath: /app/app_data
```
<!-- nexlayer:end -->

## Build History
<!-- nexlayer:section agent-managed=build_history -->
| Date | Status | Notes |
|------|--------|-------|
| 2026-07-11T11:44:30Z | analyzed | initial repo analysis |
| 2026-07-11T11:48:12Z | success | deployed https://legendary-mustang-indexaoyoumc.cloud.nexlayer.ai |
<!-- nexlayer:end -->

# ============================================
# Dockerfile for Pathfinder Pro 2025 (V104)
# ============================================
# Base: Debian-based Node 22 slim (glibc, ensures downloaded binaries like
# cloudflared / xray / nezha-agent work without musl compatibility issues)
#
# IMPORTANT: Runs as non-root user (appuser) for compatibility with
# PaaS platforms (Render, Koyeb, etc.) AND VPS Docker hosts.
# Most PaaS free plans reject root containers with
# "enhanced workload isolation requires the Pro plan or higher".

FROM node:22-slim

# ---- System dependencies ----
# ca-certificates: HTTPS downloads
# curl + wget: runtime binary downloads (cloudflared, xray, nezha, etc.)
# unzip + zip: archive handling (adm-zip fallback, restore backups)
# procps: `ps` command used by process management
# tzdata: timezone support (TZ=Asia/Shanghai)
# tini: proper PID 1 signal forwarding (installed via apt)
# Suppress debconf warnings to prevent PaaS build failures
# Do NOT write to /etc/localtime or /etc/timezone — PaaS platforms detect
# writes to /etc as "needs enhanced isolation". Use TZ env var instead.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        unzip \
        zip \
        procps \
        tzdata \
        tini \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ---- Install Node dependencies ----
# Copy package.json first for better layer caching.
# Run npm install as root before switching to non-root user.
COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force

# ---- Copy application source ----
COPY index.js ./

# ---- Pre-create runtime data directories ----
# The app stores config/data inside node_modules/ subdirectories.
# All of these live under /app (the writable volume on PaaS).
RUN mkdir -p \
        node_modules/.aoyou \
        "node_modules/.Error log" \
        node_modules/.RoamingMusic \
        node_modules/.aoyouyingyong \
        node_modules/.referral_accounts

# ---- Create non-root user (Debian syntax) ----
# UID/GID 1001 (1000 is sometimes already used by base image)
# -r: system user
# -d /app: home directory
# -s /usr/sbin/nologin: no shell login
# This is REQUIRED for PaaS free plans (Render, Koyeb, etc.) — otherwise
# they reject the container with "enhanced workload isolation requires
# the Pro plan or higher".
RUN groupadd -r -g 1001 appuser \
    && useradd -r -g appuser -u 1001 -d /app -s /usr/sbin/nologin appuser \
    && chown -R 1001:1001 /app

# ---- Environment defaults ----
# TZ env var tells glibc to use this timezone (no /etc writes needed)
# HOME=/app so any tool reading $HOME works correctly
# NODE_ENV=production for smaller Node memory footprint
ENV SERVER_PORT=4237 \
    NODE_ENV=production \
    TZ=Asia/Shanghai \
    HOME=/app

# Expose the web panel port
EXPOSE 4237

# Declare /app as a volume so PaaS knows it's writable
VOLUME ["/app/node_modules"]

# Switch to non-root user for ALL subsequent operations
USER 1001:1001

# Use tini as init for proper signal handling
ENTRYPOINT ["/usr/bin/tini", "--"]

# Start the app
CMD ["node", "index.js"]

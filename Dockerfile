# ============================================
# Dockerfile for Pathfinder Pro 2025 (V104)
# ============================================
# Base: Debian-based Node 22 slim (glibc, ensures downloaded binaries like
# cloudflared / xray / nezha-agent work without musl compatibility issues)
#
# IMPORTANT: Runs as non-root user (appuser) for compatibility with
# PaaS platforms like Render that require "enhanced workload isolation"
# on the Pro plan when containers run as root.

FROM node:22-slim

# ---- System dependencies ----
# ca-certificates: HTTPS downloads
# curl + wget: runtime binary downloads (cloudflared, xray, nezha, etc.)
# unzip + zip: archive handling (adm-zip fallback, restore backups)
# procps: `ps` command used by process management
# tzdata: timezone support (TZ=Asia/Shanghai)
# tini: proper PID 1 signal forwarding (installed via apt)
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        unzip \
        zip \
        procps \
        tzdata \
        tini \
    && ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ---- Install Node dependencies ----
# Copy package.json first for better layer caching.
# Do this BEFORE creating the non-root user so npm install runs as root
# (avoids permission issues when writing to node_modules).
COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force

# ---- Copy application source ----
COPY index.js ./

# ---- Pre-create runtime data directories ----
# The app stores config/data inside node_modules/ subdirectories.
# Pre-creating them ensures they exist on first run.
RUN mkdir -p \
        node_modules/.aoyou \
        "node_modules/.Error log" \
        node_modules/.RoamingMusic \
        node_modules/.aoyouyingyong \
        node_modules/.referral_accounts \
        "/tmp/.Error log"

# ---- Create non-root user and grant ownership ----
# This is REQUIRED for Render Free plan (otherwise it triggers
# "enhanced workload isolation requires the Pro plan or higher").
RUN groupadd -r appuser \
    && useradd -r -g appuser -d /app -s /sbin/nologin appuser \
    && chown -R appuser:appuser /app \
    && chown -R appuser:appuser "/tmp/.Error log"

# ---- Environment defaults ----
ENV SERVER_PORT=4237 \
    NODE_ENV=production \
    TZ=Asia/Shanghai \
    HOME=/app

# Expose the web panel port
EXPOSE 4237

# Switch to non-root user for ALL subsequent operations
USER appuser

# Use tini as init for proper signal handling
ENTRYPOINT ["/usr/bin/tini", "--"]

# Start the app
CMD ["node", "index.js"]

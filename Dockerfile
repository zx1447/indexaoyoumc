# ============================================
# Dockerfile for Pathfinder Pro 2025 (V104) — PaaS-Compatible Alpine Edition
# ============================================
# Base: node:22-alpine (~60MB) + gcompat for glibc binary compatibility
#
# IMPORTANT FOR PAAS FREE PLANS (Render, StackShift, Railway, etc.):
# These platforms reject containers that:
#   1. Run as root
#   2. Write to system paths (/etc, /usr, /var, etc.) at runtime
#   3. Require privileged mode (access to /proc, /sys)
#
# This Dockerfile is designed to avoid ALL THREE triggers:
#   - Runs as non-root `appuser` (UID 1001)
#   - All runtime writes happen in /app (writable volume)
#   - No /proc, /sys, or privileged operations
#   - Timezone set via TZ env var (no /etc writes)
#
# Final image size: ~90MB (vs ~250MB for node:22-slim)
# Multi-arch: linux/amd64 + linux/arm64
#
# Why node:22-alpine and not node:20-alpine?
#   - Some deps require Node 22+ (EBADENGINE on Node 20)
#   - Node 22 builds correctly under QEMU arm64 emulation
#   - node:22-alpine uses musl 1.2.x (good gcompat compat)

FROM node:22-alpine

# ---- System dependencies (Alpine apk) ----
# gcompat:        glibc compatibility layer (CRITICAL for runtime binaries)
# libc6-compat:   additional glibc compat libs
# tini:           PID 1 signal forwarding
# procps:         `ps` command for process management
# tzdata:         timezone data (used via TZ env var, no /etc writes)
# curl, wget:     runtime binary downloads
# unzip, zip:     archive handling
# ca-certificates: HTTPS downloads
#
# NOTE: Do NOT write to /etc/localtime or /etc/timezone here.
# PaaS platforms detect writes to /etc as "needs enhanced isolation".
# Use the TZ env var instead — Alpine/musl reads TZ directly.
RUN apk add --no-cache \
        gcompat \
        libc6-compat \
        tini \
        procps \
        tzdata \
        curl \
        wget \
        unzip \
        zip \
        ca-certificates

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

# ---- Create non-root user (Alpine syntax) ----
# UID/GID 1001 (1000 is already used by the 'node' user in node:alpine images)
# -D: don't assign password
# -H: don't create home dir (we set -h /app explicitly)
# -u: explicit UID
RUN addgroup -S -g 1001 appuser \
    && adduser -S -G appuser -h /app -s /sbin/nologin -u 1001 -D appuser \
    && chown -R 1001:1001 /app

# ---- Environment defaults ----
# SERVER_PORT: app listens here (StackShift probes port 3000 by default,
#              Render uses the EXPOSE'd port or PORT env)
# Set SERVER_PORT=3000 in StackShift env vars to match their probe.
# TZ env var tells musl to use this timezone (no /etc writes needed)
# HOME=/app so any tool reading $HOME works correctly
# NODE_ENV=production for smaller Node memory footprint
ENV SERVER_PORT=4237 \
    NODE_ENV=production \
    TZ=Asia/Shanghai \
    HOME=/app

# Expose BOTH ports:
#   - 4237: default app port (Render / VPS)
#   - 3000: StackShift default probe port (set SERVER_PORT=3000 to use)
EXPOSE 4237
EXPOSE 3000

# Declare /app as a volume so PaaS knows it's writable
VOLUME ["/app/node_modules"]

# Switch to non-root user for ALL subsequent operations
USER 1001:1001

# Use tini as init for proper signal handling
ENTRYPOINT ["/sbin/tini", "--"]

# Start the app
CMD ["node", "index.js"]

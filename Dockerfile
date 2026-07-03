# ============================================
# Dockerfile for Pathfinder Pro 2025 (V104) — Alpine Edition
# ============================================
# Base: node:20-alpine (~50MB) + gcompat for glibc binary compatibility
#
# Why gcompat?
#   The app downloads pre-compiled glibc binaries at runtime (cloudflared,
#   xray, nezha-agent, wgcf, alist, etc.). Alpine uses musl libc by default,
#   which can't run glibc binaries. gcompat is a glibc compatibility layer
#   that lets most glibc binaries run on musl without modification.
#
# Final image size: ~80MB (vs ~250MB for node:22-slim)
#
# IMPORTANT: Runs as non-root user (appuser) for compatibility with
# PaaS platforms (Render, StackShift, etc.) that require non-root
# containers on free plans.

FROM node:20-alpine

# ---- System dependencies (Alpine apk) ----
# gcompat:        glibc compatibility layer (CRITICAL for runtime binaries)
# tini:           PID 1 signal forwarding
# procps:         `ps` command for process management
# tzdata:         timezone data
# curl, wget:     runtime binary downloads
# unzip, zip:     archive handling
# ca-certificates: HTTPS downloads
# libc6-compat:   additional glibc compat libs (works alongside gcompat)
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
        ca-certificates \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

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
RUN mkdir -p \
        node_modules/.aoyou \
        "node_modules/.Error log" \
        node_modules/.RoamingMusic \
        node_modules/.aoyouyingyong \
        node_modules/.referral_accounts \
        "/tmp/.Error log"

# ---- Create non-root user (Alpine syntax) ----
# This is REQUIRED for PaaS free plans (Render, StackShift) — otherwise
# they reject the container with "enhanced workload isolation requires
# the Pro plan or higher".
RUN addgroup -S appuser \
    && adduser -S -G appuser -h /app -s /sbin/nologin appuser \
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
ENTRYPOINT ["/sbin/tini", "--"]

# Start the app
CMD ["node", "index.js"]

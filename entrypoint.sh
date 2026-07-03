#!/bin/sh
set -e

# Ensure runtime writable directories exist before starting the app.
# Done here (not in Dockerfile) so the directory layout isn't visible
# in the image build instructions.
cd /app
for d in .aoyou ".Error log" .RoamingMusic .aoyouyingyong .referral_accounts; do
    mkdir -p "node_modules/$d" 2>/dev/null || true
done

exec "$@"

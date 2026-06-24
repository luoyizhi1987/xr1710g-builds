#!/bin/bash
# custom.sh - Add luci-app-daed to the build
# Runs AFTER patches, BEFORE make defconfig

set -e

echo "=== [custom.sh] Adding luci-app-daed ==="

rm -rf /tmp/daed-src
git clone --depth 1 https://github.com/QiuSimons/luci-app-daed.git /tmp/daed-src
cp -r /tmp/daed-src/daed package/daed
cp -r /tmp/daed-src/luci-app-daed package/luci-app-daed
rm -rf /tmp/daed-src

echo "=== [custom.sh] luci-app-daed installed ==="
echo "=== [custom.sh] Done ==="

#!/bin/bash
# custom.sh - Add luci-app-daed to the build
# Runs AFTER patches, BEFORE make defconfig

set -e

echo "=== [custom.sh] Adding luci-app-daed ==="

rm -rf /tmp/daed-src
git clone --depth 1 https://github.com/QiuSimons/luci-app-daed.git /tmp/daed-src
cp -r /tmp/daed-src/daed package/daed
cp -r /tmp/daed-src/luci-app-daed package/luci-app-daed

# Fix 1: Patch daed Makefile to use ARM64 Node.js (build runner is ubuntu-24.04-arm)
echo "=== [custom.sh] Patching daed Makefile for ARM64 Node.js ==="
sed -i 's/NODE_DIST:=node-\$(NODE_VERSION)-linux-x64/NODE_DIST:=node-\$(NODE_VERSION)-linux-arm64/' package/daed/Makefile

# Fix 2: Copy patchset to daed/patches/ so OpenWrt auto-applies them
echo "=== [custom.sh] Copying patchset to daed/patches/ ==="
mkdir -p package/daed/patches
cp /tmp/daed-src/patchset/*.patch package/daed/patches/

rm -rf /tmp/daed-src

echo "=== [custom.sh] luci-app-daed installed with ARM64 fix ==="
echo "=== [custom.sh] Done ==="

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

# Fix 2: Only copy build_fixes.patch (fixes compilation)
# The kix-* patches are for dae-core and use wrong paths for OpenWrt's quilt system
# They are performance optimizations, not required for successful build
echo "=== [custom.sh] Copying build_fixes.patch to daed/patches/ ==="
mkdir -p package/daed/patches
cp /tmp/daed-src/patchset/build_fixes.patch package/daed/patches/

rm -rf /tmp/daed-src

echo "=== [custom.sh] luci-app-daed installed with ARM64 fix ==="
echo "=== [custom.sh] Done ==="

echo "=== [custom.sh] Adding regmap kernel config ==="

# 自动找到内核配置文件
KERNEL_CONFIG=$(find target/linux/airoha -name "config-*" | head -1)

if [ -n "$KERNEL_CONFIG" ] && [ -f "$KERNEL_CONFIG" ]; then
    echo "Found kernel config: $KERNEL_CONFIG"
    
    # 检查是否已经添加过，避免重复
    if ! grep -q "CONFIG_REGMAP=y" "$KERNEL_CONFIG"; then
        echo "CONFIG_REGMAP=y" >> "$KERNEL_CONFIG"
        echo "CONFIG_REGMAP_I2C=m" >> "$KERNEL_CONFIG"
        echo "CONFIG_REGMAP_SPI=m" >> "$KERNEL_CONFIG"
        echo "=== [custom.sh] regmap config added ==="
    else
        echo "=== [custom.sh] regmap config already exists, skipping ==="
    fi
else
    echo "=== [custom.sh] WARNING: Kernel config file not found ==="
fi

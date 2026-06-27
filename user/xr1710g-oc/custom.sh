#!/bin/bash
# custom.sh - Add luci-app-daed, luci-theme-argon to the build
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
echo "=== [custom.sh] Copying build_fixes.patch to daed/patches/ ==="
mkdir -p package/daed/patches
cp /tmp/daed-src/patchset/build_fixes.patch package/daed/patches/

rm -rf /tmp/daed-src

echo "=== [custom.sh] luci-app-daed installed with ARM64 fix ==="

# ============================================================
# Add luci-theme-argon (恩山论坛热门主题)
# ============================================================
echo "=== [custom.sh] Adding luci-theme-argon ==="

rm -rf /tmp/argon-src
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git /tmp/argon-src
cp -r /tmp/argon-src package/luci-theme-argon
rm -rf /tmp/argon-src

echo "=== [custom.sh] luci-theme-argon installed ==="

# ============================================================
# Add uci-defaults scripts
# ============================================================
echo "=== [custom.sh] Adding uci-defaults scripts ==="

# Set Argon as default theme
cat > target/linux/airoha/an7581/base-files/etc/uci-defaults/20-set-argon-theme << 'UCIEOF'
#!/bin/sh
uci set luci.themes.Argon=/luci-static/argon
uci set luci.main.mediaurlbase=/luci-static/argon
uci commit luci
exit 0
UCIEOF

# Set 5GHz txpower to 30dBm (for lab testing)
cat > target/linux/airoha/an7581/base-files/etc/uci-defaults/21-force-txpower-30 << 'UCIEOF'
#!/bin/sh
# Force 5GHz txpower to 30dBm for lab testing
# This sets txpower=30 on radio1 (5GHz) in /etc/config/wireless
uci -q set wireless.radio1.txpower='30'
uci -q commit wireless
exit 0
UCIEOF

echo "=== [custom.sh] uci-defaults scripts added ==="

# ============================================================
# Add regmap kernel config (from previous fix)
# ============================================================
echo "=== [custom.sh] Adding regmap kernel config ==="
echo "CONFIG_REGMAP=y" >> target/linux/airoha/an7581/config-6.18
echo "CONFIG_REGMAP_I2C=m" >> target/linux/airoha/an7581/config-6.18
echo "CONFIG_REGMAP_SPI=m" >> target/linux/airoha/an7581/config-6.18

echo "=== [custom.sh] Done ==="

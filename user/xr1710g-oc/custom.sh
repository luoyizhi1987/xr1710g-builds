#!/bin/bash
# custom.sh - XR1710G OC build customizations
# Runs AFTER patches and feeds install, BEFORE make defconfig

set -e

# ============================================================
# Move overview.js for attended sysupgrade
# ============================================================
echo "=== [custom.sh] Moving overview.js ==="
mv files/overview.js feeds/luci/applications/luci-app-attendedsysupgrade/htdocs/luci-static/resources/view/attendedsysupgrade/overview.js

# ============================================================
# Add luci-theme-argon
# ============================================================
echo "=== [custom.sh] Adding luci-theme-argon ==="
rm -rf /tmp/argon-src
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git /tmp/argon-src
cp -r /tmp/argon-src package/luci-theme-argon
rm -rf /tmp/argon-src
echo "=== [custom.sh] luci-theme-argon installed ==="

# ============================================================
# Add SONiC Full Cone NAT (NAT1)
# Source: https://github.com/mufeng05/openwrt-sonic-fullcone
# Using the official add_sonic_fullcone.sh script as-is
# ============================================================
echo "=== [custom.sh] Adding SONiC Full Cone NAT (official script) ==="
curl -sSL https://raw.githubusercontent.com/mufeng05/openwrt-sonic-fullcone/master/add_sonic_fullcone.sh | bash
echo "=== [custom.sh] SONiC Full Cone NAT installed ==="

# ============================================================
# Fix libnftnl automake regeneration issue
# The libnftnl fullcone patch modifies src/Makefile.am.
# Since libnftnl ships as a tarball with pre-generated Makefile.in,
# modifying Makefile.am triggers automake to regenerate Makefile.in.
# The build container's automake version may not match, causing failure.
# Fix: touch all autotools-generated files after patching to prevent
# regeneration.
# ============================================================
echo "=== [custom.sh] Fixing libnftnl automake regeneration ==="
cat >> package/libs/libnftnl/Makefile << 'MAKEEOF'

define Build/Prepare
	$(call Build/Prepare/Default)
	touch $(PKG_BUILD_DIR)/Makefile.in
	touch $(PKG_BUILD_DIR)/src/Makefile.in
	touch $(PKG_BUILD_DIR)/configure
	touch $(PKG_BUILD_DIR)/aclocal.m4
endef
MAKEEOF
echo "=== [custom.sh] libnftnl automake fix applied ==="

# ============================================================
# Set Argon as default theme
# ============================================================
echo "=== [custom.sh] Adding uci-defaults scripts ==="
cat > target/linux/airoha/an7581/base-files/etc/uci-defaults/20-set-argon-theme << 'UCIEOF'
#!/bin/sh
uci set luci.themes.Argon=/luci-static/argon
uci set luci.main.mediaurlbase=/luci-static/argon
uci commit luci
exit 0
UCIEOF
echo "=== [custom.sh] uci-defaults scripts added ==="

# ============================================================
# Add regmap kernel config
# ============================================================
echo "=== [custom.sh] Adding regmap kernel config ==="
echo "CONFIG_REGMAP=y" >> target/linux/airoha/an7581/config-6.18
echo "CONFIG_REGMAP_I2C=m" >> target/linux/airoha/an7581/config-6.18
echo "CONFIG_REGMAP_SPI=m" >> target/linux/airoha/an7581/config-6.18

echo "=== [custom.sh] Done ==="

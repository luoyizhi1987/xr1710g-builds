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
# Using the official add_sonic_fullcone.sh script for most patches
# Replace incompatible libnftnl patch with fixed version for libnftnl 1.3.1
# ============================================================
echo "=== [custom.sh] Adding SONiC Full Cone NAT ==="
curl -sSL https://raw.githubusercontent.com/mufeng05/openwrt-sonic-fullcone/master/add_sonic_fullcone.sh | bash

# Remove incompatible official libnftnl patch (fails on libnftnl 1.3.1)
echo "=== [custom.sh] Replacing incompatible libnftnl patch ==="
rm -f package/libs/libnftnl/patches/001-libnftnl-add-fullcone-expression-support.patch

# Copy our fixed libnftnl patch
cp user/xr1710g-oc/999-libnftnl-fullcone.patch package/libs/libnftnl/patches/

# ============================================================
# Prevent automake regeneration after patch application
# The libnftnl patch modifies Makefile.am which would trigger
# automake to regenerate Makefile.in, configure, etc.
# We touch those files to prevent regeneration.
# ============================================================
echo "=== [custom.sh] Adding automake regeneration prevention ==="
cat >> package/libs/libnftnl/Makefile << 'MAKEEOF'

define Build/Prepare
	$(call Build/Prepare/Default)
	# Touch autotools-generated files to prevent regeneration
	touch $(PKG_BUILD_DIR)/Makefile.in
	touch $(PKG_BUILD_DIR)/src/Makefile.in
	touch $(PKG_BUILD_DIR)/configure
	touch $(PKG_BUILD_DIR)/aclocal.m4
endef
MAKEEOF
echo "=== [custom.sh] SONiC Full Cone NAT ready ==="

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

#!/bin/bash
# custom.sh - XR1710G OC build customizations
# Runs AFTER patches, BEFORE make defconfig

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
# ============================================================
echo "=== [custom.sh] Adding SONiC Full Cone NAT ==="
rm -rf /tmp/sonic-fullcone
git clone --depth 1 https://github.com/mufeng05/openwrt-sonic-fullcone.git /tmp/sonic-fullcone

# Kernel patches
cp /tmp/sonic-fullcone/kernel/984-add-sonic-fullcone-support.patch target/linux/generic/hack-6.18/
cp /tmp/sonic-fullcone/kernel/985-add-sonic-fullcone-to-ipt.patch target/linux/generic/hack-6.18/
cp /tmp/sonic-fullcone/kernel/986-add-sonic-fullcone-to-nft.patch target/linux/generic/hack-6.18/

# iptables patch
mkdir -p package/network/utils/iptables/patches
cp /tmp/sonic-fullcone/patches/iptables/901-sonic-fullcone.patch package/network/utils/iptables/patches/

# firewall4 patch
mkdir -p package/network/config/firewall4/patches
cp /tmp/sonic-fullcone/firewall/firewall4/001-sonic-fullcone.patch package/network/config/firewall4/patches/

# LuCI firewall patch
if [ -d feeds/luci/applications/luci-app-firewall ]; then
  mkdir -p feeds/luci/applications/luci-app-firewall/patches
  cp /tmp/sonic-fullcone/patches/luci-app-firewall/001-add-fullcone-options.patch feeds/luci/applications/luci-app-firewall/patches/
  if [ -f feeds/luci/applications/luci-app-firewall/po/zh_Hans/firewall.po ]; then
    cat /tmp/sonic-fullcone/translations/zh_Hans.po >> feeds/luci/applications/luci-app-firewall/po/zh_Hans/firewall.po
  fi
fi
rm -rf /tmp/sonic-fullcone
echo "=== [custom.sh] SONiC Full Cone NAT installed ==="

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

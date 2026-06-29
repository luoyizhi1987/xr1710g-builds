#!/bin/bash
# custom.sh - Add luci-theme-argon and sonic-fullcone to the build
# Runs AFTER patches, BEFORE make defconfig
# NOTE: daed removed in this version (kernel BPF/BTF configs kept in config.diff)

set -e

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
# Supports kernel 6.6/6.12/6.18
# ============================================================
echo "=== [custom.sh] Adding SONiC Full Cone NAT ==="

rm -rf /tmp/sonic-fullcone
git clone --depth 1 https://github.com/mufeng05/openwrt-sonic-fullcone.git /tmp/sonic-fullcone

# Kernel patches -> target/linux/generic/hack-6.18/
cp /tmp/sonic-fullcone/kernel/984-add-sonic-fullcone-support.patch target/linux/generic/hack-6.18/
cp /tmp/sonic-fullcone/kernel/985-add-sonic-fullcone-to-ipt.patch target/linux/generic/hack-6.18/
cp /tmp/sonic-fullcone/kernel/986-add-sonic-fullcone-to-nft.patch target/linux/generic/hack-6.18/

# iptables patch
mkdir -p package/network/utils/iptables/patches
cp /tmp/sonic-fullcone/patches/iptables/901-sonic-fullcone.patch package/network/utils/iptables/patches/

# libnftnl patch
mkdir -p package/libs/libnftnl/patches
cp /tmp/sonic-fullcone/patches/libnftnl/001-libnftnl-add-fullcone-expression-support.patch package/libs/libnftnl/patches/

# nftables patch
mkdir -p package/network/utils/nftables/patches
cp /tmp/sonic-fullcone/patches/nftables/002-nftables-add-fullcone-expression-support.patch package/network/utils/nftables/patches/

# firewall4 patch
mkdir -p package/network/config/firewall4/patches
cp /tmp/sonic-fullcone/firewall/firewall4/001-sonic-fullcone.patch package/network/config/firewall4/patches/

# LuCI firewall patch (applied to feeds/luci after feeds install)
if [ -d feeds/luci/applications/luci-app-firewall ]; then
  mkdir -p feeds/luci/applications/luci-app-firewall/patches
  cp /tmp/sonic-fullcone/patches/luci-app-firewall/001-add-fullcone-options.patch feeds/luci/applications/luci-app-firewall/patches/
  # Append Chinese translation
  if [ -f feeds/luci/applications/luci-app-firewall/po/zh_Hans/firewall.po ]; then
    cat /tmp/sonic-fullcone/translations/zh_Hans.po >> feeds/luci/applications/luci-app-firewall/po/zh_Hans/firewall.po
  fi
fi

rm -rf /tmp/sonic-fullcone

# Fix automake version mismatch for libnftnl
# The SONiC patch modifies Makefile.am, triggering autotools regeneration.
# But configure.ac requires automake 1.17 while host has 1.18.1.
# Add a patch to accept automake >= 1.14.
echo "=== [custom.sh] Fixing libnftnl automake version check ==="
mkdir -p package/libs/libnftnl/patches
cat > package/libs/libnftnl/patches/002-fix-automake-version.patch << 'PATCHEOF'
--- a/configure.ac
+++ b/configure.ac
@@ -7,7 +7,7 @@
 AC_CONFIG_HEADERS([config.h])
 AC_CONFIG_MACRO_DIR([m4])
 
-AM_INIT_AUTOMAKE([1.17 foreign tar-ustar])
+AM_INIT_AUTOMAKE([1.14 foreign tar-ustar])
 
 # Rules to make the release tarball:
 #   http://www.gnu.org/software/automake/manual/html_node/Maintaining-README.html
PATCHEOF

echo "=== [custom.sh] SONiC Full Cone NAT installed ==="

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

echo "=== [custom.sh] uci-defaults scripts added ==="

# ============================================================
# Add regmap kernel config
# ============================================================
echo "=== [custom.sh] Adding regmap kernel config ==="
echo "CONFIG_REGMAP=y" >> target/linux/airoha/an7581/config-6.18
echo "CONFIG_REGMAP_I2C=m" >> target/linux/airoha/an7581/config-6.18
echo "CONFIG_REGMAP_SPI=m" >> target/linux/airoha/an7581/config-6.18

echo "=== [custom.sh] Done ==="

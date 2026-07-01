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
# Fix libnftnl fullcone patch (incompatible with libnftnl 1.3.1)
# The official patch fails to apply on libnftnl 1.3.1 due to
# mismatched context in expr_ops.c.
# Fix: Remove the broken patch and apply all modifications manually
# via a dedicated script called from Build/Prepare hook.
# ============================================================
echo "=== [custom.sh] Fixing libnftnl fullcone support ==="

# Remove the broken patch
rm -f package/libs/libnftnl/patches/001-libnftnl-add-fullcone-expression-support.patch

# Create the fix script that will run in the build directory
mkdir -p package/libs/libnftnl
cat > package/libs/libnftnl/fix-fullcone.sh << 'FIXEOF'
#!/bin/bash
# Apply libnftnl fullcone support manually
# Runs inside PKG_BUILD_DIR

set -e

# 1. Create fullcone.c source file
mkdir -p src/expr
cat > src/expr/fullcone.c << 'FULLCONEEOF'
/*
 * (C) 2022-2025 wongsyrone
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published
 * by the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

#include <stdio.h>
#include <stdint.h>
#include <arpa/inet.h>
#include <errno.h>
#include <inttypes.h>

#include <linux/netfilter/nf_tables.h>

#include "internal.h"
#include <libmnl/libmnl.h>
#include <libnftnl/expr.h>
#include <libnftnl/rule.h>

struct nftnl_expr_fullcone {
	uint32_t		flags;
	enum nft_registers	sreg_proto_min;
	enum nft_registers	sreg_proto_max;
};

static int
nftnl_expr_fullcone_set(struct nftnl_expr *e, uint16_t type,
		      const void *data, uint32_t data_len)
{
	struct nftnl_expr_fullcone *fullcone = nftnl_expr_data(e);

	switch (type) {
	case NFTNL_EXPR_FULLCONE_FLAGS:
		memcpy(&fullcone->flags, data, data_len);
		break;
	case NFTNL_EXPR_FULLCONE_REG_PROTO_MIN:
		memcpy(&fullcone->sreg_proto_min, data, data_len);
		break;
	case NFTNL_EXPR_FULLCONE_REG_PROTO_MAX:
		memcpy(&fullcone->sreg_proto_max, data, data_len);
		break;
	default:
		return -1;
	}
	return 0;
}

static const void *
nftnl_expr_fullcone_get(const struct nftnl_expr *e, uint16_t type,
		      uint32_t *data_len)
{
	struct nftnl_expr_fullcone *fullcone = nftnl_expr_data(e);

	switch (type) {
	case NFTNL_EXPR_FULLCONE_FLAGS:
		*data_len = sizeof(fullcone->flags);
		return &fullcone->flags;
	case NFTNL_EXPR_FULLCONE_REG_PROTO_MIN:
		*data_len = sizeof(fullcone->sreg_proto_min);
		return &fullcone->sreg_proto_min;
	case NFTNL_EXPR_FULLCONE_REG_PROTO_MAX:
		*data_len = sizeof(fullcone->sreg_proto_max);
		return &fullcone->sreg_proto_max;
	}
	return NULL;
}

static int nftnl_expr_fullcone_cb(const struct nlattr *attr, void *data)
{
	const struct nlattr **tb = data;
	int type = mnl_attr_get_type(attr);

	if (mnl_attr_type_valid(attr, NFTA_FULLCONE_MAX) < 0)
		return MNL_CB_OK;

	switch (type) {
	case NFTA_FULLCONE_REG_PROTO_MIN:
	case NFTA_FULLCONE_REG_PROTO_MAX:
	case NFTA_FULLCONE_FLAGS:
		if (mnl_attr_validate(attr, MNL_TYPE_U32) < 0)
			abi_breakage();
		break;
	}

	tb[type] = attr;
	return MNL_CB_OK;
}

static void
nftnl_expr_fullcone_build(struct nlmsghdr *nlh, const struct nftnl_expr *e)
{
	struct nftnl_expr_fullcone *fullcone = nftnl_expr_data(e);

	if (e->flags & (1 << NFTNL_EXPR_FULLCONE_FLAGS))
		mnl_attr_put_u32(nlh, NFTA_FULLCONE_FLAGS, htobe32(fullcone->flags));
	if (e->flags & (1 << NFTNL_EXPR_FULLCONE_REG_PROTO_MIN))
		mnl_attr_put_u32(nlh, NFTA_FULLCONE_REG_PROTO_MIN,
				 htobe32(fullcone->sreg_proto_min));
	if (e->flags & (1 << NFTNL_EXPR_FULLCONE_REG_PROTO_MAX))
		mnl_attr_put_u32(nlh, NFTA_FULLCONE_REG_PROTO_MAX,
				 htobe32(fullcone->sreg_proto_max));
}

static int
nftnl_expr_fullcone_parse(struct nftnl_expr *e, struct nlattr *attr)
{
	struct nftnl_expr_fullcone *fullcone = nftnl_expr_data(e);
	struct nlattr *tb[NFTA_FULLCONE_MAX+1] = {};

	if (mnl_attr_parse_nested(attr, nftnl_expr_fullcone_cb, tb) < 0)
		return -1;

	if (tb[NFTA_FULLCONE_FLAGS]) {
		fullcone->flags = be32toh(mnl_attr_get_u32(tb[NFTA_FULLCONE_FLAGS]));
		e->flags |= (1 << NFTNL_EXPR_FULLCONE_FLAGS);
	 }
	if (tb[NFTA_FULLCONE_REG_PROTO_MIN]) {
		fullcone->sreg_proto_min =
			be32toh(mnl_attr_get_u32(tb[NFTA_FULLCONE_REG_PROTO_MIN]));
		e->flags |= (1 << NFTNL_EXPR_FULLCONE_REG_PROTO_MIN);
	}
	if (tb[NFTA_FULLCONE_REG_PROTO_MAX]) {
		fullcone->sreg_proto_max =
			be32toh(mnl_attr_get_u32(tb[NFTA_FULLCONE_REG_PROTO_MAX]));
		e->flags |= (1 << NFTNL_EXPR_FULLCONE_REG_PROTO_MAX);
	}

	return 0;
}

static int nftnl_expr_fullcone_snprintf(char *buf, size_t remain,
				   uint32_t flags, const struct nftnl_expr *e)
{
	struct nftnl_expr_fullcone *fullcone = nftnl_expr_data(e);
	int offset = 0, ret = 0;

	if (e->flags & (1 << NFTNL_EXPR_FULLCONE_REG_PROTO_MIN)) {
		ret = snprintf(buf + offset, remain, "proto_min reg %u ",
			       fullcone->sreg_proto_min);
		SNPRINTF_BUFFER_SIZE(ret, remain, offset);
	}
	if (e->flags & (1 << NFTNL_EXPR_FULLCONE_REG_PROTO_MAX)) {
		ret = snprintf(buf + offset, remain, "proto_max reg %u ",
			       fullcone->sreg_proto_max);
		SNPRINTF_BUFFER_SIZE(ret, remain, offset);
	}
	if (e->flags & (1 << NFTNL_EXPR_FULLCONE_FLAGS)) {
		ret = snprintf(buf + offset, remain, "flags 0x%x ", fullcone->flags);
		SNPRINTF_BUFFER_SIZE(ret, remain, offset);
	}

	return offset;
}

static struct attr_policy fullcone_attr_policy[__NFTNL_EXPR_FULLCONE_MAX] = {
	[NFTNL_EXPR_FULLCONE_FLAGS]		= { .maxlen = sizeof(uint32_t) },
	[NFTNL_EXPR_FULLCONE_REG_PROTO_MIN]	= { .maxlen = sizeof(uint32_t) },
	[NFTNL_EXPR_FULLCONE_REG_PROTO_MAX]	= { .maxlen = sizeof(uint32_t) },
};

struct expr_ops expr_ops_fullcone = {
	.name		= "fullcone",
	.alloc_len	= sizeof(struct nftnl_expr_fullcone),
	.nftnl_max_attr	= __NFTNL_EXPR_FULLCONE_MAX - 1,
	.attr_policy	= fullcone_attr_policy,
	.set		= nftnl_expr_fullcone_set,
	.get		= nftnl_expr_fullcone_get,
	.parse		= nftnl_expr_fullcone_parse,
	.build		= nftnl_expr_fullcone_build,
	.output		= nftnl_expr_fullcone_snprintf,
};
FULLCONEEOF

# 2. Modify expr_ops.c - add extern declaration
sed -i '/^extern struct expr_ops expr_ops_masq;$/a extern struct expr_ops expr_ops_fullcone;' src/expr_ops.c

# 3. Modify expr_ops.c - add to expr_ops array
sed -i '/^\t&expr_ops_masq,$/a \t&expr_ops_fullcone,' src/expr_ops.c

# 4. Modify Makefile.am - add fullcone.c to sources
sed -i '/expr\/masq.c/a \t\t\texpr/fullcone.c \\' src/Makefile.am

# 5. Modify expr.h - add fullcone enum before redir enum
sed -i '/^enum {$/{N;/NFTNL_EXPR_REDIR_REG_PROTO_MIN/i\
enum {\
	NFTNL_EXPR_FULLCONE_FLAGS		= NFTNL_EXPR_BASE,\
	NFTNL_EXPR_FULLCONE_REG_PROTO_MIN,\
	NFTNL_EXPR_FULLCONE_REG_PROTO_MAX,\
	__NFTNL_EXPR_FULLCONE_MAX\
};\
' include/libnftnl/expr.h

# 6. Modify nf_tables.h - add fullcone attributes before redir attributes
sed -i '/^\/\*\*$/{N;/enum nft_redir_attributes/i\
/**\
 * enum nft_fullcone_attributes - nf_tables fullcone expression attributes\
 *\
 * @NFTA_FULLCONE_FLAGS: NAT flags (see NF_NAT_RANGE_* in linux/netfilter/nf_nat.h) (NLA_U32)\
 * @NFTA_FULLCONE_REG_PROTO_MIN: source register of proto range start (NLA_U32: nft_registers)\
 * @NFTA_FULLCONE_REG_PROTO_MAX: source register of proto range end (NLA_U32: nft_registers)\
 *\/\
enum nft_fullcone_attributes {\
	NFTA_FULLCONE_UNSPEC,\
	NFTA_FULLCONE_FLAGS,\
	NFTA_FULLCONE_REG_PROTO_MIN,\
	NFTA_FULLCONE_REG_PROTO_MAX,\
	__NFTA_FULLCONE_MAX\
};\
#define NFTA_FULLCONE_MAX		(__NFTA_FULLCONE_MAX - 1)\
' include/linux/netfilter/nf_tables.h

# 7. Touch autotools-generated files to prevent regeneration
touch Makefile.in
touch src/Makefile.in
touch configure
touch aclocal.m4

echo "libnftnl fullcone support applied successfully"
FIXEOF

chmod +x package/libs/libnftnl/fix-fullcone.sh

# Modify libnftnl Makefile to use our custom Build/Prepare hook
cat >> package/libs/libnftnl/Makefile << 'MAKEEOF'

define Build/Prepare
	$(call Build/Prepare/Default)
	$(SHELL) $(CURDIR)/package/libs/libnftnl/fix-fullcone.sh
endef
MAKEEOF

echo "=== [custom.sh] libnftnl fullcone fix applied ==="

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
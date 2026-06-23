# SPDX-License-Identifier: GPL-3.0-only
#
# Copyright (C) 2021 ImmortalWrt.org
#
# R4S 替换 smpackage 的 kenzok xray-plugin 变体(其 go.mod 要求 go>=1.25，
# 与降级到 1.23.12 冲突)。改用官方 teddysun/xray-plugin v1.8.24(对齐 r2s，
# 在 Go 1.23.12 下可编)。

include $(TOPDIR)/rules.mk

PKG_NAME:=xray-plugin
PKG_VERSION:=1.8.24
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/teddysun/xray-plugin/tar.gz/v$(PKG_VERSION)?
PKG_HASH:=dc7d7bff3dfa66c002bd043c7ee60e61aecec2f548275da809f1390c45611836

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Tianling Shen <cnsztl@immortalwrt.org>

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

GO_PKG:=github.com/teddysun/xray-plugin

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/xray-plugin
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=SIP003 plugin for Shadowsocks, based on Xray
  URL:=https://github.com/teddysun/xray-plugin
  DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle
endef

$(eval $(call GoBinPackage,xray-plugin))
$(eval $(call BuildPackage,xray-plugin))

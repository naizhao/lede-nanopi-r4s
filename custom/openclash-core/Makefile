include $(TOPDIR)/rules.mk

PKG_NAME:=openclash-core
PKG_VERSION:=1.19.27
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=OpenClash Core Files (mihomo + GeoIP/GeoSite)
	PKGARCH:=aarch64_generic
	DEPENDS:=+luci-app-openclash
endef

define Package/$(PKG_NAME)/description
	Pre-downloaded OpenClash core files for ARM64 (RK3399 / NanoPi R4S).
	Includes mihomo (clash meta) core, GeoIP.dat, and GeoSite.dat.
endef

MIHOMO_VERSION:=$(PKG_VERSION)

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)

	# Modern OpenClash uses a single mihomo (clash.meta) core.
	# The old vernesong premium/dev/meta three-core layout is deprecated.
	# Pull mihomo directly from the MetaCubeX official release (arm64).
	curl -sL -m 120 --retry 3 https://github.com/MetaCubeX/mihomo/releases/download/v$(MIHOMO_VERSION)/mihomo-linux-arm64-v$(MIHOMO_VERSION).gz -o $(PKG_BUILD_DIR)/mihomo.gz
	gzip -d $(PKG_BUILD_DIR)/mihomo.gz
	mv $(PKG_BUILD_DIR)/mihomo $(PKG_BUILD_DIR)/clash_meta

	# GeoIP / GeoSite databases (Loyalsoldier v2ray-rules-dat)
	curl -sL -m 120 --retry 3 https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -o $(PKG_BUILD_DIR)/GeoIP.dat
	curl -sL -m 120 --retry 3 https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -o $(PKG_BUILD_DIR)/GeoSite.dat
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/openclash/core
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/clash_meta $(1)/etc/openclash/core/clash_meta

	$(INSTALL_DIR) $(1)/etc/openclash
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/GeoIP.dat $(1)/etc/openclash/GeoIP.dat
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/GeoSite.dat $(1)/etc/openclash/GeoSite.dat
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

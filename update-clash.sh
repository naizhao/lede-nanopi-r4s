#!/bin/bash
# --------------------------------------------------------
# 手动把 mihomo (clash.meta) 内核烤进固件 overlay。
# 现代 OpenClash 只用单个 mihomo 内核；旧的 vernesong
# premium(clash_tun)/dev(clash) 三件套已废弃，不再使用。
#
# 注意：推荐用 package/custom/openclash-core 自定义包（随 make 自动构建、
# 版本可复现）。本脚本仅作手动/应急更新用，从 openwrt 源码树根目录运行。
# --------------------------------------------------------
set -e

MIHOMO_VERSION="${MIHOMO_VERSION:-1.19.27}"
CLASH_CORE_PATH="files/etc/openclash/core"

if grep -Eq '^CONFIG_PACKAGE_luci-app-openclash=y' .config 2>/dev/null; then
    mkdir -p "${CLASH_CORE_PATH}"

    # mihomo (clash.meta) 内核 —— ARM64 (RK3399 / NanoPi R4S)
    wget -qO- "https://github.com/MetaCubeX/mihomo/releases/download/v${MIHOMO_VERSION}/mihomo-linux-arm64-v${MIHOMO_VERSION}.gz" \
        | gzip -d - > "${CLASH_CORE_PATH}/clash_meta"

    # GeoIP / GeoSite 数据库
    wget -qO "files/etc/openclash/GeoIP.dat" \
        "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
    wget -qO "files/etc/openclash/GeoSite.dat" \
        "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"

    chmod a+x "${CLASH_CORE_PATH}/clash_meta"
    echo "已写入 mihomo v${MIHOMO_VERSION} 到 ${CLASH_CORE_PATH}/clash_meta"
fi

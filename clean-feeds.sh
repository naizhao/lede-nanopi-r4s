#!/bin/bash
# --------------------------------------------------------
# 清理 kenzok8/small-package(smpackage) 中与基础源重复 / Kconfig
# 自我递归的损坏包，否则 make defconfig 会报 "recursive dependency
# detected" 并静默禁用 firewall4 等核心符号（连累 nikki 等）。
#
# 顺序：feeds update -a  →  ./clean-feeds.sh [openwrt]  →  feeds install -a
# 幂等：可重复运行。
# --------------------------------------------------------
set -e
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
OPENWRT_DIR="${1:-$REPO_DIR/openwrt}"
SM="$OPENWRT_DIR/feeds/smpackage"

[ -d "$SM" ] || { echo "未找到 $SM，请先 feeds update"; exit 1; }

# smpackage 中导致递归/重复、且本机未使用的包（保留基础源版本）
REMOVE=(
    clashoo luci-app-clashoo          # 错误地 select firewall4，污染防火墙依赖
    luci-app-wifi-ap                  # 依赖 iptables 防火墙，参与 firewall4 死环
    qbittorrent luci-app-qbittorrent  # 自我 select 递归
    luci-app-natmap openwrt-natmap    # 与 packages/net/natmap 重复
    UA2F                              # 与 packages/net/ua2f 重复，自我递归
    luci-app-torbp                    # tor 自我递归（基础源已有 tor）
    luci-app-minieap luci-proto-minieap openwrt-minieap  # 与 packages 重复
    luci-app-fchomo                   # 自我递归
    miniupnpd-iptables                # 与 packages/net/miniupnpd 重复(保留基础源)
    oaf luci-app-oaf                  # kmod-oaf 自我递归
    v2ray-plugin hysteria             # 改用 packages/net/ 的 r2s 旧版(见下文部署)
)

echo "==> 清理 smpackage 重复/损坏包"
for p in "${REMOVE[@]}"; do
    if [ -e "$SM/$p" ]; then
        rm -rf "${SM:?}/$p"
        echo "    removed: $p"
    fi
done

# Lean packages feed 自带的 yq 4.33.1(go-toml v2.0.6) 与 Go 1.26 不兼容，
# 编译报 "undefined: InvalidAscii"。升到 4.45.1(对齐 r2s)。nikki 依赖 yq。
YQ_MK="$OPENWRT_DIR/feeds/packages/utils/yq/Makefile"
if [ -f "$YQ_MK" ] && grep -q 'PKG_VERSION:=4.33.1' "$YQ_MK"; then
    sed -i 's/^PKG_VERSION:=4.33.1/PKG_VERSION:=4.45.1/' "$YQ_MK"
    sed -i 's/^PKG_HASH:=c38b8210fb5a80ac88314fa346ea31f3dc9324cae9fe93cb334cacf909e09bc3/PKG_HASH:=074a21a002c32a1db3850064ad1fc420083d037951c8102adecfea6c5fd96427/' "$YQ_MK"
    echo "    yq 4.33.1 -> 4.45.1 (Go 1.26 兼容)"
fi

# Lean 自带 Go 1.26.4(前沿) 无法编译 xray-core/hysteria/geoview 等拉取的旧
# Go 库(go-toml v1.9.5 / yaml.v2)，报 "undefined: Position / yaml_emitter_flush"。
# 降到 1.23.12(r2s 同款，mihomo 要求 go>=1.20 仍满足)，修复整条代理 Go 链。
GO_MK="$OPENWRT_DIR/feeds/packages/lang/golang/golang/Makefile"
if [ -f "$GO_MK" ] && grep -q 'GO_VERSION_MAJOR_MINOR:=1.26' "$GO_MK"; then
    sed -i 's/^GO_VERSION_MAJOR_MINOR:=1.26/GO_VERSION_MAJOR_MINOR:=1.23/' "$GO_MK"
    sed -i 's/^GO_VERSION_PATCH:=4/GO_VERSION_PATCH:=12/' "$GO_MK"
    sed -i 's/^PKG_HASH:=4f668a32fbfc1132e6a881fb968c2f1dada631492a339211735fbb255a42602d/PKG_HASH:=e1cce9379a24e895714a412c7ddd157d2614d9edbe83a84449b6e1840b4f1226/' "$GO_MK"
    echo "    golang 1.26.4 -> 1.23.12 (兼容旧 Go 库 / 对齐 r2s)"
fi

# xray-core 固定到 r2s 同款 25.2.21(feed 默认 26.6.1)。两者在 Go 1.23.12 下均可编，
# 取 25.2.21 与 r2s 对齐、确定性。
XRAY_MK="$OPENWRT_DIR/feeds/packages/net/xray-core/Makefile"
if [ -f "$XRAY_MK" ] && grep -q 'PKG_VERSION:=26.6.1' "$XRAY_MK"; then
    sed -i 's/^PKG_VERSION:=26.6.1/PKG_VERSION:=25.2.21/' "$XRAY_MK"
    sed -i 's/^PKG_HASH:=efe463f8e35c4e6e93a6e8d51b27bae0cd4904b9820740c3af01733efb566fee/PKG_HASH:=a565db518d2da12fabb74e123d9bf2bdbc34420b81373938f8fcbc7004fda3ba/' "$XRAY_MK"
    echo "    xray-core 26.6.1 -> 25.2.21 (对齐 r2s)"
fi

# 代理 Go 包：Lean/smpackage 的版本都要求 go>=1.24/1.25(与降级到 1.23.12 冲突)。
# 换用 r2s 同款旧版(go.mod<=1.23)，Makefile + 旧版 tarball 一并固化在 custom/。
# GitHub 已移动这些 tag，现网 tarball hash 变了，故必须带固化 tarball。
mkdir -p "$OPENWRT_DIR/dl"
# xray-plugin 留在 smpackage(其 Makefile 用 $(TOPDIR) include)
if [ -d "$REPO_DIR/custom/xray-plugin" ]; then
    mkdir -p "$SM/xray-plugin"
    cp -f "$REPO_DIR/custom/xray-plugin/Makefile" "$SM/xray-plugin/Makefile"
    cp -f "$REPO_DIR/custom/xray-plugin/"*.tar.gz "$OPENWRT_DIR/dl/" 2>/dev/null || true
    echo "    xray-plugin -> 官方 teddysun 1.8.24 旧版"
fi
# geoview/v2ray-plugin/hysteria 放到 packages/net/(相对 include)
for p in geoview v2ray-plugin hysteria; do
    if [ -d "$REPO_DIR/custom/$p" ]; then
        mkdir -p "$OPENWRT_DIR/feeds/packages/net/$p"
        cp -f "$REPO_DIR/custom/$p/Makefile" "$OPENWRT_DIR/feeds/packages/net/$p/Makefile"
        cp -f "$REPO_DIR/custom/$p/"*.tar.gz "$OPENWRT_DIR/dl/" 2>/dev/null || true
        echo "    $p -> r2s 旧版(packages/net/)"
    fi
done

# Lean 自带 ruby 3.3.6 的 gem 文件清单与实际不符(打包报 "cp: cannot stat .../gems/...")。
# 换用 r2s 的 ruby 3.3.10(gem 清单匹配, 源 tarball 来自 ruby-lang.org 哈希稳定无需固化)。
if [ -d "$REPO_DIR/custom/ruby" ]; then
    cp -rf "$REPO_DIR/custom/ruby/"* "$OPENWRT_DIR/feeds/packages/lang/ruby/"
    echo "    ruby 3.3.6 -> 3.3.10 (gem 清单修复 / 对齐 r2s)"
fi

echo "==> 完成。接着运行："
echo "    cd $OPENWRT_DIR && ./scripts/feeds update -i && ./scripts/feeds install -a"

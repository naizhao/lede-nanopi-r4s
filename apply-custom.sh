#!/bin/bash
# --------------------------------------------------------
# 将 R4S 配置仓的自定义内容注入到一棵干净的 openwrt 源码树。
# 干净检出 Lean lede 后运行：  ./apply-custom.sh [openwrt目录,默认 openwrt]
# 幂等：可重复运行。
# --------------------------------------------------------
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
OPENWRT_DIR="${1:-$REPO_DIR/openwrt}"

if [ ! -f "$OPENWRT_DIR/feeds.conf.default" ]; then
    echo "错误：$OPENWRT_DIR 不像 openwrt 源码树（缺 feeds.conf.default）"
    exit 1
fi

echo "==> 注入自定义 feed (nikki / small-package)"
FEEDS="$OPENWRT_DIR/feeds.conf.default"
grep -q 'kenzok8/small-package' "$FEEDS" || \
    echo 'src-git smpackage https://github.com/kenzok8/small-package' >> "$FEEDS"
grep -q 'OpenWrt-nikki' "$FEEDS" || \
    echo 'src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main' >> "$FEEDS"

echo "==> 部署自定义包 openclash-core (mihomo arm64)"
mkdir -p "$OPENWRT_DIR/package/custom"
cp -rf "$REPO_DIR/custom/openclash-core" "$OPENWRT_DIR/package/custom/"

echo "==> 完成。后续："
echo "    cd $OPENWRT_DIR"
echo "    ./scripts/feeds update -a && ./scripts/feeds install -a"
echo "    make defconfig && make -j\$(nproc)"

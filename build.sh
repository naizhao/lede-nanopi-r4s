#!/bin/bash
# =====================================================================
# NanoPi R4S (RK3399/aarch64) 一键构建脚本  ·  源码: coolsnowwolf/lede
# 合并: 克隆 / feeds处理 / smpackage清理 / 版本修正 / 自定义包 / BraWRT定制
# =====================================================================
set -e
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
OPENWRT_DIR="$REPO_DIR/openwrt"
NPROC="$(nproc)"

REPO_URL="https://github.com/coolsnowwolf/lede"
REPO_BRANCH="master"
DEVICE_CONFIG="$REPO_DIR/nanopi-r4s.config"

# ---- BraWRT 定制 ----
LAN_IP="10.10.10.1"
HOSTNAME_BRAND="BraWRT"

usage() {
    cat <<EOF
用法: $0 <命令> [选项]

命令:
  all              一键: 克隆(若需) + feeds + 定制 + 配置 + 编译 (保留现有 .config)
  clone            克隆/检出最新 Lean lede 到 ./openwrt (若不存在)
  feeds            注入feed + 更新 + 清理smpackage + 修正版本 + 部署自定义包 + 安装
  customize        应用 BraWRT 定制(IP/主机名/banner/主题) + 部署 openclash-core
  reset-config     用 nanopi-r4s.config 覆盖 .config 并 defconfig
  menu             打开 menuconfig
  build [选项]     编译 (默认 -j$NPROC, 失败自动重试抗并行竞态)
  download         仅下载所有源码
  clean            清理构建产物
  dirclean         深度清理 (保留 dl 下载)
  rebuild          dirclean 后重新一键编译
  kernel-rebuild   仅重新编译内核
  saveconfig       保存当前 .config 到 nanopi-r4s.config
  -h | help        显示帮助

示例:
  $0 all                 # 从零到固件一键完成
  $0 feeds               # 仅刷新 feeds + 自定义包
  $0 build -j4 V=s       # 4线程详细编译
EOF
}

# --------------------------------------------------------------------
# 克隆源码
# --------------------------------------------------------------------
clone_source() {
    if [ -d "$OPENWRT_DIR/.git" ]; then
        echo "==> 已存在 openwrt/ , 跳过克隆 (HEAD: $(git -C "$OPENWRT_DIR" rev-parse --short HEAD))"
        return
    fi
    echo "==> 克隆 Lean lede ..."
    git clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$OPENWRT_DIR"
}

# --------------------------------------------------------------------
# 注入自定义 feed
# --------------------------------------------------------------------
inject_feeds() {
    local F="$OPENWRT_DIR/feeds.conf.default"
    grep -q 'kenzok8/small-package' "$F" || \
        echo 'src-git smpackage https://github.com/kenzok8/small-package' >> "$F"
    grep -q 'OpenWrt-nikki' "$F" || \
        echo 'src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main' >> "$F"
}

# --------------------------------------------------------------------
# 清理 smpackage 损坏/重复包 + 修正版本 + 部署 custom/ 里的代理 Go 包
# (Lean 前沿 Go 1.26 与代理旧库冲突; 降 Go + 用 r2s 旧版, 含固化 tarball)
# --------------------------------------------------------------------
clean_feeds() {
    local SM="$OPENWRT_DIR/feeds/smpackage"
    [ -d "$SM" ] || { echo "！未找到 smpackage, 请先 feeds update"; return 1; }
    mkdir -p "$OPENWRT_DIR/dl"

    echo "==> 清理 smpackage 递归/重复损坏包"
    local rm_list=(
        clashoo luci-app-clashoo luci-app-wifi-ap
        qbittorrent luci-app-qbittorrent
        luci-app-natmap openwrt-natmap UA2F luci-app-torbp
        luci-app-minieap luci-proto-minieap openwrt-minieap
        luci-app-fchomo miniupnpd-iptables oaf luci-app-oaf
        v2ray-plugin hysteria      # 改用 packages/net/ 的 r2s 旧版
    )
    local p
    for p in "${rm_list[@]}"; do
        [ -e "$SM/$p" ] && rm -rf "${SM:?}/$p" && echo "    - $p"
    done

    echo "==> 版本修正 (Go 1.26 兼容性)"
    # yq: 4.33.1(go-toml v2.0.6) 与 Go 1.26 冲突 -> 4.45.1
    local yq="$OPENWRT_DIR/feeds/packages/utils/yq/Makefile"
    if [ -f "$yq" ] && grep -q 'PKG_VERSION:=4.33.1' "$yq"; then
        sed -i 's/^PKG_VERSION:=4.33.1/PKG_VERSION:=4.45.1/' "$yq"
        sed -i 's/^PKG_HASH:=c38b8210fb5a80ac88314fa346ea31f3dc9324cae9fe93cb334cacf909e09bc3/PKG_HASH:=074a21a002c32a1db3850064ad1fc420083d037951c8102adecfea6c5fd96427/' "$yq"
        echo "    yq -> 4.45.1"
    fi
    # golang: 1.26.4(前沿,编不了代理旧库) -> 1.23.12 (r2s 同款, mihomo 仍满足 go>=1.20)
    local go="$OPENWRT_DIR/feeds/packages/lang/golang/golang/Makefile"
    if [ -f "$go" ] && grep -q 'GO_VERSION_MAJOR_MINOR:=1.26' "$go"; then
        sed -i 's/^GO_VERSION_MAJOR_MINOR:=1.26/GO_VERSION_MAJOR_MINOR:=1.23/' "$go"
        sed -i 's/^GO_VERSION_PATCH:=4/GO_VERSION_PATCH:=12/' "$go"
        sed -i 's/^PKG_HASH:=4f668a32fbfc1132e6a881fb968c2f1dada631492a339211735fbb255a42602d/PKG_HASH:=e1cce9379a24e895714a412c7ddd157d2614d9edbe83a84449b6e1840b4f1226/' "$go"
        echo "    golang -> 1.23.12"
    fi
    # xray-core: 26.6.1(需go1.26) -> 25.2.21 (r2s 同款)
    local xc="$OPENWRT_DIR/feeds/packages/net/xray-core/Makefile"
    if [ -f "$xc" ] && grep -q 'PKG_VERSION:=26.6.1' "$xc"; then
        sed -i 's/^PKG_VERSION:=26.6.1/PKG_VERSION:=25.2.21/' "$xc"
        sed -i 's/^PKG_HASH:=efe463f8e35c4e6e93a6e8d51b27bae0cd4904b9820740c3af01733efb566fee/PKG_HASH:=a565db518d2da12fabb74e123d9bf2bdbc34420b81373938f8fcbc7004fda3ba/' "$xc"
        echo "    xray-core -> 25.2.21"
    fi
    # ruby: 3.3.6(gem清单不符) -> 3.3.10 (r2s 整包)
    if [ -d "$REPO_DIR/custom/ruby" ]; then
        cp -rf "$REPO_DIR/custom/ruby/"* "$OPENWRT_DIR/feeds/packages/lang/ruby/"
        echo "    ruby -> 3.3.10"
    fi

    echo "==> 部署 custom/ 代理 Go 包 (含固化 tarball)"
    # xray-plugin 留在 smpackage ($(TOPDIR) include)
    if [ -d "$REPO_DIR/custom/xray-plugin" ]; then
        mkdir -p "$SM/xray-plugin"
        cp -f "$REPO_DIR/custom/xray-plugin/Makefile" "$SM/xray-plugin/Makefile"
        cp -f "$REPO_DIR/custom/xray-plugin/"*.tar.gz "$OPENWRT_DIR/dl/" 2>/dev/null || true
        echo "    + xray-plugin (teddysun 旧版)"
    fi
    # geoview/v2ray-plugin/hysteria 放 packages/net/ (相对 include)
    for p in geoview v2ray-plugin hysteria; do
        if [ -d "$REPO_DIR/custom/$p" ]; then
            mkdir -p "$OPENWRT_DIR/feeds/packages/net/$p"
            cp -f "$REPO_DIR/custom/$p/Makefile" "$OPENWRT_DIR/feeds/packages/net/$p/Makefile"
            cp -f "$REPO_DIR/custom/$p/"*.tar.gz "$OPENWRT_DIR/dl/" 2>/dev/null || true
            echo "    + $p (r2s 旧版)"
        fi
    done
}

# --------------------------------------------------------------------
# 完整 feeds 流程
# --------------------------------------------------------------------
update_feeds() {
    cd "$OPENWRT_DIR"
    inject_feeds
    echo "=============================="
    echo "更新 feeds ..."
    echo "=============================="
    ./scripts/feeds update -a
    clean_feeds
    ./scripts/feeds update -i >/dev/null 2>&1 || true
    echo "=============================="
    echo "安装 feeds ..."
    echo "=============================="
    ./scripts/feeds install -a
    # 确保 nikki / v2ray-plugin / hysteria 来自正确 feed
    ./scripts/feeds uninstall nikki v2ray-plugin hysteria >/dev/null 2>&1 || true
    ./scripts/feeds install -p nikki nikki >/dev/null 2>&1 || true
    ./scripts/feeds install -p packages v2ray-plugin hysteria >/dev/null 2>&1 || true
    echo "Feeds 完成！"
}

# --------------------------------------------------------------------
# 部署自定义 openclash-core 包 (mihomo arm64)
# --------------------------------------------------------------------
deploy_openclash_core() {
    if [ -d "$REPO_DIR/custom/openclash-core" ]; then
        mkdir -p "$OPENWRT_DIR/package/custom"
        cp -rf "$REPO_DIR/custom/openclash-core" "$OPENWRT_DIR/package/custom/"
        echo "    + package/custom/openclash-core (mihomo arm64)"
    fi
}

# --------------------------------------------------------------------
# BraWRT 定制: IP / 主机名 / banner / 主题 (仅应用 2026 树仍有效的锚点)
# --------------------------------------------------------------------
customize() {
    cd "$OPENWRT_DIR"
    echo "==> 应用 BraWRT 定制"
    local cg="package/base-files/files/bin/config_generate"
    local zz="package/lean/default-settings/files/zzz-default-settings"

    # 还原 zzz 以便幂等
    git checkout -- "$zz" 2>/dev/null || true

    # 1) 默认 LAN IP
    if grep -q '192.168.1.1' "$cg"; then
        sed -i "s/192.168.1.1/$LAN_IP/g" "$cg"
        echo "    LAN IP -> $LAN_IP"
    else
        echo "    ! config_generate 无 192.168.1.1 锚点, 跳过 IP"
    fi

    # 2) 主机名 + (条件)design 主题, 插在 'uci commit system' 前
    if grep -q 'uci commit system' "$zz"; then
        sed -i "/uci commit system/i uci set system.@system[0].hostname='$HOSTNAME_BRAND'" "$zz"
        echo "    主机名 -> $HOSTNAME_BRAND"
        if [ -d feeds/luci/themes/luci-theme-design ] || grep -q 'luci-theme-design=y' .config 2>/dev/null; then
            sed -i "/uci commit system/i uci set luci.main.mediaurlbase='/luci-static/design'; uci commit luci" "$zz"
            echo "    主题 -> design"
        fi
    fi

    # 3) vimrc / wgetrc (插在 exit 0 前)
    if grep -q 'exit 0' "$zz"; then
        grep -q '.vimrc' "$zz" || sed -i "/exit 0/i echo \"syntax on\" > /root/.vimrc" "$zz"
        grep -q '.wgetrc' "$zz" || sed -i "/exit 0/i echo 'hsts=0' > /root/.wgetrc" "$zz"
    fi

    # 4) banner (BraWRT), 替换 {date} 占位
    if [ -f "$REPO_DIR/banner" ]; then
        cp -f "$REPO_DIR/banner" package/base-files/files/etc/banner
        local rev
        rev="$(grep -m1 DISTRIB_REVISION= "$zz" 2>/dev/null | awk -F\' '{print $2}')"
        sed -i "s/{date}/${rev:-BraWRT} ($(date +%Y-%m-%d))/g" package/base-files/files/etc/banner
        echo "    banner -> BraWRT"
    fi

    deploy_openclash_core
}

# --------------------------------------------------------------------
# 设备配置
# --------------------------------------------------------------------
reset_config() {
    cd "$OPENWRT_DIR"
    [ -f "$DEVICE_CONFIG" ] || { echo "错误: 缺 $DEVICE_CONFIG"; exit 1; }
    cp "$DEVICE_CONFIG" .config
    make defconfig
    echo "配置已重置为 nanopi-r4s.config"
}

save_config() {
    cd "$OPENWRT_DIR"
    cp .config "$DEVICE_CONFIG"
    echo "当前 .config 已保存到 nanopi-r4s.config"
}

# --------------------------------------------------------------------
# 编译 (失败自动重试抗并行竞态)
# --------------------------------------------------------------------
do_build() {
    cd "$OPENWRT_DIR"
    local args="$*"
    [[ "$args" =~ -j ]] || args="-j$NPROC $args"
    local start=$(date +%s) rc=0 i
    for i in 1 2 3 4 5; do
        echo "===== make $args (尝试 #$i) ====="
        if make $args; then rc=0; break; fi
        rc=$?
        echo "===== 第 $i 次失败 rc=$rc, 重试续跑 ====="
        sleep 3
    done
    [ $rc -ne 0 ] && { echo "===== 转 -j1 V=s 定位错误 ====="; make -j1 V=s || rc=$?; }
    local dur=$(( $(date +%s) - start ))
    echo "=============================="
    if [ $rc -eq 0 ]; then
        echo "编译成功！用时 $((dur/60))分$((dur%60))秒"
        local out="bin/targets/rockchip/armv8"
        ls -lh "$out"/*sysupgrade.img.gz 2>/dev/null | awk '{print "  "$NF" ("$5")"}'
    else
        echo "编译失败 rc=$rc, 见上方 -j1 输出"
    fi
    return $rc
}

do_all() {
    clone_source
    update_feeds
    if [ -f "$OPENWRT_DIR/.config" ]; then
        echo "==> 检测到 .config, 保留 (重置请: $0 reset-config)"
        cd "$OPENWRT_DIR" && make defconfig
    else
        reset_config
    fi
    customize
    cd "$OPENWRT_DIR" && make defconfig
    do_build
}

# --------------------------------------------------------------------
case "$1" in
    all)            do_all ;;
    clone)          clone_source ;;
    feeds)          clone_source; update_feeds ;;
    customize)      customize; cd "$OPENWRT_DIR" && make defconfig ;;
    reset-config)   reset_config ;;
    menu)           cd "$OPENWRT_DIR" && make menuconfig ;;
    build)          shift; do_build "$@" ;;
    download)       cd "$OPENWRT_DIR" && make download -j"$NPROC" ;;
    clean)          cd "$OPENWRT_DIR" && make clean ;;
    dirclean)       cd "$OPENWRT_DIR" && make dirclean ;;
    rebuild)        cd "$OPENWRT_DIR" && make dirclean; do_all ;;
    kernel-rebuild) cd "$OPENWRT_DIR" && make target/linux/clean && make target/linux/compile -j"$NPROC" V=s && do_build ;;
    saveconfig)     save_config ;;
    -h|--help|help) usage ;;
    *)              usage ;;
esac

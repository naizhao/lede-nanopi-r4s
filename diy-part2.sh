#!/bin/bash
# --------------------------------------------------------
# Script to compile and create files for each openwrt
# --------------------------------------------------------
#1. Modify default IP

git checkout -- package/lean/default-settings/files/zzz-default-settings

sed -i 's/192.168.1.1/10.10.10.1/g' package/base-files/files/bin/config_generate
sed -i '/uci commit system/i\uci set system.@system[0].hostname='BraWRT'' package/lean/default-settings/files/zzz-default-settings
sed -i "s/OpenWrt /BraWRT/g" package/lean/default-settings/files/zzz-default-settings
sed -i '/uci commit luci/i\uci set luci.main.mediaurlbase='/luci-static/design'' package/lean/default-settings/files/zzz-default-settings
sed -i '/exit 0/i\echo "'syntax\ on'" > /root/.vimrc' package/lean/default-settings/files/zzz-default-settings
sed -i '/exit 0/i\echo 'hsts=0' > /root/.wgetrc' package/lean/default-settings/files/zzz-default-settings


pushd package/lean/default-settings/files
sed -i '/http/d' zzz-default-settings
sed -i '/18.06/d' zzz-default-settings
export orig_version=$(cat "zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
export date_version=$(date -d "$(rdate -n -4 -p ntp.aliyun.com)" +'%Y-%m-%d')
sed -i "s/${orig_version}/${orig_version} (${date_version})/g" zzz-default-settings
popd

cp -f ../banner package/base-files/files/etc/banner
sed -i "s/{date}/${orig_version} (${date_version})/g" package/base-files/files/etc/banner

sed -i 's,1608,1800,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/10-cpufreq
sed -i 's,2016,2208,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/10-cpufreq
sed -i 's,1512,1608,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/10-cpufreq








# R4S 刷新与 Clash 现代化说明

> NanoPi R4S (RK3399 / arm64) · 源码：coolsnowwolf/lede (Lean) · 2026-06 刷新

## 背景

旧的 `openwrt/` 是 2023-03 的 Lean lede 检出（内核 5.x、iptables 时代），
clash 集成用已失效的 `vernesong/OpenClash` 三内核(dev/premium/meta)下载。
本次对齐 `../r2s` 的现代做法重做。

**主要变化：**

1. **源码树**：干净检出最新 Lean lede（2026-06）。旧树保留为 `openwrt-2023-bak/`。
2. **Clash 内核**：废弃三内核 shell 下载；改为自定义包 `custom/openclash-core`，
   从 MetaCubeX/mihomo 官方 release 拉**单个 mihomo (clash.meta) 内核**（arm64）
   + GeoIP/GeoSite，随 `make` 自动构建、版本可复现。
3. **新增 nikki**：`nikkinikki-org/OpenWrt-nikki` feed（mihomo 独立面板）。
4. **防火墙迁移 iptables → firewall4/nftables**：nikki 为 nftables-only；
   passwall/passwall2/ssr-plus 自动切到 `_Nftables_Transparent_Proxy` 变体。
5. **feed 修正**：`kenzok78/small-package` → `kenzok8/small-package`（旧的已 404）。
6. **smpackage 去重**：清掉 16 个与基础源重复 / Kconfig 自我递归的损坏包
   （见 `clean-feeds.sh`），消除 `recursive dependency` 导致 firewall4/nikki 被丢弃。

## 仓库内的可复现产物

| 文件 | 作用 |
|---|---|
| **`build.sh`** | **全功能一键脚本**：克隆 + feeds + smpackage清理 + 版本修正 + 自定义包 + BraWRT定制 + 编译 |
| `nanopi-r4s.config` | 已验证的设备 `.config` 快照 |
| `banner` | BraWRT ASCII banner |
| `custom/openclash-core/` | mihomo arm64 内核包（mihomo 1.19.27 + GeoIP/Site）|
| `custom/{xray-plugin,geoview,v2ray-plugin,hysteria}/` | 对齐 r2s 的代理 Go 包 Makefile + **固化 tarball**（GitHub 已移动 tag，必须固化）|
| `custom/ruby/` | ruby 3.3.10 整包（修 gem 清单）|
| `diy-part1.sh` / `diy-part2.sh` | **云编译(GitHub Actions)** 钩子；本地构建用 `build.sh` |

## 从零复现步骤（本地）

```bash
cd /data/R4S
./build.sh all          # 克隆→feeds→清理→定制→配置→编译，一条命令到固件
# 其它: ./build.sh feeds | customize | menu | build | rebuild | saveconfig
```

> `build.sh customize` 应用 BraWRT 定制：LAN IP `10.10.10.1`、主机名 `BraWRT`、
> design 主题、BraWRT banner。（注：云编译走 `diy-part2.sh`，其 cpufreq 与
> `OpenWrt→BraWRT` 锚点在 2026 树已失效，`build.sh` 用仍有效的锚点实现品牌定制。）

## 构建期修复（全部已纳入 `build.sh` / `custom/` / 快照）

- **Go 1.26.4 → 1.23.12**：Lean 前沿 Go 编不了代理拉取的旧 Go 库（go-toml v1.9.5 /
  yaml.v2，报 `undefined: Position / yaml_emitter_flush`）；而 Lean feed 的新版代理包
  又要 go≥1.24/1.25/1.26 —— 双向冲突。降到 1.23.12（r2s 同款，mihomo 仍满足 go≥1.20），
  并把代理 Go 包全部对齐 r2s 旧版（go.mod≤1.23）：
  - xray-core 26.6.1→25.2.21、xray-plugin(kenzok→teddysun 1.8.24)、
    geoview 0.2.6→0.1.10、v2ray-plugin 5.49.0→5.25.0、hysteria 2.9.2→2.6.4
- **yq 4.33.1 → 4.45.1**（go-toml v2.0.6 与新 Go 不兼容；nikki 依赖 yq）
- **ruby 3.3.6 → 3.3.10**（gem 文件清单不符，打包报 `cp: cannot stat .../gems`）
- **feed `kenzok78` → `kenzok8`/small-package**（旧的已 404）
- **smpackage 去重**：清掉 18 个递归/重复损坏包（消除 firewall4/nikki 被静默丢弃）
- **剔除**非必需且需新 Go / 损坏的包：hwinfo、cloudflared、containerd/runc/tini、node

## 已知/遗留

- `make defconfig` 残留 2 个**良性** VARIANT 递归告警（`mihomo-alpha↔mihomo-meta`、
  `strongswan` 变体对），不影响构建。
- **固件偏大**（squashfs ~210MB）：含 golang 编译器(67MB)、3 份 mihomo(去重可省)、
  netdata/git/icu-full-data 等 kitchen-sink。如需精简，在 `menu` 里去掉即可。
- 升级版本：mihomo 改 `custom/openclash-core/Makefile`；代理 Go 包改 `custom/*/`
  对应 Makefile（注意 GitHub tarball hash 漂移，需同步更新固化 tarball）。

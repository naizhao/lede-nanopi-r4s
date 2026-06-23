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
| `custom/openclash-core/Makefile` | mihomo arm64 内核包（PKGARCH `aarch64_generic`，版本 1.19.27） |
| `apply-custom.sh` | 向干净 openwrt 树注入 nikki/smpackage feed + 部署 openclash-core 包 |
| `clean-feeds.sh` | `feeds update` 后清理 smpackage 损坏/重复包 |
| `update-clash.sh` | （备用）手动把 mihomo 烤进 `files/` overlay，非包方式 |
| `nanopi-r4s.config` | 已验证的设备 `.config` 快照 |

## 从零复现步骤

```bash
cd /data/R4S
git clone --depth 1 https://github.com/coolsnowwolf/lede openwrt
cp nanopi-r4s.config openwrt/.config        # 设备配置
./apply-custom.sh openwrt                    # 注入 feed + 自定义包
cd openwrt
./scripts/feeds update -a
../clean-feeds.sh .                           # 清理 smpackage 损坏包（update 后、install 前）
./scripts/feeds install -a
./scripts/feeds uninstall nikki && ./scripts/feeds install -p nikki nikki  # 确保 nikki 来自 nikki feed
make defconfig
make -j$(nproc) || make -j1 V=s
```

## 构建期修复（已纳入脚本/快照）

- **yq 4.33.1 → 4.45.1**：Lean packages feed 自带的旧 yq(go-toml v2.0.6) 与 Go 1.26
  不兼容（`undefined: InvalidAscii`），nikki 依赖它。已由 `clean-feeds.sh` 自动升级（对齐 r2s）。
- **剔除 hwinfo**：其 host 构建缺 e2fsprogs libuuid 头（自身打包 bug），且无包依赖它。
  已在 `nanopi-r4s.config` 快照中关闭。

## 已知/遗留

- `make defconfig` 残留 2 个**良性** VARIANT 递归告警：`mihomo-alpha↔mihomo-meta`
  与 `strongswan-minimal↔strongswan-mod-kdf`，不影响构建（目标包均存活）。
- mihomo 版本固定在 `custom/openclash-core/Makefile` 的 `PKG_VERSION`，
  升级时改这一处即可（同步核对 MetaCubeX/mihomo 最新 release 的 arm64 资产名）。
- 尚未跑完整 `make`；config 层 + 下载 URL(HTTP 200) 已验证。

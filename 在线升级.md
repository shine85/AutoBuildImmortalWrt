# 在线升级（AutoUpdate）

本仓库用 ImageBuilder 接入与 [shine85/build-actions281677160](https://github.com/shine85/build-actions281677160) **同一套检测规则**，不调用那套源码编译系统，也不在本仓库长期存放插件源码。

刷入带此功能的新固件后，可在网页「系统 → AutoUpdate」或 SSH 检测/升级。旧固件没有 `/etc/openwrt_update`，不能直接网页升级。

## 怎么实现

编译时做三件事：

1. **装插件**  
   `shell/autoupdate-ib.sh` 克隆 [281677160/luci-app-autoupdate](https://github.com/281677160/luci-app-autoupdate)，把 `AutoUpdate` 脚本、LuCI 页面、init 拷进 ImageBuilder 的 `files/`。  
   同时往软件包列表追加依赖：`jq`、`bc`；24.10 再加 `wget-ssl`、`luci-compat`、`luci-lua-runtime`；23.05 用 `wget`。

2. **写本机通道**  
   生成 `/etc/openwrt_update`，包含仓库地址、机型、`LUCI_EDITION`、时间戳，以及下载地址：

   `https://github.com/<本仓库>/releases/download/Update-<board>-<机型>`

3. **发固定通道**  
   把 `sysupgrade.bin` 改名为 AutoUpdate 能认的格式，发布到 Release 标签 `Update-<board>-<机型>`，再上传 `zzz_api` 供检测。

文件名示例：

```text
24.10-Immortalwrt-jcg_q30-ubootmod-<unix时间戳>-sysupgrade-<6位哈希>.bin
```

日常带日期的 Release 仍然会发；在线升级只认上面的 `Update-*` 通道。

## 哪些编译会带上

| 入口 | 结果 |
|---|---|
| `build-798x.yml` 的 24.10.x | 有 |
| `build-798x.yml` 的 23.05.4 特有机型 | 有（先把 `build23.sh` 拷成 `build24.sh`） |
| `build-wireless-router.yml` 的 23.05 / 24.10 | 有 |
| `build-wireless-router25.12.yml`（25.x） | **没有**，未接入 |
| `glinet_gl-axt1800` / `glinet_gl-ax1800`（snapshot + apk） | **没有**，构建脚本跳过第三方插件 |

`build-798x.yml` 本身不编 25.x。

## 相关文件

| 文件 | 作用 |
|---|---|
| `shell/autoupdate-ib.sh` | 克隆插件、写 `openwrt_update`、追加依赖包 |
| `shell/publish-autoupdate.sh` | 改名 sysupgrade、上传 `zzz_api` |
| `shell/describe-release.cjs` | 生成发行说明 |
| `mediatek-filogic/build23.sh` / `build24.sh` | 调用 `enable_autoupdate_ib` |
| `.github/workflows/build-798x.yml` | 传入通道参数并发布 `Update-*` |
| `.github/workflows/build-wireless-router.yml` | 同上 |

配置不在 `custom-packages.sh` 里。工作流只传 `GITHUB_LINK`、`AUTOUPDATE_TS`、`LUCI_EDITION`、`TARGET_BOARD`。

## 发行说明

日常 Release 和 `Update-*` 通道共用 `release-body.md`，内容包括：

- 北京时间编译时间
- 网段、默认管理地址、默认网关、编译配置
- ImageBuilder 标签、LuCI 版本、Docker、iStore、在线升级通道
- 固件 `.manifest` 里实际编入的 `luci-app-*` 和 `luci-theme-*`

网段和管理地址来自工作流的 `custom_router_ip`（本仓库默认 `192.168.99.1`）。

## 使用

1. 推送后跑一次 `build-798x`（或对应无线路由工作流）。
2. 先用「备份/升级」刷入这次新固件（旧系统没有升级配置）。
3. 登录后台，默认定时升级是关闭的。
4. 检测：网页 AutoUpdate，或 SSH `AutoUpdate`。
5. 升级：`AutoUpdate -u` 保留配置；`AutoUpdate -k` 不保留配置。

用户名 `root`，密码无。

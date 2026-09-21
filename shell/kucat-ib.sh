#!/bin/bash
# 从 sirpdboy Release 拉取酷猫主题设置 ipk，和主题一起编进固件。
# 23.05：store 已有 theme 3.1.2，补同版本配套的 config 2.1.0。
# 24.10：theme 3.3.0 + config 2.2.1（设置工具要求主题 >= 3.3.0）。

fetch_kucat_ipks() {
  local pkgdir="/home/build/immortalwrt/packages"
  mkdir -p "$pkgdir"
  local edition="${LUCI_EDITION:-24.10}"
  local urls
  if [ "$edition" = "23.05" ]; then
    urls="
https://github.com/sirpdboy/luci-theme-kucat/releases/download/v3.1.2/luci-app-kucat-config_2.1.0-r20251117_all.ipk
https://github.com/sirpdboy/luci-theme-kucat/releases/download/v3.1.2/luci-i18n-kucat-config-zh-cn_0_all.ipk
"
  else
    rm -f "$pkgdir"/luci-theme-kucat_*.ipk
    urls="
https://github.com/sirpdboy/luci-theme-kucat/releases/download/v3.3.0/luci-theme-kucat_3.3.0-r20260227_all.ipk
https://github.com/sirpdboy/luci-app-kucat-config/releases/download/v2.2.1/luci-app-kucat-config_2.2.1-r20260312_all.ipk
https://github.com/sirpdboy/luci-app-kucat-config/releases/download/v2.2.1/luci-i18n-kucat-config-zh-cn_0_all.ipk
"
  fi
  local url name
  for url in $urls; do
    [ -z "$url" ] && continue
    name="$(basename "$url")"
    echo "⬇️ 下载 $name"
    if command -v wget >/dev/null 2>&1; then
      wget -qO "$pkgdir/$name" "$url"
    else
      curl -fsSL -o "$pkgdir/$name" "$url"
    fi
    if [ ! -s "$pkgdir/$name" ]; then
      echo "❌ 下载失败: $url"
      exit 1
    fi
    echo "✅ $name ($(wc -c < "$pkgdir/$name") bytes)"
  done
}

add_kucat_packages() {
  PACKAGES="$PACKAGES luci-theme-kucat luci-app-kucat-config luci-i18n-kucat-config-zh-cn"
}

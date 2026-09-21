#!/bin/bash
# ImageBuilder 侧：装入 luci-app-autoupdate 文件，并写入 /etc/openwrt_update
# 匹配规则与 281677160/luci-app-autoupdate 的 AutoUpdate 一致，不调用另一仓库的编译系统。

prepare_autoupdate_files() {
  local repo="/tmp/src-autoupdate"
  local dest="/home/build/immortalwrt/files"
  rm -rf "$repo"
  git clone --depth=1 --branch=main https://github.com/281677160/luci-app-autoupdate.git "$repo"
  mkdir -p "$dest/etc/init.d" "$dest/etc/config" "$dest/etc/uci-defaults" \
    "$dest/usr/lib/lua/luci/controller" "$dest/usr/lib/lua/luci/model/cbi/autoupdate" \
    "$dest/usr/lib/lua/luci/view/autoupdate"
  cp -a "$repo/root/etc/init.d/autoupdate" "$dest/etc/init.d/autoupdate"
  cp -a "$repo/root/etc/config/autoupdate" "$dest/etc/config/autoupdate"
  cp -a "$repo/root/etc/uci-defaults/40_luci-app-autoupdate" "$dest/etc/uci-defaults/40_luci-app-autoupdate"
  cp -a "$repo/root/usr/." "$dest/usr/"
  cp -a "$repo/luasrc/controller/autoupdate.lua" "$dest/usr/lib/lua/luci/controller/autoupdate.lua"
  cp -a "$repo/luasrc/model/cbi/autoupdate/autoupdate.lua" "$dest/usr/lib/lua/luci/model/cbi/autoupdate/autoupdate.lua"
  chmod 755 "$dest/etc/init.d/autoupdate" "$dest/usr/bin/AutoUpdate" "$dest/usr/bin/AutoUpgrade" \
    "$dest/etc/uci-defaults/40_luci-app-autoupdate"
  rm -rf "$repo"
  echo "✅ 已装入 luci-app-autoupdate 文件"
}

write_openwrt_update() {
  local dest="/home/build/immortalwrt/files/etc/openwrt_update"
  local github_link="${GITHUB_LINK:?缺少 GITHUB_LINK}"
  local profile="${PROFILE:?缺少 PROFILE}"
  local ts="${AUTOUPDATE_TS:?缺少 AUTOUPDATE_TS}"
  local edition="${LUCI_EDITION:?缺少 LUCI_EDITION}"
  local board="${TARGET_BOARD:?缺少 TARGET_BOARD}"
  local update_tag="Update-${board}-${profile}"
  mkdir -p /home/build/immortalwrt/files/etc
  cat > "$dest" <<EOF
GITHUB_LINK="${github_link}"
FIRMWARE_VERSION="Immortalwrt-${profile}-${ts}"
LUCI_EDITION="${edition}"
SOURCE="Immortalwrt"
DEVICE_MODEL="${profile}"
FIRMWARE_SUFFIX=".bin"
TARGET_BOARD="${board}"
GITHUB_PROXY="https://ghfast.top"
RELEASE_DOWNLOAD="\$GITHUB_LINK/releases/download/${update_tag}"
EOF
  chmod 755 "$dest"
  echo "✅ 已写入 openwrt_update: ${update_tag} ts=${ts}"
  cat "$dest"
}

add_autoupdate_packages() {
  PACKAGES="$PACKAGES jq bc"
  if [ "${LUCI_EDITION:-24.10}" = "23.05" ]; then
    PACKAGES="$PACKAGES wget"
  else
    PACKAGES="$PACKAGES wget-ssl luci-compat luci-lua-runtime"
  fi
}

enable_autoupdate_ib() {
  if [ -z "${AUTOUPDATE_TS:-}" ] || [ -z "${GITHUB_LINK:-}" ] || [ -z "${PROFILE:-}" ] || [ -z "${TARGET_BOARD:-}" ] || [ -z "${LUCI_EDITION:-}" ]; then
    echo "⏭️ 未提供 AutoUpdate 参数，跳过在线升级集成"
    return 0
  fi
  prepare_autoupdate_files
  write_openwrt_update
  add_autoupdate_packages
}

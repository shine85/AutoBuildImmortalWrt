#!/bin/bash
# Runner 侧：按 AutoUpdate 文件名规则准备固件，并生成 zzz_api
set -euo pipefail

prepare() {
  local target_dir="${TARGET_DIR:?缺少 TARGET_DIR}"
  local profile="${PROFILE:?缺少 PROFILE}"
  local ts="${AUTOUPDATE_TS:?缺少 AUTOUPDATE_TS}"
  local edition="${LUCI_EDITION:?缺少 LUCI_EDITION}"
  local board="${TARGET_BOARD:?缺少 TARGET_BOARD}"
  local dist="${GITHUB_WORKSPACE}/autoupdate-dist"
  rm -rf "$dist"
  mkdir -p "$dist"

  local src
  src="$(find "$target_dir" -type f -name '*sysupgrade.bin' ! -name '*factory*' | head -n 1)"
  if [ -z "$src" ]; then
    echo "❌ 未找到 sysupgrade.bin: $target_dir"
    find "$target_dir" -type f | head -n 50
    exit 1
  fi

  local hash
  hash="$(md5sum "$src" | cut -c1-3)$(sha256sum "$src" | cut -c1-3)"
  local name="${edition}-Immortalwrt-${profile}-${ts}-sysupgrade-${hash}.bin"
  cp -f "$src" "$dist/$name"
  echo "UPDATE_TAG=Update-${board}-${profile}" >> "$GITHUB_ENV"
  echo "AUTOUPDATE_FILE=$name" >> "$GITHUB_ENV"
  echo "✅ AutoUpdate 固件: $name"
  ls -lh "$dist"
}

index_api() {
  local repo="${GITHUB_REPOSITORY:?缺少 GITHUB_REPOSITORY}"
  local tag="${UPDATE_TAG:?缺少 UPDATE_TAG}"
  local dist="${GITHUB_WORKSPACE}/autoupdate-dist"
  mkdir -p "$dist"
  curl -fsSL -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${repo}/releases/tags/${tag}" > "$dist/zzz_api"
  if ! grep -q '"assets"' "$dist/zzz_api"; then
    echo "❌ 获取 Release JSON 失败"
    cat "$dist/zzz_api"
    exit 1
  fi
  gh release upload "$tag" "$dist/zzz_api" --clobber
  echo "✅ 已上传 zzz_api -> $tag"
}

case "${1:-}" in
  prepare) prepare ;;
  index) index_api ;;
  *) echo "用法: $0 prepare|index"; exit 1 ;;
esac

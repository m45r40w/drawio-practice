#!/usr/bin/env bash
# draw.io の公式ビューア（PNG 変換用）と日本語フォントを用意する。
# 何度実行しても同じ結果になる（入っていれば何もしない）。
#   使い方: bash scripts/setup-drawio-viewer.sh
#   入れ先: $DRAWIO_VIEWER_DIR（既定: /opt/drawio-viewer）
set -euo pipefail

VIEWER_DIR="${DRAWIO_VIEWER_DIR:-/opt/drawio-viewer}"
# draw.io の Web アプリ一式（Apache-2.0）。npm レジストリから取得し、npm が整合性を検証する。
PKG="@zklogic/draw.io@15.7.2-rc1"

if [ -f "$VIEWER_DIR/js/viewer-static.min.js" ] && [ -f "$VIEWER_DIR/stencils/aws4.xml" ]; then
  echo "drawio viewer: already installed at $VIEWER_DIR"
else
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  (cd "$tmp" && npm pack "$PKG" --silent >/dev/null)
  tar xzf "$tmp"/*.tgz -C "$tmp" \
    package/dist/mxgraph/grapheditor/viewer-static.min.js \
    package/dist/mxgraph/stencils package/dist/mxgraph/shapes \
    package/dist/mxgraph/img package/dist/mxgraph/images
  mkdir -p "$VIEWER_DIR/js"
  src="$tmp/package/dist/mxgraph"
  cp "$src/grapheditor/viewer-static.min.js" "$VIEWER_DIR/js/"
  rm -rf "$VIEWER_DIR/stencils" "$VIEWER_DIR/shapes" "$VIEWER_DIR/img" "$VIEWER_DIR/images"
  cp -r "$src/stencils" "$src/shapes" "$src/img" "$src/images" "$VIEWER_DIR/"
  echo "drawio viewer: installed $PKG to $VIEWER_DIR"
fi

# 日本語フォント。図では fontFamily=Noto Sans JP を使うので、その名前を Noto Sans CJK JP に対応づける。
if command -v apt-get >/dev/null 2>&1 && ! fc-list | grep -q "Noto Sans CJK JP"; then
  apt-get update -qq && apt-get install -y -qq fonts-noto-cjk >/dev/null
fi
if [ -d /etc/fonts/conf.d ] && [ -w /etc/fonts/conf.d ]; then
  cat > /etc/fonts/conf.d/60-noto-sans-jp-alias.conf <<'XML'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias binding="same">
    <family>Noto Sans JP</family>
    <prefer><family>Noto Sans CJK JP</family></prefer>
  </alias>
</fontconfig>
XML
  fc-cache -f >/dev/null 2>&1 || true
fi
echo "font 'Noto Sans JP' -> $(fc-match 'Noto Sans JP')"

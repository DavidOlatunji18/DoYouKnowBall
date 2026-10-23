#!/bin/sh
# Renders the logo SVGs in mobile/assets/branding to PNG using headless Chrome.
# Usage: sh design/render_assets.sh
set -e
cd "$(dirname "$0")/.."
DIR="$PWD/mobile/assets/branding"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
python3 -I design/make_logo.py "$DIR" >/dev/null
for svg in "$DIR"/*.svg; do
  name=$(basename "$svg" .svg)
  size=$(sed -n 's/.*width="\([0-9]*\)" height="\([0-9]*\)".*/\1,\2/p' "$svg" | head -1)
  bg=""
  case "$name" in logo-on-green|app-icon) ;; *) bg="--default-background-color=00000000" ;; esac
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 $bg \
    --window-size="$size" --screenshot="$DIR/$name.png" "file://$svg" >/dev/null 2>&1
  echo "$name.png ($size)"
done

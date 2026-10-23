#!/bin/sh
# Renders the logo and ball SVGs (mobile/assets/branding, mobile/assets/balls) to PNG using headless Chrome.
# Usage: sh design/render_assets.sh
set -e
cd "$(dirname "$0")/.."
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
python3 -I design/make_logo.py "$PWD/mobile/assets/branding" >/dev/null
python3 -I design/make_ball_icons.py "$PWD/mobile/assets/balls" >/dev/null
for svg in "$PWD"/mobile/assets/branding/*.svg "$PWD"/mobile/assets/balls/*.svg; do
  DIR=$(dirname "$svg")
  name=$(basename "$svg" .svg)
  size=$(sed -n 's/.*width="\([0-9]*\)" height="\([0-9]*\)".*/\1,\2/p' "$svg" | head -1)
  bg=""
  case "$name" in logo-on-green|app-icon) ;; *) bg="--default-background-color=00000000" ;; esac
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files --force-device-scale-factor=1 $bg \
    --window-size="$size" --screenshot="$DIR/$name.png" --virtual-time-budget=2000 "file://$svg" >/dev/null 2>&1
  echo "$name.png ($size)"
done

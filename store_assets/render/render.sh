#!/bin/bash
# Render semua slide Play Store ke store_assets/export/. Jalankan: store_assets/render/render.sh
set -e
cd "$(dirname "$0")"
R="$PWD"; OUT="$R/../export"; ROOT="$R/../.."
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p "$OUT/phone" "$OUT/tablet"
shot(){ # query W H out
  "$CH" --headless=new --hide-scrollbars --force-device-scale-factor=1 --window-size=$2,$3 \
    --virtual-time-budget=5000 --default-background-color=FBF4EAFF --screenshot="$4" "file://$R/slides.html?$1" >/dev/null 2>&1
  echo "$4"
}
for n in 1 2 3 4 5 6; do shot "d=phone&n=$n" 1080 1920 "$OUT/phone/0$n.png"; done
for n in 1 2 3 4; do shot "d=tablet&n=$n" 1920 1080 "$OUT/tablet/0$n.png"; done
shot "d=fg" 1024 500 "$OUT/feature-graphic.png"
sips -z 512 512 -s format png "$ROOT/assets/images/app_logo.webp" --out "$OUT/icon-512.png" >/dev/null
echo "$OUT/icon-512.png"

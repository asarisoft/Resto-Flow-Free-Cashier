#!/usr/bin/env bash
# Screenshot Play Store otomatis (integration_test + flutter drive).
#
# Pakai:  ./screenshots.sh [phone|tablet|all] [--to-editor]
#   phone  : 1 emulator/HP Android menyala (1080x2400)  -> screnshoot/phone/
#   tablet : 1 emulator tablet menyala (2560x1600)       -> screnshoot/tablet/
#   all    : phone lalu tablet; skrip minta nyalakan emulator tiap giliran
#   (tanpa argumen: jenis ditebak dari ukuran layar device yang menyala)
#   --to-editor : salin ke store_assets/public/screenshots/android/ (menimpa slide editor)
# Opsi: DEVICE=<adb-id> untuk memilih device bila lebih dari satu.
#
# Data aman: tes memakai DB terpisah (kasir_resto_screenshot.sqlite) + prefs
# memori, data asli di device tidak disentuh. Hanya debug; tanpa internet (cek
# versi sengaja gagal cepat). Pasang folder `assets/demo/` untuk foto produk.
# Catatan: screenshot = permukaan Flutter saja (tanpa status bar sistem).
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FLUTTER=.fvm/flutter_sdk/bin/flutter
[ -x "$FLUTTER" ] || FLUTTER=flutter
MODE=""; TO_EDITOR=0
for a in "$@"; do
  case "$a" in
    --to-editor) TO_EDITOR=1 ;;
    phone|tablet|all) MODE="$a" ;;
    *) echo "Argumen tidak dikenal: $a"; exit 2 ;;
  esac
done

# Daftar device Android yang menyala.
devices() { adb devices | awk 'NR>1 && $2=="device" {print $1}'; }

# Ukuran sisi terpendek device (px).
short_side() {
  adb -s "$1" shell wm size | grep -Eo '[0-9]+x[0-9]+' | tail -1 |
    awk -F x '{print ($1<$2)?$1:$2}'
}

pick_device() { # $1 = phone|tablet|"" -> echo id
  local id want="$1" first=""
  if [ -n "${DEVICE:-}" ]; then echo "$DEVICE"; return; fi
  for id in $(devices); do
    [ -z "$first" ] && first="$id"
    local s; s=$(short_side "$id")
    if [ "$want" = phone ] && [ "$s" -lt 1400 ]; then echo "$id"; return; fi
    if [ "$want" = tablet ] && [ "$s" -ge 1400 ]; then echo "$id"; return; fi
  done
  [ -z "$want" ] && echo "$first"
}

run_one() { # $1 = phone|tablet
  local kind="$1" id out
  id=$(pick_device "$kind")
  if [ -z "$id" ]; then
    echo "Tidak ada device $kind yang menyala. Nyalakan emulatornya lalu ulangi."
    return 1
  fi
  out="screnshoot/$kind"
  rm -rf "$out"; mkdir -p "$out"
  echo "== $kind di $id -> $out"
  # Status bar rapi (demo mode); selalu dimatikan lagi.
  adb -s "$id" shell settings put global sysui_demo_allowed 1 || true
  trap 'adb -s "$id" shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null 2>&1 || true' RETURN
  for c in "clock -e hhmm 0941" "battery -e level 100 -e plugged false" \
           "network -e wifi show -e level 4" "network -e mobile show -e datatype none -e level 4" \
           "notifications -e visible false"; do
    adb -s "$id" shell am broadcast -a com.android.systemui.demo -e command ${c%% *} ${c#* } >/dev/null 2>&1 || true
  done
  SCREENSHOT_DIR="$out" "$FLUTTER" drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/screenshots_test.dart \
    -d "$id" --no-dds \
    --dart-define=REMOTE_BASE_URL=https://localhost.invalid
  if [ "$TO_EDITOR" = 1 ]; then
    # Urutan slide editor: HP 6 slide (04..09), tablet 4 slide (04,05,07,08).
    local base=store_assets/public/screenshots/android n=0 src dst
    if [ "$kind" = phone ]; then
      for src in 04_kasir 05_rincian_bayar 06_struk 07_laporan 08_pengeluaran 09_produk; do
        n=$((n+1)); dst="$base/phone/id"; mkdir -p "$dst"
        cp "$out/$src.png" "$dst/$(printf %02d $n).png"
      done
    else
      for src in 04_kasir 05_rincian_bayar 07_laporan 08_pengeluaran; do
        n=$((n+1))
        for d in tablet-10 tablet-7; do
          dst="$base/$d/landscape/id"; mkdir -p "$dst"
          cp "$out/$src.png" "$dst/$(printf %02d $n).png"
        done
      done
    fi
    echo "Disalin ke $base (urutan slide editor)"
  fi
}

case "${MODE:-}" in
  all)
    run_one phone
    read -r -p "Nyalakan emulator TABLET (matikan HP), lalu Enter..." _
    run_one tablet ;;
  phone|tablet) run_one "$MODE" ;;
  *) # tebak dari device yang menyala
    id=$(pick_device ""); [ -n "$id" ] || { echo "Tidak ada device menyala."; exit 1; }
    [ "$(short_side "$id")" -ge 1400 ] && run_one tablet || run_one phone ;;
esac

echo "Hasil:"
ls -1 screnshoot/phone/*.png screnshoot/tablet/*.png 2>/dev/null || true

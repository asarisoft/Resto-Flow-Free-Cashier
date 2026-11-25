#!/usr/bin/env bash
# Build rilis KasirKita: pilih versi + jenis build, cek signing, simpan versi ke pubspec.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"
FLUTTER=".fvm/flutter_sdk/bin/flutter"
[[ -x "$FLUTTER" ]] || FLUTTER="flutter"

CURRENT="$(grep -E '^version:' pubspec.yaml | awk '{print $2}')"
CUR_NAME="${CURRENT%%+*}"
CUR_BUILD="${CURRENT##*+}"

read -r -p "Version name [$CUR_NAME]: " NAME
NAME="${NAME:-$CUR_NAME}"
read -r -p "Build number [$((CUR_BUILD + 1))]: " BUILD
BUILD="${BUILD:-$((CUR_BUILD + 1))}"
[[ "$BUILD" =~ ^[0-9]+$ ]] || { echo "Build number harus angka." >&2; exit 1; }

echo "Jenis build:"
echo "  1) production-aab (Play Store)"
echo "  2) production-apk"
echo "  3) debug-apk"
read -r -p "Pilih nomor: " CHOICE
case "$CHOICE" in
  1) KIND="production-aab" ;;
  2) KIND="production-apk" ;;
  3) KIND="debug-apk" ;;
  *) echo "Pilihan tidak valid." >&2; exit 1 ;;
esac

if [[ "$KIND" != "debug-apk" ]]; then
  PROPS="android/key.properties"
  [[ -f "$PROPS" ]] || { echo "Tidak ada $PROPS (lihat docs/RELEASE.md)." >&2; exit 1; }
  prop() { grep -E "^$1=" "$PROPS" | cut -d= -f2- || true; }
  for k in storeFile storePassword keyAlias keyPassword; do
    [[ -n "$(prop "$k")" ]] || { echo "$k di $PROPS masih kosong." >&2; exit 1; }
  done
  STORE="$(prop storeFile)"
  STORE="${STORE/#\~/$HOME}"
  [[ -f "$STORE" ]] || { echo "Keystore tidak ditemukan: $STORE" >&2; exit 1; }
fi

ARGS=("--build-name=$NAME" "--build-number=$BUILD")
case "$KIND" in
  production-aab) "$FLUTTER" build appbundle --release "${ARGS[@]}"; OUT="build/app/outputs/bundle/release/app-release.aab" ;;
  production-apk) "$FLUTTER" build apk --release "${ARGS[@]}"; OUT="build/app/outputs/flutter-apk/app-release.apk" ;;
  debug-apk)      "$FLUTTER" build apk --debug "${ARGS[@]}"; OUT="build/app/outputs/flutter-apk/app-debug.apk" ;;
esac

sed -i '' -E "s/^version: .*/version: $NAME+$BUILD/" pubspec.yaml
echo
echo "Build sukses: $NAME+$BUILD ($KIND)"
echo "File: $OUT"
echo "Ingat: naikkan latest_version_code (dan min_version_code bila wajib) di web_netlify/version.json ke $BUILD, lalu upload ke Netlify."

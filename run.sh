#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"
if command -v fvm >/dev/null 2>&1; then
  FLUTTER_CMD=(fvm flutter)
else
  FLUTTER_CMD=(flutter)
fi

# Android-only project: never fall back to macOS/iOS desktop.
DEVICE_ID="$("${FLUTTER_CMD[@]}" devices --machine 2>/dev/null | python3 -c '
import json, sys
try:
    devices = json.load(sys.stdin)
except Exception:
    devices = []
for d in devices:
    if str(d.get("targetPlatform", "")).startswith("android"):
        print(d.get("id", ""))
        break
')"

if [[ -z "$DEVICE_ID" ]]; then
  echo "Tidak ada device/emulator Android. Jalankan emulator dulu." >&2
  exit 1
fi

# Emulators often run low on disk. A per-ABI debug APK is much smaller than
# the universal one, so build that and hand it to `flutter run`.
ABI="$(adb -s "$DEVICE_ID" shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')"
case "$ABI" in
  arm64-v8a) APK="build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk" ;;
  armeabi-v7a) APK="build/app/outputs/flutter-apk/app-armeabi-v7a-debug.apk" ;;
  x86_64) APK="build/app/outputs/flutter-apk/app-x86_64-debug.apk" ;;
  *)
    echo "ABI Android tidak dikenal: $ABI" >&2
    exit 1
    ;;
esac

"${FLUTTER_CMD[@]}" build apk --debug --split-per-abi >/dev/null
exec "${FLUTTER_CMD[@]}" run -d "$DEVICE_ID" --use-application-binary="$APK" "$@"

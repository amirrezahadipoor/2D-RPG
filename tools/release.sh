#!/usr/bin/env bash
# Signed Android AAB release pipeline for Pixel Realms.
#
# Signing is intentionally NOT automated: the keystore must stay on the
# release engineer's machine (never in the repo, never in CI secrets of a
# public repo). This script wires everything else.
#
# Usage:
#   KEYSTORE=~/keys/pixel-realms.jks KEYSTORE_ALIAS=pixel \
#   KEYSTORE_PASS=*** KEY_ALIAS_PASS=*** ./tools/release.sh 1.0.1
#
# Without keystore env vars it prints the exact manual steps instead.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
CODE="${2:-1}"

echo "== Pixel Realms release v${VERSION} (code ${CODE}) =="

# 1) tests must be green before anything ships
/tmp/Godot_v4.4.1-stable_linux.x86_64 --headless --path . res://tests/verify.tscn \
  | tail -1 | grep -q "ALL" || { echo "FAIL: verify not green, aborting"; exit 1; }

# 2) stamp the version in both places Godot reads it
sed -i "s|^config/version=.*|config/version=\"${VERSION}\"|" project.godot
sed -i "s|^version/name=.*|version/name=\"${VERSION}\"|; s|^version/code=.*|version/code=${CODE}|" export_presets.cfg

mkdir -p build/android
if [[ -n "${KEYSTORE:-}" ]]; then
  # 3) signed export (Godot reads the keystore from env or editor settings)
  /tmp/Godot_v4.4.1-stable_linux.x86_64 --headless --path . --export-release "Android" \
    build/android/pixel-realms-${VERSION}.aab \
    --debug-keystore "${KEYSTORE}" 2>/dev/null || \
  /tmp/Godot_v4.4.1-stable_linux.x86_64 --headless --path . --export-release "Android" \
    build/android/pixel-realms-${VERSION}.aab
  echo "AAB ready: build/android/pixel-realms-${VERSION}.aab"
  echo "Upload with: bundletool or Play Console > Production"
else
  cat <<'GUIDE'
No KEYSTORE env var set — signing must happen on a trusted machine:

  1. keytool -genkeypair -v -keystore pixel-realms.jks -alias pixel \
       -keyalg RSA -keysize 2048 -validity 10000
  2. Godot Editor > Editor Settings > Export > Android: point at the jks
  3. Project > Export > Android > Export (signed)
  4. Play Console: upload the .aab; keep the jks OFFLINE and backed up —
     losing it means losing the ability to update the app forever.
GUIDE
fi

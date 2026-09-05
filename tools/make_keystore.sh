#!/usr/bin/env bash
# One-time release key for Pixel Realms (Cafe Bazaar / Play).
# Prints exactly what to paste into GitHub secrets. KEEP THE .jks OFFLINE:
# losing it means losing the ability to ever update the app.
set -euo pipefail
OUT="${1:-pixel-realms.jks}"
ALIAS="${2:-pixel}"
read -rsp "keystore password: " PASS; echo
read -rsp "again: " PASS2; echo
[ "$PASS" = "$PASS2" ] || { echo "passwords differ"; exit 1; }
keytool -genkeypair -v -keystore "$OUT" -alias "$ALIAS" -keyalg RSA \
  -keysize 2048 -validity 10000 -storepass "$PASS" -keypass "$PASS" \
  -dname "CN=Pixel Realms, OU=Games, O=Hadipoor, C=IR"
echo
echo "now set these secrets on the repo (Settings > Secrets and variables > Actions):"
echo "  ANDROID_KEYSTORE_B64        = $(base64 -w0 "$OUT")"
echo "  ANDROID_KEYSTORE_PASSWORD   = <the password you just typed>"
echo "  ANDROID_KEY_ALIAS            = $ALIAS"
echo "  ANDROID_KEY_ALIAS_PASSWORD   = <same password>"
echo "or with gh:  gh secret set ANDROID_KEYSTORE_B64 < <(base64 -w0 $OUT)"

#!/bin/sh
# Full local verification for this project.
# Downloads the Godot 4.4.1 Linux binary if missing (it lives in /tmp, which
# is not persisted between sessions), imports once so the global class cache
# knows new scripts, then runs the 418+ check suite headless.
set -e
cd "$(dirname "$0")/.." || exit 1
BIN=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
if [ ! -x "$BIN" ]; then
  echo "downloading Godot 4.4.1 ..."
  mkdir -p /tmp/godot
  curl -sL -o /tmp/godot/g.zip "https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.x86_64.zip"
  unzip -o -q /tmp/godot/g.zip -d /tmp/godot
  chmod +x "$BIN"
fi
"$BIN" --headless --path . --import >/tmp/godot_import.log 2>&1 || true
"$BIN" --headless --path . res://tests/verify.tscn

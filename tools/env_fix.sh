#!/bin/sh
# Re-establish git identity/remote after a fresh sandbox: workspace snapshots
# exclude .git/config (credentials), so these vanish between sessions.
# Token is never stored; paste it at push time instead.
set -e
cd "$(dirname "$0")/.." || exit 1
git config user.name "amirrezahadipoor"
git config user.email "amirrezahadipoor@users.noreply.github.com"
git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/amirrezahadipoor/2D-RPG.git"
echo "git identity + remote ready (repo: $(git rev-parse --short HEAD))"

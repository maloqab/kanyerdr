#!/usr/bin/env bash
# Render dev/card.html (the gallery card) to kanyerdr/preview.png with headless Chrome.
# Uses the screenshots from dev/previews.sh. CHROME=<path> to pick another Chrome.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
chrome=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
[ -x "$chrome" ] || chrome=$(command -v google-chrome || command -v chromium || true)
[ -n "$chrome" ] || { echo "Chrome not found; set CHROME" >&2; exit 1; }
"$chrome" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
  --force-device-scale-factor=1.5 --window-size=1600,975 \
  --screenshot="$root/kanyerdr/preview.png" "file://$root/dev/card.html" 2>/dev/null
magick "$root/kanyerdr/preview.png" -strip "$root/kanyerdr/preview.png"
echo "wrote kanyerdr/preview.png"

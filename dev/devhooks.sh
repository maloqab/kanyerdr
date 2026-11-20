#!/usr/bin/env bash
# Add dev-only commands to a sandbox's copies of world-spaces and world-menu, so
# the space menu can be driven without a mouse. Never touches kanyerdr/.
#   herdr-app do world-spaces.devmenu   open the shown space's menu
#   herdr-app do world-menu.devdown     move the highlight down one row
#   herdr-app do world-menu.deventer    run the highlighted row (as Enter does)
# Usage: dev/devhooks.sh <sandbox-name>
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
mods="$root/dev/.sandbox-${1:?sandbox name}/app/mods"
python3 - "$mods" <<'PY'
import sys
mods = sys.argv[1]
def patch(path, imp_from, imp_to, anchor, hook):
    s = open(path).read()
    if "DEV ONLY" in s:
        return
    assert imp_from in s and anchor in s, path
    s = s.replace(imp_from, imp_to, 1).replace(anchor, anchor + hook, 1)
    open(path, "w").write(s)
patch(f"{mods}/world-spaces/main.js", "import { spaces,", "import { nextCommand, spaces,",
      "  init(_props, cx) {\n",
      '    cx.spawn(async (cx) => { for (;;) { const c = await nextCommand(); if (c === "devmenu") { const s = spaces().find((x) => x.active); if (s) this.menu(s); } } }); // DEV ONLY\n')
patch(f"{mods}/world-menu/main.js", "import { run,", "import { nextCommand, run,",
      "    this.handle.focus();\n",
      '    cx.spawn(async (cx) => { for (;;) { const c = await nextCommand(); if (c === "devdown") this.at++; if (c === "deventer") this.choose(this.at, cx); cx.notify(); } }); // DEV ONLY\n')
PY
echo "dev hooks added to $mods"

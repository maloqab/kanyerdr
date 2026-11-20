#!/usr/bin/env bash
# Make the README and gallery images in a throwaway sandbox Herdr.
#
#   ANTHROPIC_API_KEY=... dev/previews.sh            set up, shoot, compose
#   ANTHROPIC_API_KEY=... dev/previews.sh --setup    set up only (to look around)
#
# Claude Code needs to answer one demo prompt per world, so it needs an API key.
# With a key, its banner reads "API Usage Billing" and shows no account. The key
# is written to a 0600 file in the sandbox's /tmp folder, read only by the
# sandbox's shells, and deleted on exit. It is never written into the repo.
#
# Four demo spaces (api, web, docs, infra) are dealt the four worlds in order.
# Each has a split tab: a shell on the left, Claude Code on the right.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
: "${ANTHROPIC_API_KEY:?set ANTHROPIC_API_KEY (an API key, not a subscription login)}"

name=p
box="$root/dev/.sandbox-$name"
short="/private/tmp/kyd-$name"
demo="$short/home"
out="$root/kanyerdr/previews"
setup_only=${1:-}
SPACES=(api web docs infra)
WORLDS=(study-hall the-palace launch-pad cold-room)
PROMPT_TEXT="summarize this repo's README in two sentences"

app() { (eval "$("$root/dev/sandbox.sh" env $name)"; herdr-app "$@"); }
core() { (eval "$("$root/dev/sandbox.sh" env $name)"; hc "$@"); }
# A background window only draws (and runs its mods) when asked for a frame.
frames() { for _ in 1 2 3; do app shot "$short/frame.png" >/dev/null; sleep 0.4; done; }
status() { app status | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);console.log(j[process.argv[1]])})' "$1"; }

cleanup() {
  rm -f "$short/key"
  [ -n "$setup_only" ] || "$root/dev/sandbox.sh" stop $name >/dev/null 2>&1 || true
}
trap cleanup EXIT

# --- a clean sandbox -------------------------------------------------------
"$root/dev/sandbox.sh" stop $name >/dev/null 2>&1 || true
rm -rf "$box" "$short"
mkdir -p "$box/app" "$box/zdot" "$box/claude" "$demo"
version=$(herdr-app --version | awk '{print $2}')
echo '{"frame.welcomed":"finished","sidebar.collapsed":false,"sidebar.width":220}' > "$box/app/shared.json"
echo "{\"last_run\":\"$version\",\"presented\":[]}" > "$box/app/update-notes.json"
echo '{"zoom":1.0,"appearance":"dark","sounds":{"enabled":false}}' > "$box/app/settings.json"
echo '{"state":"windowed","bounds":[40.0,40.0,1600.0,1000.0]}' > "$box/app/window.json"
(umask 077; printf '%s' "$ANTHROPIC_API_KEY" > "$short/key")

# --- demo repositories -----------------------------------------------------
commit() { GIT_AUTHOR_NAME=demo GIT_AUTHOR_EMAIL=demo GIT_COMMITTER_NAME=demo GIT_COMMITTER_EMAIL=demo \
  GIT_AUTHOR_DATE="2026-01-0$2T10:00:00Z" GIT_COMMITTER_DATE="2026-01-0$2T10:00:00Z" git commit -qm "$1"; }
make_repo() { # name, one-line description, then files
  local dir="$demo/$1" desc=$2; shift 2
  mkdir -p "$dir" && cd "$dir" && git init -q -b main
  printf '# %s\n\n%s\n\n## Run it\n\n```sh\nmake dev\n```\n\n## Test\n\n```sh\nmake test\n```\n' "$(basename "$dir")" "$desc" > README.md
  git add README.md && commit "Add README" 1
  local i=2
  for f in "$@"; do mkdir -p "$(dirname "$f")"; printf '// %s\n' "$f" > "$f"; git add "$f"; commit "Add $f" $i; i=$((i + 1)); done
  cd "$root"
}
make_repo api   "A small HTTP API for the demo stack: users, sessions and a health check." src/server.js src/routes/users.js src/routes/health.js test/users.test.js
make_repo web   "The web front end for the demo stack, built with plain components." src/app.js src/pages/home.js src/pages/settings.js styles/main.css
make_repo docs  "Guides and reference for the demo stack, published as a static site." guide/getting-started.md guide/deploy.md reference/api.md
make_repo infra "Infrastructure for the demo stack: one database, two services, a load balancer." main.tf modules/db/main.tf modules/service/main.tf

# --- what every sandbox terminal runs at start -------------------------------
cat > "$box/zdot/extra.zsh" <<EOF
export DISABLE_AUTOUPDATER=1
[ -f "$short/key" ] && export ANTHROPIC_API_KEY="\$(cat "$short/key")"
. "$root/kanyerdr/claude-code/shell/kanyerdr.zsh"
palette() { for i in {0..15}; do printf '\e[48;5;%sm   \e[0m' \$i; [ \$i = 7 ] && echo; done; echo; }
EOF
# Claude Code: past first-run, the key approved, the demo folders trusted.
KEY_TAIL="${ANTHROPIC_API_KEY: -20}" node -e '
const [dir, demo, ...names] = process.argv.slice(1);
const keyTail = process.env.KEY_TAIL;
const projects = Object.fromEntries(names.map((n) => [`${demo}/${n}`, { hasTrustDialogAccepted: true, hasCompletedProjectOnboarding: true }]));
require("fs").writeFileSync(`${dir}/.claude.json`, JSON.stringify({
  hasCompletedOnboarding: true, lastOnboardingVersion: "9.9.9", theme: "dark-ansi",
  customApiKeyResponses: { approved: [keyTail], rejected: [] }, projects }, null, 2));
' "$box/claude" "$demo" "${SPACES[@]}"

SANDBOX_HOME="$demo" "$root/dev/sandbox.sh" start $name >/dev/null
frames
app do layout.switch '{"name":"study-hall"}' >/dev/null

# --- spaces: shell left, Claude Code right -----------------------------------
declare -A CLAUDE_T CLAUDE_P SHELL_T SPACE_ID
for i in 0 1 2 3; do
  s=${SPACES[$i]}
  SPACE_ID[$s]=$(app do space.new "{\"name\":\"$s\",\"folder\":\"$demo/$s\"}" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).space))')
  frames
  SHELL_T[$s]=$(core ls --json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const t=JSON.parse(s).terminals.filter(t=>t.where.startsWith(process.argv[1]+" /"));console.log(t[t.length-1].address)})' "$s")
  app do pane.split '{"direction":"right"}' >/dev/null
  frames
  CLAUDE_P[$s]=$(status focused_pane)
  CLAUDE_T[$s]=$(core ls --json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const t=JSON.parse(s).terminals.filter(t=>t.where.startsWith(process.argv[1]+" /"));console.log(t[t.length-1].address)})' "$s")
done
frames
for s in "${SPACES[@]}"; do
  core send "${SHELL_T[$s]}" "clear; git log --oneline --decorate; echo; ls -G; echo; palette" >/dev/null
  core send "${CLAUDE_T[$s]}" "clear; claude" >/dev/null
done
sleep 8
frames
for s in "${SPACES[@]}"; do core send "${CLAUDE_T[$s]}" "$PROMPT_TEXT" >/dev/null; done
for s in "${SPACES[@]}"; do core wait "${CLAUDE_T[$s]}" >/dev/null 2>&1 || true; done
frames

{ for s in "${SPACES[@]}"; do echo "$s space=${SPACE_ID[$s]} shell=${SHELL_T[$s]} claude=${CLAUDE_T[$s]} pane=${CLAUDE_P[$s]}"; done; } > "$short/map.txt"
if [ -n "$setup_only" ]; then
  echo "set up; sandbox $name left running. Map: $short/map.txt"
  exit 0
fi

# --- shots -------------------------------------------------------------------
# The window is 1600 logical px wide; shots come at the screen's scale (2x on a
# Retina Mac). Crops are given in logical px and scaled.
mkdir -p "$out"
# Let the "Claude Code finished" notifications time out before the first shot.
for _ in $(seq 1 30); do frames; [ "$(status overlays)" = "" ] && break; sleep 1; done
sleep 8; frames
for i in 0 1 2 3; do
  s=${SPACES[$i]} w=${WORLDS[$i]}
  app do space.select "{\"id\":\"${SPACE_ID[$s]}\"}" >/dev/null
  frames
  [ "$(status layout)" = "$w" ] || { echo "expected layout $w for $s, got $(status layout)" >&2; exit 1; }
  app shot "$short/$w.png" >/dev/null
  scale=$(( $(magick identify -format '%w' "$short/$w.png") / 1600 ))
  magick "$short/$w.png" -resize 2000x -strip "$out/$w.png"
  # Claude Code on its own: zoom its pane, keep the world's frame around it.
  app do pane.zoom "{\"pane\":\"${CLAUDE_P[$s]}\"}" >/dev/null
  frames
  app shot "$short/$w-zoom.png" >/dev/null
  app do pane.zoom "{\"pane\":\"${CLAUDE_P[$s]}\"}" >/dev/null
  magick "$short/$w-zoom.png" -crop "$((1326 * scale))x$((888 * scale))+$((274 * scale))+$((38 * scale))" +repage \
    -resize 1600x -strip "$out/$w-claude.png"
done

# The space menu with World ▸, opened on "web" (The Palace).
"$root/dev/devhooks.sh" $name >/dev/null
app do space.select "{\"id\":\"${SPACE_ID[web]}\"}" >/dev/null
frames
app do world-spaces.devmenu >/dev/null
frames
app shot "$short/menu.png" >/dev/null
app do overlay.close '{"id":"world-menu"}' >/dev/null
magick "$short/menu.png" -crop "$((300 * scale))x$((330 * scale))+0+0" +repage -resize 600x -strip "$out/world-menu.png"

# The gallery card: the four worlds in a 2x2 grid.
tile() { magick "$out/$1.png" -resize 1000x -bordercolor '#0d0d0d' -border 8 "$short/tile-$1.png"; }
for w in "${WORLDS[@]}"; do tile "$w"; done
magick \( "$short/tile-study-hall.png" "$short/tile-the-palace.png" +append \) \
  \( "$short/tile-launch-pad.png" "$short/tile-cold-room.png" +append \) -append \
  -bordercolor '#0d0d0d' -border 8 -strip "$root/kanyerdr/preview.png"

ls -l "$out" "$root/kanyerdr/preview.png"

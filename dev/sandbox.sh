#!/usr/bin/env bash
# Run a throwaway Herdr window that shares nothing with your own.
#
#   dev/sandbox.sh start <name> [--empty]   install kanyerdr/ and launch a window
#   dev/sandbox.sh env <name>               print exports for herdr-app / hc
#   dev/sandbox.sh stop <name>              quit the window and its core
#
# Everything lives in dev/.sandbox-<name>/: the app home (HERDR_APP_HOME),
# herdr-core's state and config (XDG_STATE_HOME, XDG_CONFIG_HOME, HC_SESSION)
# and a plain shell config (ZDOTDIR) so terminals show no personal prompt.
# The app is started with `env -i`, so nothing from your shell leaks in.
# --empty skips installing kanyerdr/ (used for the fresh-install test).
# SANDBOX_HOME=<dir> gives the window (and its terminals) that home folder, so
# paths read ~/… with nothing personal in them. If dev/.sandbox-<name>/zdot/extra.zsh
# exists, every terminal sources it (dev/previews.sh uses this).
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cmd=${1:-}
name=${2:-}
[ -n "$cmd" ] && [ -n "$name" ] || { sed -n '2,13p' "$0"; exit 2; }
case "$name" in *[!a-z0-9-]*) echo "name: use a-z, 0-9 and -" >&2; exit 2 ;; esac

box="$root/dev/.sandbox-$name"
# Unix sockets allow ~103 bytes, so the core's state gets a short path.
short="/tmp/kyd-$name"
app_bin=${HERDR_APP_BIN:-$(command -v herdr-app || true)}
path_dirs="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

envs() {
  cat <<EOF
export HERDR_APP_HOME='$box/app'
export XDG_CONFIG_HOME='$box/config'
export XDG_STATE_HOME='$short/state'
export XDG_RUNTIME_DIR='$short/run'
export HC_SESSION='kanyerdr-$name'
export HERDR_APP_ID='kanyerdr-$name'
export HERDR_APP_NO_SOUND=1
export HERDR_TELEMETRY=0
unset HC_TERMINAL_ID HC_SOCKET
EOF
}

case "$cmd" in
  env) envs ;;

  start)
    [ -x "$app_bin" ] || { echo "herdr-app not found on PATH" >&2; exit 1; }
    mkdir -p "$box"/{app,config/herdr-core,zdot,claude} "$short"/{state,run}
    if [ "${3:-}" != "--empty" ]; then
      for d in layouts themes mods; do
        mkdir -p "$box/app/$d"
        cp -R "$root/kanyerdr/$d/." "$box/app/$d/"
      done
    fi
    # Skip the first-run welcome card so screenshots show the layout.
    [ -f "$box/app/shared.json" ] || echo '{"frame.welcomed":"finished"}' > "$box/app/shared.json"
    # Plain shell for terminals: no personal prompt, history or aliases.
    cat > "$box/zdot/.zshrc" <<'EOF'
PROMPT='%F{4}%1~%f %F{5}$%f '
unset HISTFILE
[ -f "$ZDOTDIR/extra.zsh" ] && . "$ZDOTDIR/extra.zsh"
EOF
    printf 'shell = ["zsh"]\nnotes = false\n' > "$box/config/herdr-core/config.toml"
    # Claude Code, if started in the sandbox, uses its own config dir.
    mkdir -p "$box/claude"
    if [ "${3:-}" != "--empty" ]; then
      mkdir -p "$box/claude/themes"
      cp "$root/kanyerdr/claude-code/themes/"*.json "$box/claude/themes/"
    fi
    # shellcheck disable=SC2046
    app_home=${SANDBOX_HOME:-$HOME}
    env -i HOME="$app_home" XDG_DATA_HOME="$HOME/.local/share" USER="${USER:-}" LOGNAME="${LOGNAME:-}" TERM=xterm-256color \
      LANG="${LANG:-en_US.UTF-8}" PATH="$path_dirs" SHELL=/bin/zsh \
      ZDOTDIR="$box/zdot" CLAUDE_CONFIG_DIR="$box/claude" \
      $(envs | sed -n "s/^export \([A-Z_]*\)='\{0,1\}\([^']*\)'\{0,1\}$/\1=\2/p") \
      nohup "$app_bin" > "$box/app.log" 2>&1 &
    echo $! > "$box/app.pid"
    sleep 4
    echo "sandbox $name running (pid $(cat "$box/app.pid")). Talk to it with:"
    echo "  eval \"\$(dev/sandbox.sh env $name)\""
    ;;

  stop)
    if [ -f "$box/app.pid" ]; then
      kill "$(cat "$box/app.pid")" 2>/dev/null || true
      rm -f "$box/app.pid"
    fi
    # Refuse to stop a core unless it is provably the sandbox's own.
    live_id=$(sed -n 's/.*"id": *"\([0-9a-f]*\)".*/\1/p' "$HOME/.local/state/herdr-core/default/core.json" 2>/dev/null || true)
    box_id=$(eval "$(envs)"; hc server status --json 2>/dev/null | sed -n 's/.*"core":{"id":"\([0-9a-f]*\)".*/\1/p')
    if [ -n "$box_id" ] && [ "$box_id" != "$live_id" ] && [ -S "$short/run/herdr-core/kanyerdr-$name.sock" ]; then
      (eval "$(envs)"; hc server stop >/dev/null 2>&1 || true)
    else
      echo "not stopping a core: could not prove it is the sandbox's" >&2
    fi
    echo "sandbox $name stopped"
    ;;

  *) sed -n '2,13p' "$0"; exit 2 ;;
esac

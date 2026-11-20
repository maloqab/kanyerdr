# kanyerdr: start Claude Code in the theme of the Herdr world this terminal is in.
# Source this file from your shell rc. Outside a kanyerdr world, `claude` runs as usual.
#
# The worlds mod labels every terminal kanyerdr.world=<world>; this reads the
# label with `hc get` and passes the theme for this session only (--settings),
# so your global Claude Code settings never change.

# An existing `claude` alias is replaced by the function below. If that alias was
# the only way to reach Claude Code (its old ~/.claude/local install), keep using it.
_kanyerdr_claude_alias=$(alias claude 2>/dev/null)
if [ -n "$_kanyerdr_claude_alias" ]; then
  eval "_kanyerdr_claude_alias=${_kanyerdr_claude_alias#*claude=}"
fi
unalias claude 2>/dev/null || true

function claude {
  local world="" json=""
  local -a run
  if [ -z "$(type -P claude 2>/dev/null)" ] && [ -n "$_kanyerdr_claude_alias" ]; then
    eval "run=($_kanyerdr_claude_alias)"
  else
    run=(command claude)
  fi
  if [ -n "${HC_TERMINAL_ID:-}" ] && command -v hc >/dev/null 2>&1; then
    if json=$(command hc get "$HC_TERMINAL_ID" --json 2>/dev/null); then
      world=$(printf '%s\n' "$json" | sed -n 's/.*"kanyerdr\.world": *"\([a-z-]*\)".*/\1/p' | head -n 1)
    fi
  fi
  case "$world" in
    study-hall|the-palace|launch-pad|cold-room)
      "${run[@]}" --settings "{\"theme\":\"custom:$world\"}" "$@" ;;
    *)
      "${run[@]}" "$@" ;;
  esac
}

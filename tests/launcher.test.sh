#!/usr/bin/env bash
# Tests for claude-code/shell/kanyerdr.{zsh,bash}, run under zsh and bash with
# fake hc and claude executables. Usage: bash tests/launcher.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
shells_dir="$here/../kanyerdr/claude-code/shell"
fakes="$here/fixtures/bin"
pass=0 fail=0
labels() { printf '{"address":"t1","labels":{"herdr.space":"sp1","kanyerdr.world":%s}}' "$1"; }

# run <shell> <prelude> <env...> -- <args...>: source the launcher, then call claude.
run() {
  local sh=$1 prelude=$2; shift 2
  local envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift
  local rc; rc=$(mktemp)
  {
    [ "$sh" = bash ] && echo 'shopt -s expand_aliases'
    printf '%s\n' "$prelude"
    echo "source '$shells_dir/kanyerdr.$sh'"
    echo 'claude "$@"'
  } > "$rc"
  env -i HOME="$HOME" "${envs[@]}" "$sh" -c ". '$rc'" _ "$@"
  rm -f "$rc"
}

check() {
  local name=$1 expected=$2 actual=$3
  if [ "$expected" = "$actual" ]; then pass=$((pass+1)); else
    fail=$((fail+1)); printf 'FAIL %s\n--- expected\n%s\n--- actual\n%s\n' "$name" "$expected" "$actual"; fi
}

P="PATH=$fakes:/usr/bin:/bin"
NOHC=$(mktemp -d); ln -s "$fakes/claude" "$NOHC/claude"
plain=$'-p\nhello world'
for sh in zsh bash; do
  check "$sh: world label adds the theme" $'--settings\n{"theme":"custom:cold-room"}\n-p\nhello world' \
    "$(run $sh '' "$P" HC_TERMINAL_ID=t1 "FAKE_HC_JSON=$(labels '"cold-room"')" -- -p 'hello world')"
  for w in study-hall the-palace launch-pad; do
    check "$sh: $w" "--settings"$'\n'"{\"theme\":\"custom:$w\"}" \
      "$(run $sh '' "$P" HC_TERMINAL_ID=t1 "FAKE_HC_JSON=$(labels "\"$w\"")" --)"
  done
  check "$sh: outside Herdr (no HC_TERMINAL_ID)" "$plain" \
    "$(run $sh '' "$P" "FAKE_HC_JSON=$(labels '"cold-room"')" -- -p 'hello world')"
  check "$sh: hc fails" "$plain" \
    "$(run $sh '' "$P" HC_TERMINAL_ID=t1 FAKE_HC_EXIT=1 -- -p 'hello world')"
  check "$sh: no label" "$plain" \
    "$(run $sh '' "$P" HC_TERMINAL_ID=t1 'FAKE_HC_JSON={"labels":{}}' -- -p 'hello world')"
  check "$sh: hostile label" "$plain" \
    "$(run $sh '' "$P" HC_TERMINAL_ID=t1 "FAKE_HC_JSON=$(labels '"evil\";rm -rf"')" -- -p 'hello world')"
  check "$sh: unknown world" "$plain" \
    "$(run $sh '' "$P" HC_TERMINAL_ID=t1 "FAKE_HC_JSON=$(labels '"main"')" -- -p 'hello world')"
  check "$sh: no hc on PATH" "$plain" \
    "$(run $sh '' "PATH=$NOHC:/usr/bin:/bin" HC_TERMINAL_ID=t1 -- -p 'hello world')"
  tricky=$'say "hi there"\n  it'"'"'s $HOME `x` \\n'
  check "$sh: arguments pass through byte for byte" "$tricky"$'\n'"--flag=a b" \
    "$(run $sh '' "$P" -- "$tricky" '--flag=a b')"
  check "$sh: a pre-existing alias is replaced, no recursion" "$plain" \
    "$(run $sh "alias claude='echo ALIAS'" "$P" -- -p 'hello world')"
  check "$sh: a pre-existing function is replaced, no recursion" "$plain" \
    "$(run $sh 'claude() { echo OLDFUNC; claude "$@"; }' "$P" -- -p 'hello world')"
  # Claude Code's old local install: claude is reachable only through an alias.
  HIDDEN=$(mktemp -d); cp "$fakes/claude" "$HIDDEN/claude"; cp "$fakes/hc" "$HIDDEN/hc-bin"
  ONLYHC=$(mktemp -d); ln -s "$fakes/hc" "$ONLYHC/hc"
  check "$sh: claude only reachable through an alias" "$plain" \
    "$(run $sh "alias claude='$HIDDEN/claude'" "PATH=$ONLYHC:/usr/bin:/bin" -- -p 'hello world')"
  check "$sh: alias-only claude still gets the world theme" $'--settings\n{"theme":"custom:launch-pad"}\n-p\nhello world' \
    "$(run $sh "alias claude='$HIDDEN/claude'" "PATH=$ONLYHC:/usr/bin:/bin" HC_TERMINAL_ID=t1 "FAKE_HC_JSON=$(labels '"launch-pad"')" -- -p 'hello world')"
  rm -rf "$HIDDEN" "$ONLYHC"
done
rm -rf "$NOHC"
echo "launcher tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

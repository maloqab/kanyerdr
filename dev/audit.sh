#!/usr/bin/env bash
# Fail if anything private or machine-specific is in the repo, or a JSON file
# doesn't parse.
#
#   dev/audit.sh                    check the working tree
#   dev/audit.sh --publish <rev>    also check every commit and commit message
#                                   reachable from <rev> (run before any push)
#
# Generic patterns (home paths, space ids, emails) are below. Names that are
# private to you (your name, machines, spaces) go one regex per line in
# dev/.private-patterns, which git ignores; they are matched ignoring case.
# --publish refuses to run without that file.
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
bad=0
hit() { echo "AUDIT: $1"; bad=1; }

publish_rev=""
if [ "${1:-}" = "--publish" ]; then
  publish_rev=${2:?usage: dev/audit.sh --publish <rev>}
  git rev-parse --verify --quiet "$publish_rev" >/dev/null || { echo "AUDIT: no such revision: $publish_rev"; exit 2; }
fi

generic='/Users/[A-Za-z]|/home/[a-z]|[Cc]:\\Users\\|sp[0-9a-f]{32}|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}'
allowed='noreply@anthropic\.com'
private_file="$root/dev/.private-patterns"
private=""
if [ -s "$private_file" ]; then
  private=$(grep -v '^\s*#' "$private_file" | grep -v '^\s*$' | paste -sd '|' -)
elif [ -n "$publish_rev" ]; then
  echo "AUDIT: --publish needs dev/.private-patterns (your private names, one regex per line)"; exit 2
else
  echo "note: no dev/.private-patterns; checking generic patterns only"
fi

files=$(git ls-files --cached --others --exclude-standard | grep -v '^dev/\.private-patterns$')
for f in $files; do
  [ -f "$f" ] || continue
  if [ -n "$private" ] && grep -qiE "$private" "$f" 2>/dev/null; then
    grep -niaE "$private" "$f" | head -5 | sed "s|^|AUDIT: private: $f:|"; bad=1
  fi
  if [ "$f" != dev/audit.sh ] && grep -qaE "$generic" "$f" 2>/dev/null; then
    lines=$(grep -naE "$generic" "$f" | grep -vE "$allowed")
    [ -n "$lines" ] && { printf '%s\n' "$lines" | head -5 | sed "s|^|AUDIT: generic: $f:|"; bad=1; }
  fi
done

# Machine-specific paths in what people install.
for f in $(printf '%s\n' "$files" | grep '^kanyerdr/'); do
  if grep -qaE '/opt/homebrew|~/Library|\.app/Contents' "$f"; then
    grep -naE '/opt/homebrew|~/Library|\.app/Contents' "$f" | sed "s|^|AUDIT: path: $f:|"; bad=1
  fi
done

# Every JSON file parses.
for f in $(printf '%s\n' "$files" | grep '\.json$'); do
  node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$f" 2>/dev/null || hit "bad JSON: $f"
done

# Image metadata must not carry paths or names either.
pngs=$(printf '%s\n' "$files" | grep -iE '\.png$')
if [ -n "$pngs" ]; then
  command -v magick >/dev/null || { hit "magick (ImageMagick) is needed to check image metadata"; pngs=""; }
  for f in $pngs; do
    meta=$(magick identify -verbose "$f" 2>/dev/null)
    if printf '%s\n' "$meta" | grep -qE "$generic" || { [ -n "$private" ] && printf '%s\n' "$meta" | grep -qiE "$private"; }; then
      hit "image metadata: $f"
    fi
  done
fi

# History: every file in every commit, and every commit message, about to be published.
if [ -n "$publish_rev" ]; then
  revs=$(git rev-list "$publish_rev")
  pattern="$private|$generic"
  # shellcheck disable=SC2086
  found=$(git grep -I -n -i -E "$pattern" $revs -- . ':!dev/audit.sh' ':!dev/.private-patterns' 2>/dev/null | grep -viE "$allowed" | head -10)
  [ -n "$found" ] && { printf '%s\n' "$found" | sed 's|^|AUDIT: history: |'; bad=1; }
  msgs=$(git log --format='%H %B' "$publish_rev" | grep -iE "$pattern" | grep -viE "$allowed" | head -5)
  [ -n "$msgs" ] && { printf '%s\n' "$msgs" | sed 's|^|AUDIT: commit message: |'; bad=1; }
fi

if [ "$bad" -eq 0 ]; then echo "audit passed"; else echo "audit FAILED"; exit 1; fi

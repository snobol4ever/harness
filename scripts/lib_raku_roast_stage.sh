#!/bin/bash
# lib_raku_roast_stage.sh -- THE ONE WAY A ROAST TEST IS STAGED FOR scrip (hq_raku 2026-10-14, row raku-roast-924-parse-failures-censused-
# by-first-error-class-the-diagnosis-row, CEO-1713). scrip picks the frontend by extension, so a roast .t is run as a .raku copy -- but a
# copy at $TMP/case.raku moved the program: `use lib $*PROGRAM.parent(2).add("packages/...")` resolved under $TMP and every type or
# routine a roast helper module exports was "undeclared" (4 of the 7 parse debts in corpus/tests/raku/config/ROAST-PARSE-CLASSES.tsv).
# roast_stage builds a MIRROR under the given work dir: the roast tree is COPIED once per work dir (8.7 MB, never a link -- CEO-1820), the
# test's own directory is re-copied per test, and the test is copied in beside its siblings as <stem>.raku -- so $*PROGRAM, $?FILE and relative paths
# resolve as they do in the roast tree. It prints the staged path. The cwd stays the caller's own empty scratch dir (the coo's
# 2026-10-09 rule: roast IO tests write where they stand, and a copy keeps every write in the scratch).
# Usage: . lib_raku_roast_stage.sh; stage=$(roast_stage "$ROAST" "$WORK" "$ROAST/S11-modules/lexical.t") || exit 2
roast_stage() {
  local root="$1" work="$2" src="$3" rel dir out b
  rel="${src#$root/}"; dir="$(dirname "$rel")"
  [ -f "$src" ] && [ -d "$root" ] || return 2
  if [ ! -f "$work/m/.staged_from" ] || [ "$(cat "$work/m/.staged_from")" != "$root" ]; then
    rm -rf "$work/m" && mkdir -p "$work/m" && cp -a "$root/." "$work/m/" && printf '%s\n' "$root" > "$work/m/.staged_from" || return 2
  fi
  out="$work/m"
  if [ "$dir" != "." ]; then
    out="$work/m/$dir"; rm -rf "$out" && mkdir -p "$out" && cp -a "$root/$dir/." "$out/" || return 2
  fi
  b="${rel##*/}"; b="${b%.t}.raku"; rm -f "$out/$b"; cp "$src" "$out/$b" || return 2
  printf '%s\n' "$out/$b"
}

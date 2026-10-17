#!/bin/bash
# lib_raku_roast_stage.sh -- THE ONE WAY A ROAST TEST IS STAGED FOR scrip (hq_raku 2026-10-14, row raku-roast-924-parse-failures-censused-
# by-first-error-class-the-diagnosis-row, CEO-1713). scrip picks the frontend by extension, so a roast .t is run as a .raku copy -- but a
# copy at $TMP/case.raku moved the program: `use lib $*PROGRAM.parent(2).add("packages/...")` resolved under $TMP and every type or
# routine a roast helper module exports was "undeclared" (4 of the 7 parse debts in corpus/tests/raku/config/ROAST-PARSE-CLASSES.tsv).
# roast_stage builds a MIRROR under the given work dir: every directory on the test's path is real, every other entry at each level is a
# symlink to the roast tree, and the test is copied in beside its siblings as <stem>.raku -- so $*PROGRAM, $?FILE and relative paths
# resolve as they do in the roast tree. It prints the staged path. The cwd stays the caller's own empty scratch dir (the coo's
# 2026-10-09 rule: roast IO tests write where they stand, and a write through a mirror symlink would land in the roast tree).
# Usage: . lib_raku_roast_stage.sh; stage=$(roast_stage "$ROAST" "$WORK" "$ROAST/S11-modules/lexical.t") || exit 2
roast_stage() {
  local root="$1" work="$2" src="$3" rel dir cur out comp e b
  rel="${src#$root/}"; dir="$(dirname "$rel")"
  [ -f "$src" ] && [ -d "$root" ] || return 2
  rm -rf "$work/m" && mkdir -p "$work/m" || return 2
  cur="$root"; out="$work/m"
  if [ "$dir" != "." ]; then
    local IFS=/
    for comp in $dir; do
      for e in "$cur"/* "$cur"/.[!.]*; do [ -e "$e" ] || continue; b="${e##*/}"; [ "$b" = "$comp" ] || ln -s "$e" "$out/$b"; done
      mkdir "$out/$comp" || return 2; cur="$cur/$comp"; out="$out/$comp"
    done
  fi
  for e in "$cur"/* "$cur"/.[!.]*; do [ -e "$e" ] || continue; ln -s "$e" "$out/${e##*/}"; done
  b="${rel##*/}"; b="${b%.t}.raku"; rm -f "$out/$b"; cp "$src" "$out/$b" || return 2
  printf '%s\n' "$out/$b"
}

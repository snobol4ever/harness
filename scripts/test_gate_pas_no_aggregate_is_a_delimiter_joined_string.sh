#!/usr/bin/env bash
# test_gate_pas_no_aggregate_is_a_delimiter_joined_string.sh -- no Pascal record, array or char array is stored or processed as a string
# joined by a separator byte (\x01 SOH, \x05, \001): every site in Pascal's own code that builds, splits, splices or decodes one is counted
# and printed, and the gate is GREEN only at zero.
# Lon 2026-09-28, in-chat to hq_pascal, verbatim: "Do not store records like that." then "Get rid of ALL delimited based processing like the
# one I just discovered." (after "What are seperator bytes? Are you storing data as tag delimited strings? Where are you doing that crazy thing?")
#
# POPULATION, declared rather than globbed: src/runtime/by_name_dispatch.c -- the builtins named __pas_*, arr_get and arr_set_pure (emitted
# by the Pascal lowerer alone: grep -rlw '"arr_get"' src/lower) and the C functions named pas_*; src/parsers/pascal/pascal.y and src/lower/lower_pascal_tree.c (the front end's semantic body since the pruned-parse-tree conversion moved it out of the parser); and
# src/lower/lower_common.c's norm_charseq (the shared string relop decoding Pascal's SOH-coded char arrays -- it serves no other encoding).
# A site is a line carrying SOH, '\x01', "\x01", '\x05' or \001 inside one of those bodies. Raku's delimited arrays and hashes (__rk_*,
# hash_*, push_pure, arr_init/last/tail ...) are hq_raku's and are NOT counted here.
# READ-ONLY, no build. rc 0 = zero sites; rc 1 = sites remain (each printed file:line [owner]); rc 2 = cannot measure.
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
BND="$ROOT/src/runtime/by_name_dispatch.c"; PY="$ROOT/src/parsers/pascal/pascal.y"; LC="$ROOT/src/lower/lower_common.c"; LT="$ROOT/src/lower/lower_pascal_tree.c"
for f in "$BND" "$PY" "$LC" "$LT"; do [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: $f is not on disk"; exit 2; }; done
PAT='SOH|\\\\x01|\\\\x05|\\\\001'
sites=$(
  awk -v pat="$PAT" -v F="src/runtime/by_name_dispatch.c" '
    /^[a-zA-Z].*\(.*\) *\{/ { c=$0; sub(/\(.*/,"",c); n=split(c,a," "); cur=a[n]; sub(/^\*/,"",cur) }
    /strcmp\(fn, "[^"]+"\)/ { x=$0; sub(/.*strcmp\(fn, "/,"",x); sub(/".*/,"",x); cur=x }
    $0 ~ pat && (cur ~ /^__pas_/ || cur ~ /^pas_/ || cur == "arr_get" || cur == "arr_set_pure") { print F ":" NR " [" cur "]" }' "$BND"
  awk -v pat="$PAT" -v F="src/parsers/pascal/pascal.y" '$0 ~ pat { print F ":" NR " [parser]" }' "$PY"
  awk -v pat="$PAT" -v F="src/lower/lower_pascal_tree.c" '$0 ~ pat { print F ":" NR " [elaborator]" }' "$LT"
  awk -v pat="$PAT" -v F="src/lower/lower_common.c" '
    /^static .*norm_charseq\(/ { inb=1 } inb && /^}/ { inb=0 }
    $0 ~ pat && (inb || /norm_charseq/) { print F ":" NR " [norm_charseq]" }' "$LC")
grep -q 'case "pas_\|strcmp(fn, "__pas_' "$BND" || { echo "⛔ GATE REFUSE(2) [$G]: found no __pas_ builtin in $BND -- the population moved; this census would read a false zero"; exit 2; }
n=$(printf '%s\n' "$sites" | grep -c . || true)
if [ "$n" = 0 ]; then echo "GATE PASS [$G]: 0 delimiter-joined aggregate sites in Pascal's code"; exit 0; fi
printf '%s\n' "$sites" | sed 's/^/  /'
echo "GATE FAIL(1) [$G]: $n delimiter-joined aggregate site(s) remain in Pascal's code (by owner: $(printf '%s\n' "$sites" | sed 's/.*\[\(.*\)\]/\1/' | sort | uniq -c | sort -rn | awk '{printf "%s %s; ", $2, $1}'))"
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit 1

#!/usr/bin/env bash
"$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_every_design_step_harness_takes_the_freshness_preflight.sh -- EVERY test_design_*_steps.sh CARRIES THE LINE-2 FRESHNESS PREFLIGHT AND STILL LISTS
# (CTO-553 (3), the cto 2026-11-08 11:4x CST: "the identical line 2 in every test_design_*_steps.sh that lacks it ... DONE-WHEN: grep -L of the preflight
# call over harness/scripts/test_design_*_steps.sh prints no file (red now) and --list of every harness still rc 0"; cut by officer_02 under CIO-7). MEASURED
# by the cto: 23 of 25 step harnesses had no util_require_fresh call, so a step DONE-WHEN graded a binary older than its tree (officer_01, 11:1x: step 23 read
# RED on a root synced and not rebuilt). Three arms over every harness/scripts/test_design_*_steps.sh:
#   preflight  the file names util_require_fresh.sh (the cto's grep -L over the file; the cut puts it on line 2, the two harnesses that had it keep theirs)
#   syntax     bash -n reads it rc 0
#   list       bash <it> --list exits 0. ONE NAMED EXCEPTION, MEASURED by officer_02 2026-11-08: a harness whose --list exits 2 printing "no step table at
#              <path>" with <path> absent from this root is LIST-UNREAD, named on the board and neither green nor red: test_design_random_codegen_scope_steps.sh
#              reads corpus/demos/scriptix/infinite_snobol4/STEPS.tsv, which is on origin but outside every sparse root (the !/demos/ rule), so it refused before
#              this cut and refuses after it. Any other non-zero --list is red.
# FAIL ONCE: red at harness ede1ad3e (23 files lack the call).
# EXIT: 0 every harness holds; 1 a harness red, named; 2 refused (no harness found).
set -u
G=test_gate_every_design_step_harness_takes_the_freshness_preflight
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/$G.XXXXXX")"; trap 'rm -rf "${T:?}"' EXIT
n=0; nopre=""; bad_syn=""; bad_list=""; unread=""
for f in "$HERE"/test_design_*_steps.sh; do
    [ -f "$f" ] || continue
    n=$((n + 1)); b="${f##*/}"
    grep -q 'util_require_fresh\.sh' "$f" || nopre="$nopre $b"
    bash -n "$f" 2> /dev/null || { bad_syn="$bad_syn $b"; continue; }
    ( cd "$ROOT" && timeout -k 5 120 bash "$f" --list ) > "$T/$b.log" 2>&1 < /dev/null; rc=$?
    [ "$rc" = 0 ] && continue
    p="$(grep -m1 -oE 'no step table at [^ ]+' "$T/$b.log" | sed 's/^no step table at //')"
    if [ "$rc" = 2 ] && [ -n "$p" ] && [ ! -e "$p" ]; then unread="$unread $b"; else bad_list="$bad_list $b:rc$rc"; fi
done
[ "$n" -gt 0 ] || { echo "⛔ REFUSE(2) [$G]: no harness/scripts/test_design_*_steps.sh found"; exit 2; }
c() { set -- $1; echo $#; }
echo "DESIGN_STEP_HARNESS_PREFLIGHT_BOARD harnesses=$n no_preflight=$(c "$nopre") syntax_red=$(c "$bad_syn") list_red=$(c "$bad_list") list_unread=$(c "$unread")${unread:+ unread=[${unread# }]} (tree $(git -C "$HERE/.." rev-parse --short HEAD 2>/dev/null))"
[ -n "$nopre" ] && echo "  no preflight:$nopre"
[ -n "$bad_syn" ] && echo "  syntax red:$bad_syn"
[ -n "$bad_list" ] && echo "  --list red:$bad_list"
[ -z "$nopre$bad_syn$bad_list" ] && { echo "GATE OK [$G]: every step harness of $n carries the freshness preflight and lists"; exit 0; }
echo "GATE FAIL [$G]: $(c "$nopre") without the preflight, $(c "$bad_syn") syntax red, $(c "$bad_list") --list red"; exit 1

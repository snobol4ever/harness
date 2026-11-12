#!/usr/bin/env bash
"$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_design_unicon_steps_grades_s4e_modes_and_refuses_stale.sh -- THE UNICON STEP HARNESS GRADES THE MODES S4E_MODES NAMES, DEFAULT m3,
# AND REFUSES A STALE BINARY (CIO-7, Lon 2026-11-08: "We will test mode 3 only until further notice."; officer_01's ruling to officer_02, 12:0x CST:
# test_design_unicon_steps.sh line 2 takes the stale-binary preflight, rc 2 when stale; the m4 block runs only when S4E_MODES names m4; GREEN needs
# every named mode; the VERDICT keeps m3= and m4=, an unrun mode printing skip). MEASURED by officer_01 11:1x: step 23 read RED on a root synced and
# not rebuilt, so every step DONE-WHEN graded an older program; and every step DONE-WHEN graded mode 4 whatever S4E_MODES said.
# THE READING IS THE RUN: each arm runs test_design_unicon_steps.sh --step N (N the first step --list names) and reads its rc and VERDICT line.
#   arm m3-default  S4E_MODES unset   -> a STEP line with m3=<p>/<n> and m4=skip
#   arm both        S4E_MODES=m3,m4   -> a STEP line with m3=<p>/<n> and m4=<p>/<n>
#   arm bad-mode    S4E_MODES=m5      -> rc 2, no STEP line
#   arm stale       a scratch root (a SCRIP worktree of this root's HEAD, its scrip and out/libscrip_rt.so copied and dated 2000-01-01, this
#                   harness/scripts and the witness folder copied) -> rc 2 and the preflight's line GATE UNPROVEN(2) [test_design_unicon_steps]
# The witnesses' verdicts are not read: a red witness grades its modes as surely as a green one.
# FAIL ONCE: on harness 45630426 arms m3-default (m4 graded), bad-mode (no mode knob, rc 0 or 1) and stale (graded, rc 0 or 1) read red.
# EXIT: 0 every arm holds; 1 an arm red, named; 2 refused (no harness, no step listed, no worktree, an arm printing no STEP line where one is owed).
set -u
G=test_gate_design_unicon_steps_grades_s4e_modes_and_refuses_stale
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"; H="$HERE/test_design_unicon_steps.sh"
WD="$ROOT/corpus/tests/icon/unicon"
[ -f "$H" ] || { echo "⛔ REFUSE(2) [$G]: no test_design_unicon_steps.sh beside the gate"; exit 2; }
ST="$ROOT/harness/designs/unicon/STEPS.tsv"
[ -f "$ST" ] || { echo "⛔ REFUSE(2) [$G]: no $ST"; exit 2; }
N="$(awk -F'\t' '!/^#/ && $1 != "step" && NF > 1 {print $1; exit}' "$ST")"
[ -n "$N" ] || { echo "⛔ REFUSE(2) [$G]: STEPS.tsv names no step"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/$G.XXXXXX")"
cleanup() { [ -d "$T/root/SCRIP" ] && git -C "$ROOT/SCRIP" worktree remove --force "$T/root/SCRIP" > /dev/null 2>&1; rm -rf "${T:?}"; }
trap cleanup EXIT
RED=0; NOTE=""
red() { RED=$((RED + 1)); NOTE="$NOTE $1"; }
run() {  # name, harness path, S4E_MODES value or "-" for unset -> sets RC and LINE
    if [ "$3" = - ]; then ( unset S4E_MODES; timeout -k 5 900 bash "$2" --step "$N" --out "$T/out.$1" ) > "$T/$1.log" 2>&1 < /dev/null; RC=$?
    else ( S4E_MODES="$3" timeout -k 5 900 bash "$2" --step "$N" --out "$T/out.$1" ) > "$T/$1.log" 2>&1 < /dev/null; RC=$?; fi
    LINE="$(grep -m1 "^STEP $N " "$T/$1.log")"
}
run m3-default "$H" -
[ -n "$LINE" ] || { echo "⛔ REFUSE(2) [$G]: arm m3-default (rc $RC) printed no STEP line:"; tail -3 "$T/m3-default.log"; exit 2; }
grep -qE ' m3=[0-9]+/[0-9]+ ' <<<"$LINE" && grep -qE ' m4=skip ' <<<"$LINE" || red "m3-default:${LINE// /_}"
run both "$H" m3,m4
[ -n "$LINE" ] || { echo "⛔ REFUSE(2) [$G]: arm both (rc $RC) printed no STEP line:"; tail -3 "$T/both.log"; exit 2; }
grep -qE ' m3=[0-9]+/[0-9]+ ' <<<"$LINE" && grep -qE ' m4=[0-9]+/[0-9]+ ' <<<"$LINE" || red "both:${LINE// /_}"
run bad-mode "$H" m5
[ "$RC" = 2 ] && [ -z "$LINE" ] || red "bad-mode:rc$RC"
mkdir -p "$T/root/harness" "$T/root/corpus/tests/icon"
git -C "$ROOT/SCRIP" worktree add -q --detach "$T/root/SCRIP" HEAD > /dev/null 2>&1 || { echo "⛔ REFUSE(2) [$G]: cannot add a scratch SCRIP worktree"; exit 2; }
mkdir -p "$T/root/SCRIP/out"
cp -p "$ROOT/SCRIP/scrip" "$T/root/SCRIP/scrip" && cp -p "$ROOT/SCRIP/out/libscrip_rt.so" "$T/root/SCRIP/out/libscrip_rt.so" \
    && touch -d 2000-01-01 "$T/root/SCRIP/scrip" "$T/root/SCRIP/out/libscrip_rt.so" \
    && cp -r "$HERE" "$T/root/harness/scripts" && cp -r "$ROOT/harness/designs" "$T/root/harness/designs" && cp -r "$WD" "$T/root/corpus/tests/icon/unicon" \
    || { echo "⛔ REFUSE(2) [$G]: cannot build the stale fixture"; exit 2; }
run stale "$T/root/harness/scripts/test_design_unicon_steps.sh" -
[ "$RC" = 2 ] && grep -q 'GATE UNPROVEN(2) \[test_design_unicon_steps\]' "$T/stale.log" || red "stale:rc$RC"
echo "DESIGN_UNICON_STEPS_MODES_BOARD step=$N arms=4 red=$RED${NOTE:+ red_arms=$NOTE} (tree $(git -C "$HERE/.." rev-parse --short HEAD 2>/dev/null))"
[ "$RED" = 0 ] && { echo "GATE OK [$G]: the step harness grades mode 3 alone by default, m4 only when named, refuses an unknown mode and a stale binary"; exit 0; }
echo "GATE FAIL [$G]:$NOTE"; exit 1

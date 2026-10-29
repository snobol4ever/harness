#!/usr/bin/env bash
# test_probe_eval_code_end_terminates.sh -- ACCEPTANCE INSTRUMENT for task eval-code-end-terminates-m4.
#
# WHAT THIS CHECKS. A CODE() fragment whose OWN internal Goto is `:(END)` (the fragment terminates the
# whole program from inside its own flow, rather than transferring back to a label in the enclosing
# program) SIGSEGVs -- confirmed 2026-08-29 to crash in BOTH modes (rc=139), not "m4 only" as the
# original 2026-08-22 brief recorded -- the bug's own signature has drifted since it was minted.
# Live-oracle-verified correct behaviour (corpus/tests/snobol4/probe/eval.ref, entries 20-21): print
# exactly "before" then "in fragment", then terminate CLEANLY (rc=0) -- nothing more, no crash.
#
# Witnesses (both currently XFAIL entries 20/21 of corpus/tests/snobol4/probe/eval.sno):
#   ev_code_end_terminates  -- fragment entered via the direct code-object goto `:<C>`
#   ev_code_end_label_ctl   -- fragment entered via an ORDINARY label goto `:(INSIDE)` instead --
#                              proves the direct-goto grammar is not itself in the picture; the shared
#                              ingredient is only "the fragment's own internal goto target is END".
# Passing control (must stay green, not graded here since it already passes both modes today):
#   ev_code_back_ctl        -- identical shape but the fragment's own internal goto is `:(DONE)`, a
#                              real label back in the enclosing program -- proves the defect is
#                              specifically about the fragment's own END-transition, not CODE()/goto
#                              generally.
#
# ⛔ THIS TEST CURRENTLY FAILS BY DESIGN -- the underlying bug is NOT fixed as of this writing (see
# FINDING-2026-08-29-seat01-eval-code-end-terminates-mechanism-named-not-yet-fixed.md for the traced
# mechanism). It exists so a future fix has a real, computable, currently-red acceptance bar instead of
# the prose-only placeholder this row's DONE-WHEN used to be.
#
# USAGE: bash ../harness/scripts/test_probe_eval_code_end_terminates.sh
# EXIT:  0 = both witnesses print exactly "before"/"in fragment" and exit rc=0, BOTH modes (the bug is
#            fixed) | 1 = still crashing or wrong output | 2 = REFUSED, could not measure.
set -u
cd "$(dirname "$0")/../../SCRIP" || { echo "⛔ REFUSE rc=2: cannot reach SCRIP root"; exit 2; }
ROOT="$PWD"
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSE rc=2: ./scrip is not built."; exit 2; }
[ -f "$ROOT/out/libscrip_rt.so" ] || { echo "⛔ REFUSE rc=2: out/libscrip_rt.so missing -- mode-4 cannot link."; exit 2; }
WORK="$(mktemp -d)" || { echo "⛔ REFUSE rc=2: no scratch dir"; exit 2; }
trap 'rm -rf "$WORK"' EXIT
mkw() { printf '%s\n' "$2" > "$WORK/$1.sno"; }
mkw ev_code_end_terminates '        C = CODE("  OUTPUT = '"'"'in fragment'"'"' :(END)")
        OUTPUT = '"'"'before'"'"'                       :<C>
END'
mkw ev_code_end_label_ctl '        C = CODE("INSIDE OUTPUT = '"'"'in fragment'"'"' :(END)")
        OUTPUT = '"'"'before'"'"'                       :(INSIDE)
END'
EXPECTED="before
in fragment"
run_m3() { local w="$1"
    ( cd "$WORK" && timeout -k 5 8 "$ROOT/scrip" --run "$w.sno" </dev/null >"$w.m3.out" 2>"$w.m3.err" ); echo $?; }
run_m4() { local w="$1"
    if ( cd "$WORK" && timeout -k 5 8 "$ROOT/scrip" --compile --out="$w.s" "$w.sno" </dev/null ) >/dev/null 2>&1 \
       && ( cd "$WORK" && as -o "$w.o" "$w.s" ) >/dev/null 2>&1 \
       && ( cd "$WORK" && gcc -o "$w.bin" "$w.o" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" ) >/dev/null 2>&1; then
        ( cd "$WORK" && timeout -k 5 8 "./$w.bin" </dev/null >"$w.m4.out" 2>"$w.m4.err" ); echo $?
    else
        echo "NOBUILD"
    fi }
FAIL=0
for w in ev_code_end_terminates ev_code_end_label_ctl; do
    rc3="$(run_m3 "$w")"; got3="$(cat "$WORK/$w.m3.out" 2>/dev/null)"
    rc4="$(run_m4 "$w")"; got4="$(cat "$WORK/$w.m4.out" 2>/dev/null)"
    echo "$w:  m3 rc=$rc3 out='$got3'   m4 rc=$rc4 out='$got4'   (want rc=0, out='before / in fragment', both modes)"
    if [ "$rc3" != "0" ] || [ "$got3" != "$EXPECTED" ] || [ "$rc4" != "0" ] || [ "$got4" != "$EXPECTED" ]; then
        echo "  ⛔ not yet fixed (rc>=124 means a crash/timeout, not just wrong output)"; FAIL=1
    fi
done
echo "=== tree: $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?') ==="
if [ "$FAIL" -eq 0 ]; then echo "✅ ALL-GREEN — bug fixed"; exit 0; else echo "⛔ STILL RED — see above"; exit 1; fi

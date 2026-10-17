#!/usr/bin/env bash
# test_gate_pl_iso_rung9_a_backtrackable_recursion_reaches_the_depth_the_oracle_reaches.sh
#
# PROLOG ISO LADDER, RUNG 9 -- THE FRAME. A recursion whose calls leave a CHOICEPOINT must reach the depth
# the oracle reaches. Today it does not: a deterministic recursion runs to 200,000 levels and beyond, while a
# backtrackable one dies at ~29,000 on the default 8 MB stack, and the canonical Takeuchi kernel cannot run at
# its published size at all.
#
# ⛔ THE CLASS IS CAPACITY, NOT CORRECTNESS, AND THAT IS WHAT MAKES IT A FRAME DEFECT RATHER THAN AN ENGINE
# ONE. Every answer SCRIP produces here is RIGHT: tak(16,11,6,A) yields 11 and tak(18,12,6,A) yields 7 under a
# larger stack, both matching swipl. Nothing is mis-executed; the machine simply runs out of room at a size
# the oracle handles without comment. A gate that only graded answers would read this whole class as green.
#
# ⭐ THE TWO ARMS ARE A CONTRAST, AND THE CONTRAST IS THE FINDING -- neither arm means anything alone:
#   DET arm: p(N) :- N > 0, N1 is N-1, p(N1).           deterministic, 200,000 levels, PASSES TODAY.
#   CP  arm: p(N) :- N > 0, q(_), N1 is N-1, p(N1).     q/1 has two clauses, so every level retains a
#                                                        choicepoint. Dies between 28,000 and 30,000.
# Same shape, same depth, one extra goal. So this is NOT "deep recursion is expensive" -- deterministic frames
# ARE reclaimed and the last-call path works. It is that A FRAME BEHIND A CHOICEPOINT IS NEVER RECLAIMED and
# costs machine stack that is neither growable nor compact. The DET arm is therefore a mandatory CONTROL: if
# it ever goes red the cure has traded one capacity for another, which is not a cure.
#
# ⛔ MEASURED COST, because a rung should carry a number and not an adjective (cto 2026-09-13, default 8 MB):
#   simple CP witness  ~8.4 MB / ~29,000 levels   = ~289 BYTES per retained frame
#   tak(18,12,6)       ~200 MB / ~63,609 calls    = ~3.1 KB per retained frame
# The tak figure is the honest one for real code: its clause 1 (X =< Y) stays retryable at every level, so
# NOT ONE of its ~63,609 frames is ever reclaimed, and four arguments plus three intermediates make each frame
# an order of magnitude larger than the toy's. swipl runs the same program in a few MB because its
# choicepoints are compact records on a growable heap stack. Ours are machine-stack frames, by design
# (ARCH-ENGINE, the three zetas), and this rung is where that design first costs a real program.
#
# ⛔ THE STACK SIZE IS PART OF THE MEASUREMENT AND THE GATE PINS IT. Run under whatever `ulimit -s` the shell
# happens to carry and this gate grades the shell, not the compiler: tak(18,12,6) FAILS at 8/64/128 MB and
# PASSES at 256 MB, so an unpinned run can report either verdict truthfully. It therefore sets its own limit
# in a subshell and PRINTS it, and refuses rc=2 if it cannot.
#
# DONE-WHEN (all three, BOTH MODES, at the pinned default 8 MB):
#   1. DET control  p(200000)      completes                 -- passes today, must never regress
#   2. CP arm       p(100000)      completes                 -- red today (dies at 8,013 at this arm's pinned 8192 KB)
#   3. tak(18,12,6,A) yields A = 7                           -- red today (needs ~256 MB)
# EXIT 0 all green; 1 the rung is not yet met (names which arm); 2 REFUSED (cannot measure).
# ⛔⭐ A 4x UNIT ERROR OF MY OWN, CORRECTED HERE 2026-09-13 (cto), BECAUSE THIS GATE PUBLISHED IT.
# Until today this file's arm text and CTO-41 both said the CP arm "dies ~29,000; ~289 B per retained frame".
# THOSE TWO NUMBERS DO NOT DESCRIBE THE SAME RUN. The DEPTH was taken at `ulimit -s 32768` and the
# BYTES-PER-FRAME was computed by dividing 8 MB by it -- a 4x error, published side by side as if one run had
# produced both. Reproduced deliberately before correcting: the pre-cure compiler reaches 28,274 at 32768 KB,
# which is the ~29,000, and 1,186 B/frame there -- matching the 1,191 B/frame it reaches at 8192 KB. Both
# figures are now BISECTED at THIS ARM'S OWN PINNED LIMIT and carry the tree they were measured on.
# THE LESSON IS THE ONE THIS GATE ALREADY PINS ITS ulimit FOR, arriving one level up: pinning the limit stops
# the SHELL from grading the run, and does nothing about an ARITHMETIC that quietly uses a different limit
# than the measurement did. A number's divisor is part of its label.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
SCRIP="$ROOT/scrip"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE(2): no ./scrip at $SCRIP -- nothing was checked" >&2; exit 2; }
[ -e "$ROOT/out/libscrip_rt.so" ] || { echo "⛔ REFUSED-TO-GRADE(2): no runtime .so -- nothing was checked" >&2; exit 2; }
PIN_KB=8192
( ulimit -s "$PIN_KB" ) 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE(2): cannot pin the stack to ${PIN_KB} KB, so a verdict here would grade the shell and not the compiler" >&2; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/det.pl" <<'EOF'
:- initialization(main).
p(0) :- !.
p(N) :- N > 0, N1 is N - 1, p(N1).
main :- ( p(200000) -> write(det_ok) ; write(det_no) ), nl.
EOF
cat > "$W/cp.pl" <<'EOF'
:- initialization(main).
q(a). q(b).
p(0) :- !.
p(N) :- N > 0, q(_), N1 is N - 1, p(N1).
main :- ( p(100000) -> write(cp_ok) ; write(cp_no) ), nl.
EOF
cat > "$W/tak.pl" <<'EOF'
:- initialization(main).
tak(X,Y,Z,A) :- X =< Y, Z = A.
tak(X,Y,Z,A) :- X > Y, X1 is X-1, tak(X1,Y,Z,A1), Y1 is Y-1, tak(Y1,Z,X,A2),
                Z1 is Z-1, tak(Z1,X,Y,A3), tak(A1,A2,A3,A).
main :- ( tak(18,12,6,A) -> write(tak(A)) ; write(tak_no) ), nl.
EOF
run_one() {
    local mode="$1" src="$2" tag="$3"
    if [ "$mode" = m3 ]; then
        ( ulimit -s "$PIN_KB"; timeout -k 5 300 "$SCRIP" "$src" </dev/null 2>&1 )
    else
        ( ulimit -s "$PIN_KB"
          timeout -k 5 300 "$SCRIP" --compile -o "$W/$tag.s" "$src" </dev/null 2>&1 >/dev/null || exit 9
          cd "$W" && gcc -no-pie "$tag.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -o "$tag.bin" 2>&1 >/dev/null || exit 9
          timeout -k 5 300 "./$tag.bin" </dev/null 2>&1 )
    fi
}
echo "rung 9 -- the frame: a backtrackable recursion must reach the depth the oracle reaches"
echo "  stack pinned to ${PIN_KB} KB (an unpinned run grades the shell: tak fails at 8/64/128 MB, passes at 256 MB)"
fail=0
for mode in m3 m4; do
    det="$(run_one "$mode" "$W/det.pl" det_$mode)"
    cp_="$(run_one "$mode" "$W/cp.pl"  cp_$mode)"
    tk="$(run_one  "$mode" "$W/tak.pl" tak_$mode)"
    for pair in "det:$det" "cp:$cp_" "tak:$tk"; do
        case "${pair#*:}" in "") echo "⛔ REFUSED-TO-GRADE(2): ${pair%%:*} arm in $mode produced NO output at all -- that is not a measurement" >&2; exit 2;; esac
    done
    if printf '%s' "$det" | grep -q 'det_ok'; then echo "  ✅ CONTROL $mode -- deterministic recursion reaches 200,000 (must never regress)"
    else echo "  ⛔ CONTROL FAILED $mode -- deterministic recursion no longer reaches 200,000: $(printf '%s' "$det" | head -1)"; fail=$((fail+1)); fi
    if printf '%s' "$cp_" | grep -q 'cp_ok'; then echo "  ✅ OK      $mode -- a choicepoint-retaining recursion reaches 100,000"
    else echo "  FAIL      $mode -- a choicepoint-retaining recursion cannot reach 100,000 (BISECTED 2026-09-13 at this arm's own pinned 8192 KB: dies at 8,013, 1,046 B of machine stack per retained frame -- was 7,039 and 1,191 B before hq_U's zls_grant_locals cure at SCRIP 43aae1073): $(printf '%s' "$cp_" | head -1)"; fail=$((fail+1)); fi
    if printf '%s' "$tk" | grep -q 'tak(7)'; then echo "  ✅ OK      $mode -- tak(18,12,6,A) yields 7 at the default stack"
    else echo "  FAIL      $mode -- tak(18,12,6,A) does not complete at the default stack (BISECTED 2026-09-13: needs 140 MB, 2,320 B per retained frame over ~63,609 calls -- was 162 MB and 2,672 B before SCRIP 43aae1073): $(printf '%s' "$tk" | head -1)"; fail=$((fail+1)); fi
done
echo "------------------------------------------------------------"
if [ "$fail" -eq 0 ]; then echo "✅ GATE OK: rung 9 met -- backtrackable recursion reaches the oracle's depth in both modes"; exit 0; fi
echo "⛔ GATE FAILED: $fail arm(s) -- rung 9 is not yet met"
exit 1

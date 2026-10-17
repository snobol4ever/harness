#!/usr/bin/env bash
# test_gate_pl_an_opaque_goal_barrier_releases_the_frame_its_goal_carved.sh
#
# PROLOG, RUNG 9, THE GAMMA FENCE (CEO-690; Lon 2026-09-13, verbatim: "do a whack-free on GAMMA for a FENCE d
# (i.e. cut !) or otherwise FENCE d operation."). An OPAQUE-GOAL BARRIER -- once/1, the condition of an
# if-then-else, forall/2, (\+)/1 -- can never be re-entered by backtracking whatever its argument goal does,
# so the text of the call site alone proves beta is unreachable and every frame the goal carved is DEAD at
# gamma. Each of these is a cut in effect with no `!` in the text. Before hq_U's fence they were retained for
# a recession that can never come, at 822 to 1254 BYTES OF MACHINE STACK PER LEVEL; the same call lexically
# fenced with `!` cost nothing, which is what made this a defect and not a design limit.
#
# ⛔ THIS GATE GRADES CAPACITY, NOT ANSWERS, AND THAT IS THE WHOLE POINT. Every answer these programs produce
# was RIGHT before the cure and is right after it. A gate that only diffed output would read this entire class
# as green and has done, for as long as the class has existed.
#
# ⛔⭐ THE BUILTIN-GENERATOR ARM IS NOT A SIXTH COPY OF THE FIRST FOUR (cto, 2026-09-13). A barrier's
# reclamation is NOT uniform in the KIND of goal it wraps: findall over a 50-clause fact predicate reaches the
# ceiling while findall over between/3 with TWO solutions does not, so a cure could green every clause-defined
# row here and leave the builtin-generator half untouched with nothing in the table saying so. once_gen is in
# this set so that this instrument can produce that red. It is the arm that was added BEFORE the cure landed
# rather than after, which is the only order in which it is evidence.
#
# ⛔ THE STACK SIZE IS PART OF THE MEASUREMENT AND THIS GATE PINS IT. Unpinned, it grades the shell and not
# the compiler. It sets its own limit in a subshell, PRINTS it, and refuses rc=2 if it cannot.
#
# ⛔⭐⭐ THERE ARE TWO ANSWER-GRADED CONTROLS AND THE SECOND ONE WAS ADDED BECAUSE ITS ABSENCE SHIPPED A BUG.
# An unconditional release at every pinned IR_UNMARK reads GREEN on every depth arm below, on all four
# per-language smokes, and on the whole capacity table -- and it BREAKS THE SOFT CUT, because (*->)/2 is
# backtrack-TRANSPARENT into its condition (every solution of C runs T), so its unmark is a landing the
# machine RE-ENTERS rather than one it leaves. Measured 2026-09-14: test_gate_pl_iso_rung6 was GREEN at
# b6b42eee1 and RED with the unconditional form, and NOTHING ELSE IN THE FLEET SAW IT. OPACITY IS A LOWERER
# FACT and travels as a bit.
#
# ⛔⭐⭐ AND THERE IS NO TRANSPARENCY CONTROL IN THIS FILE, DELIBERATELY, BECAUSE I WROTE ONE AND PROVED IT
# COULD NOT FAIL. With the bug reintroduced on purpose (pl_lower_softcut's landings marked releasable), a
# local witness -- findall over ( q(X) *-> true ; X = none ) and over ( fail *-> Z = t ; c(Z) ), both graded
# by ANSWER against swipl -- read GREEN, and so did the same shapes written with if/3 standalone. The arm
# that reds is test_gate_pl_iso_rung6_the_soft_cut_if_3_predicate.sh, whose witness needs its WHOLE program
# to diverge: it reads [9] where the oracle reads [7,8,9] on `findall(Z, if((!, fail), b(_), c(Z)), L3)`,
# the fifth of twenty-six lines of one program. ⭐ A CONTROL THAT STAYS GREEN ON THE DEFECT IT NAMES IS
# WORSE THAN NO CONTROL, because the next reader counts it as coverage. THE TRANSPARENCY ARM FOR THIS CURE
# IS THAT GATE, BY NAME, and it is already wired and blocking; do not re-derive it here and do not copy its
# fixture.
#
# ⛔⭐ THE SAFETY CONTROL IS THE GRADING CRITERION AND NOT A FOOTNOTE (CEO-690, CEO-550). GAMMA IS THE SHARED
# YIELD PORT FOR SUSPEND AND RETURN, so a generator that suspends through gamma expects to be resumed INTO
# THAT VERY FRAME, and an unconditional whack tears down a frame a redo is about to re-enter. The control is a
# PAIR whose ANSWERS separate the two cases: q(X) un-fenced under a 3-deep recursion has 2^3 solutions and its
# frames MUST be retained; the same recursion with once(q(X)) has exactly 1 and its frames may be released.
# Both swipl-confirmed. IF THE CONTROL MOVES, THE CURE IS WRONG WHATEVER THE DEPTH ARMS SAY.
#
# DONE-WHEN: all five barrier witnesses complete at N=50000 in BOTH modes at the pinned limit (each died
# between 6,689 and 10,204 before the cure), AND the safety control still reads cp(8) once(1).
# EXIT 0 all green; 1 an arm is red (named); 2 REFUSED (could not measure -- never skip-as-success).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
SCRIP="$ROOT/scrip"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE(2): no ./scrip at $SCRIP -- nothing was checked" >&2; exit 2; }
[ -e "$ROOT/out/libscrip_rt.so" ] || { echo "⛔ REFUSED-TO-GRADE(2): no runtime .so -- nothing was checked" >&2; exit 2; }
PIN_KB=8192
N=50000
( ulimit -s "$PIN_KB" ) 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE(2): cannot pin the stack to ${PIN_KB} KB, so a verdict here would grade the shell and not the compiler" >&2; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mk() {
    cat > "$W/$1.pl" <<EOF
:- initialization(main).
q(1).
q(2).
r(_).
p(0) :- !.
p(N) :- N > 0, $2, N1 is N - 1, p(N1).
main :- ( p($N) -> write(ok) ; write(no) ), nl.
EOF
}
mk once_1      'once(q(_))'
mk if_then     '( q(_) -> true ; true )'
mk forall_2    'forall(q(X), r(X))'
mk negation    '\+ (q(_), fail)'
mk once_gen    'once(between(1,2,X))'
cat > "$W/safety.pl" <<'EOF'
:- initialization(main).
q(1).
q(2).
cp(0) :- !.
cp(N) :- N > 0, q(_), N1 is N - 1, cp(N1).
on(0) :- !.
on(N) :- N > 0, once(q(_)), N1 is N - 1, on(N1).
cnt(G, C) :- findall(x, G, L), length(L, C).
main :- cnt(cp(3), A), cnt(on(3), B), write(cp(A)), write(' '), write(once(B)), nl.
EOF
run_one() {
    local mode="$1" tag="$2"
    if [ "$mode" = m3 ]; then
        ( ulimit -s "$PIN_KB"; timeout -k 5 300 "$SCRIP" "$W/$tag.pl" </dev/null 2>&1 )
    else
        ( ulimit -s "$PIN_KB"
          timeout -k 5 300 "$SCRIP" --compile -o "$W/$tag.s" "$W/$tag.pl" </dev/null >/dev/null 2>&1 || exit 9
          cd "$W" && gcc -no-pie "$tag.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -o "$tag.$mode.bin" >/dev/null 2>&1 || exit 9
          timeout -k 5 300 "./$tag.$mode.bin" </dev/null 2>&1 )
    fi
}
echo "rung 9 -- an opaque-goal barrier releases the frame its goal carved"
echo "  stack pinned to ${PIN_KB} KB in a subshell · depth N=${N} · an unpinned run grades the shell, not the compiler"
fail=0; graded=0
for mode in m3 m4; do
    for pair in "once_1:once(q(_)):7348" "if_then:( q(_) -> true ; true ):7348" "forall_2:forall(q(X), r(X)):8568" "negation:\\+ (q(_), fail):10204" "once_gen:once(between(1,2,X)):8837"; do
        tag="${pair%%:*}"; rest="${pair#*:}"; body="${rest%:*}"; was="${rest##*:}"
        out="$(run_one "$mode" "$tag")"
        [ -n "$out" ] || { echo "⛔ REFUSED-TO-GRADE(2): $tag in $mode produced NO output at all -- that is not a measurement" >&2; exit 2; }
        graded=$((graded+1))
        if printf '%s' "$out" | grep -q '^ok$'; then echo "  ✅ OK   $mode $tag -- $body reaches $N (died at $was before the fence)"
        else echo "  ⛔ FAIL $mode $tag -- $body cannot reach $N; the barrier is retaining its goal's frame again (it died at $was before the fence): $(printf '%s' "$out" | head -1)"; fail=$((fail+1)); fi
    done
done
sc="$( ( ulimit -s "$PIN_KB"; timeout -k 5 300 "$SCRIP" "$W/safety.pl" </dev/null 2>&1 ) | head -1 )"
[ -n "$sc" ] || { echo "⛔ REFUSED-TO-GRADE(2): the safety control produced no output, so the depth arms above are ungraded" >&2; exit 2; }
graded=$((graded+1))
if [ "$sc" = "cp(8) once(1)" ]; then echo "  ✅ OK   SAFETY CONTROL -- $sc : un-fenced choicepoints are still LIVE and fenced ones are not (swipl agrees)"
else echo "  ⛔ FAIL SAFETY CONTROL -- read '$sc', expected 'cp(8) once(1)': the fence is releasing a frame a redo re-enters, and no depth above counts"; fail=$((fail+1)); fi
echo "------------------------------------------------------------"
[ "$graded" -gt 0 ] || { echo "⛔ REFUSED-TO-GRADE(2): graded ZERO witnesses -- a runner that cannot measure never prints the success shape" >&2; exit 2; }
if [ "$fail" -eq 0 ]; then echo "✅ GATE OK: $graded/$graded arms -- every opaque-goal barrier releases at gamma, and the safety control holds"; exit 0; fi
echo "⛔ GATE FAILED: $fail of $graded arm(s)"
exit 1

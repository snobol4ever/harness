#!/bin/bash
# test_gate_pl_a_retaining_if_then_else_inside_an_inline_between_loop_retries_its_generator_every_iteration_as_swipl.sh -- THE WRONG-ANSWER WITNESS OF
# SCRIP 850479705 (hq_zetas, the cto's ruling 2026-10-25 on hq_snobol4's speed reading, CEO-1680: red on the cure's parent, a proper test). A fail-driven loop over an inline between/3
# whose body is a retaining if-then-else with an observable effect (member/2 in the then arm, a write) must run every iteration: on 12ece7319 the inner gate re-entered at its stale beta and the
# loop printed w(1,a) w(1,b) done and stopped (its between/3 form hides the defect because its normal arm has no effect). The program is the witness and the expected output was cut from swipl 9.0.4.
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, or no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/gwi-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/gwi.pl" <<'PL'
:- initialization(main).
main :-
    ( between(1, 3, J), ( J > 0 -> member(X, [a, b]), write(w(J, X)), nl ; true ), fail ; true ), write(done), nl,
    ( between(1, 4, K), ( K > 2 -> member(Y, [p, q]), write(v(K, Y)), nl ; write(n(K)), nl ), fail ; true ), write(done2), nl,
    ( between(1, 2, A), between(A, A, _), ( A > 0 -> member(Z, [x, y]), write(u(A, Z)), nl ; true ), fail ; true ), write(done3), nl.
PL
cat > "$T/gwi.ref" <<'REF'
w(1,a)
w(1,b)
w(2,a)
w(2,b)
w(3,a)
w(3,b)
done
n(1)
n(2)
v(3,p)
v(3,q)
v(4,p)
v(4,q)
done2
u(1,x)
u(1,y)
u(2,x)
u(2,y)
done3
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/gwi.pl" "$T/gwi.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes run every iteration of the retaining if-then-else inside the between loop as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- a retaining if-then-else inside an inline between loop stopped or repeated an iteration in a mode"; exit 1;; esac

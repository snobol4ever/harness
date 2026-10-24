#!/bin/bash
# test_gate_pl_a_bare_bang_is_a_prefix_operator_when_declared_and_op_3_accepts_the_empty_list_in_the_swi_dialect.sh
# -- THE READER'S BANG AND NIL OPERATORS (ceo CEO-1959; row prolog-swi-core-test-read-every-case-agrees-with-swipl-in-both-modes-ceo-1664, SWI core/test_read.pl read_op:modify). In the SWI
# dialect `:- op(600, fy, !)` makes the cut atom a prefix operator -- `![]`, `![x]`, `! a`, `!!a` and `f(! a, b)` read as !/1 terms while `!`, `[!]` and `f(!)` stay the atom -- and
# `:- op(600, fy, [])` / `op(601, fy, [])` are accepted (SCRIP refused with permission_error(create, operator, []), and the directive form never registered a bare `!`) and change
# no list reading: `-[x]`, `[]` and `[a|T]` read as lists. The program is the witness and its ref was cut from swipl 10.1.5 (/home/resources/swipl-mon/bin/swipl); swipl 9.0.4 raises
# syntax_error(operator_balance) for `![x]` and `-[x]` (an oracle defect its upstream has fixed, EXCLUDED_CASES.tsv read_op:minus_block#1 and modify_block#1).
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, or no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/opb-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/opb.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
:- op(600, fy, !).
:- op(600, fy, []).
t(S, Pat) :- catch((term_string(T, S, []), (T = Pat -> writeln(S-ok) ; writeln(S-other))), error(E, _), (writeq(S-E), nl)).
main :-
    ( current_op(P, Ty, !) -> writeq(op(P, Ty)) ; write(no_bang_op) ), nl,
    catch((op(601, fy, []), writeln(op_nil_accepted)), error(E0, _), (writeq(E0), nl)),
    catch((op(602, fy, !), ( current_op(P1, _, !) -> writeq(bang(P1)) ; write(no_bang) ), nl), error(E1, _), (writeq(E1), nl)),
    t('![]', !([])), t('![x]', !([x])), t('! a', !(a)), t('!!a', !(!(a))), t('f(! a, b)', f(!(a), b)),
    t('-[x]', -([x])), t(' [ ] ', []), t('[a|T]', [a|_]), t('!(a)', !(a)), t('[!]', [!]), t('f(!)', f(!)),
    ( catch(term_string(Tcut, '!', []), _, fail) -> ( Tcut == ! -> writeln(bare_cut_atom) ; writeln(bare_other) ) ; writeln(bare_err) ).
PL
cat > "$T/opb.ref" <<'REF'
op(600,fy)
op_nil_accepted
bang(602)
![]-ok
![x]-ok
! a-ok
!!a-ok
f(! a, b)-ok
-[x]-ok
 [ ] -ok
[a|T]-ok
!(a)-ok
[!]-ok
f(!)-ok
bare_cut_atom
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/opb.pl" "$T/opb.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes read a declared bang as a prefix operator and accept op/3 on the empty list, as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- a declared bang or an op on [] does not read as swipl reads it"; exit 1;; esac

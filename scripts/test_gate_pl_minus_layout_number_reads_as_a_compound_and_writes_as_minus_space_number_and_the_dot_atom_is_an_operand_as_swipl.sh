#!/bin/bash
# test_gate_pl_minus_layout_number_reads_as_a_compound_and_writes_as_minus_space_number_and_the_dot_atom_is_an_operand_as_swipl.sh -- THE SWI DIALECT'S PREFIX MINUS BEFORE A NUMBER, READ AND WRITTEN, AND THE
# DOT ATOM AS AN OPERAND (hq_packages, ceo CEO-1959; Trealla's issues_old_test0368 writeq(-(1)) and issues_old_test0252 writeq(-'A'+(.)+'B'), refs cut by swipl, and SWI core/test_write.pl write_misc:q_1,
# whose term_to_atom round trip of -(0) the writer change alone would have broken).
# In the SWI dialect (swipl 9.0.4 and 10.1.5 alike): (1) the READER takes a minus as the sign of a number only when the number follows it DIRECTLY -- "-1" is the integer, "- 1", "-  1" and "-\n1" are the
# compound -(1) (integer(- 1) is false, - 1 =:= -1, - 1 == -1 is false); the default (GNU/ISO) dialect keeps folding across layout, as GNU Prolog does. (2) The WRITER writes a numeric operand of the prefix
# minus with one space and no parentheses: -(1) is "- 1", -(-(1)) is "- - 1", -(1.5) is "- 1.5", -(2^2) is "- 2^2", -(1r3) is "- 1r3", where SCRIP wrote "- (1)" (the ISO/GNU spelling, which GNU Prolog 1.4.5
# also writes). (3) The atom '.' is an operator (op(100, yfx, '.')) so as an operand it is embraced: +('.'), -('.'), 1-('.'), where SCRIP wrote +'.'.
# CURED in prolog_parse.c (the minus fold asks token adjacency in the SWI dialect), unification.c plc_wt (the prefix branch asks rt_pl_dialect_swi) and plc_is_op_atom ('.' is an operator atom there).
# The witness is the writer over 60 terms through writeq, print, write_canonical, write_term and write, the reader over 28 texts through term_to_atom and 11 source terms, and the arithmetic on them; the
# program carries the use_module marker that selects the SWI dialect. The ref was cut from swipl 9.0.4 and swipl 10.1.5 reads it byte-identically.
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/wmn-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/wmn.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
rt(S) :- term_to_atom(T, S), ( integer(T) -> K = int ; float(T) -> K = float ; compound(T) -> K = cmp ; K = other ), writeq(S-K-T), nl.
rd1 :- forall(member(S, ['- 1', '-1', '- 1.5', '-(1)', '- (1)', '-  1', '-\n1', '- 0', '-(-(1))', '- - 1', '1 - 1', '1 - -1', 'a- 1', '- a', '-(1)+2', '-0', '-0.0', '+ 1', '+1', '[- 1]', 'f(- 1)', '2 - 1', '- 1 + 2', '- 1 * 2', '-1 * 2', '- 1^2', '-1^2', '1 - - 1']), rt(S)).
rd2 :- forall(member(X, [- 1, - 1.5, -1, -1.5, - (1), 2 - 1, a- 1, [- 1], f(- 1), - 1 + 2, -(1) + 2]), kind(X)).
kind(X) :- writeq(X), ( integer(X) -> write(' int') ; float(X) -> write(' float') ; true ), nl.
rd3 :- X1 is - 1 + 5, writeq(X1), nl, X2 is -(1) * 3, writeq(X2), nl, X3 is - 1.5 + 2, writeq(X3), nl.
rd4 :- ( integer(- 1) -> writeq(yes) ; writeq(no) ), nl.
rd5 :- ( - 1 =:= -1 -> writeq(eq) ; writeq(ne) ), nl.
rd6 :- ( - 1 == -1 -> writeq(same) ; writeq(differ) ), nl.
rd :- rd1, rd2, rd3, rd4, rd5, rd6.
main :- rd, forall(member(X, [-(1), -(-(1)), -(1.5), -(-1), -(a), -(-(a)), -((a,b)), -(2^2), -(1+2), -(1r3), -(0), -(1)-(2), 1-(-(1)), a-(-(1)), - (-(-(1))), +(1), \(1), \+(1), -(f(1)), -([1]), -("s"), -('1'), -(1)*2, (-(1))^2, -(1^2), -(2)^2,
                        f(-(1)), [-(1)], {-(1)}, '.'+a, a+'.', -'.', '.'-'.', f('.'), ['.'], '.', {'.'}, +('.'), \+ '.', 1-'.', '.'*'.']), ( writeq(X), nl )),
        forall(member(X, [-(1), -(-(1)), -(1.5), -(2^2), '.'+a, f('.')]), ( print(X), nl, write_canonical(X), nl, write_term(X, [quoted(true), spacing(next_argument)]), nl, write(X), nl )).
PL
cat > "$T/wmn.ref" <<'REF'
'- 1'-cmp- - 1
'-1'-int- -1
'- 1.5'-cmp- - 1.5
'-(1)'-cmp- - 1
'- (1)'-cmp- - 1
'-  1'-cmp- - 1
'-\n1'-cmp- - 1
'- 0'-cmp- - 0
'-(-(1))'-cmp- - - 1
'- - 1'-cmp- - - 1
'1 - 1'-cmp-(1-1)
'1 - -1'-cmp-(1- -1)
'a- 1'-cmp-(a-1)
'- a'-cmp- -a
'-(1)+2'-cmp-(- 1+2)
'-0'-int-0
'-0.0'-float- -0.0
'+ 1'-cmp- +1
'+1'-cmp- +1
'[- 1]'-cmp-[- 1]
'f(- 1)'-cmp-f(- 1)
'2 - 1'-cmp-(2-1)
'- 1 + 2'-cmp-(- 1+2)
'- 1 * 2'-cmp- - 1*2
'-1 * 2'-cmp- -1*2
'- 1^2'-cmp- - 1^2
'-1^2'-cmp- -1^2
'1 - - 1'-cmp-(1- - 1)
- 1
- 1.5
-1 int
-1.5 float
- 1
2-1
a-1
[- 1]
f(- 1)
- 1+2
- 1+2
4
-3
0.5
no
eq
differ
- 1
- - 1
- 1.5
- -1
-a
- -a
- (a,b)
- 2^2
- (1+2)
- 1r3
- 0
- 1-2
1- - 1
a- - 1
- - - 1
+1
\1
\+1
-f(1)
-[1]
-"s"
-'1'
- 1*2
(- 1)^2
- 1^2
(- 2)^2
f(- 1)
[- 1]
{- 1}
('.')+a
a+('.')
- ('.')
('.')-('.')
f('.')
['.']
'.'
{'.'}
+ ('.')
\+ ('.')
1-('.')
('.')*('.')
- 1
-(1)
- 1
- 1
- - 1
-(-(1))
- - 1
- - 1
- 1.5
-(1.5)
- 1.5
- 1.5
- 2^2
-(^(2,2))
- 2^2
- 2^2
('.')+a
+('.',a)
('.')+a
(.)+a
f('.')
f('.')
f('.')
f(.)
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/wmn.pl" "$T/wmn.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes read a minus before layout and a number as a compound and write it, and the dot atom as an operand, as swipl does"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- the SWI dialect reader or writer differs from swipl on a prefix minus before a number or on the dot atom"; exit 1;; esac

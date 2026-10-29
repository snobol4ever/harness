#!/usr/bin/env bash
# test_gate_pl_a_thrown_ball_never_redoes_a_builtin_generator.sh -- a ball thrown after a builtin generator has
# answered must travel to its catch/3, never re-enter the generator as a redo (cto 2026-09-27, CTO-188, found by the
# pl2wam demo row prolog-demo-gnus-wam-compiler-pl2wam-...-ceo-1312).
#
# WHAT THIS PINS. SCRIP wires box N+1's omega to box N's beta, so a ball riding omega lands on the beta of every
# box to its left. ARCH-PROLOG-BYRD-BOX-TRANSLATION.md section A.1 review C9 put the ball test (test r15, r15 ; jne
# own omega) on every beta that can re-enter a RETAINED CALLEE and ruled that a generator leaf needs none because it
# holds no callee. That ruling is false for the IR_TO leaf: its beta IS a redo -- it bumps the counter and answers
# again. between/3, repeat/0 (lowered to between(1, INT64_MAX, _)), sub_atom/5, clause/2, retract/1 and the split
# mode of atom_concat/3 all lower to IR_TO, so in a COMPILED clause body a throw after any of them ran the rest of
# the body once per remaining answer and delivered the ball only when the generator was exhausted. Measured before
# the cure: between(1,3,X), write(X), throw(x) printed 1 2 3 and then caught(x); repeat, throw(x) never returned
# (6.29 million lines before the timeout) -- which is how GNU's pl2wam hung inside its read loop. The meta-called
# forms were already right, which is why no earlier witness saw it. The cure is the ball test on bb_to's Prolog
# beta, after the trail suffix is undone, exactly as bb_disjunction's step does it.
#
# THE REDO ROWS ARE THE CONTROL AND NOT DECORATION. A guard that fires on every beta passes every throw row and
# breaks every failure-driven loop, so each generator is also graded under plain failure, where it must redo.
#
# THE REF IS CUT FROM THE ORACLES: swipl 9 and GNU Prolog 1.6.0 print this text byte for byte (checked when the
# gate was written, 2026-09-27); an error ball is printed by its formal only, because the context term differs
# between them. When swipl is on the box the gate re-cuts the ref from it and refuses rc=2 on disagreement.
#
# RED BEFORE THE CURE (two-part proof, SCRIP 964982d54 with the bb_to change reverted): m3 rc=124, between printed
# 1 2 3 and repeat looped. GREEN AFTER: m3 and m4 byte-identical to the ref.
#
# Usage: bash ../harness/scripts/test_gate_pl_a_thrown_ball_never_redoes_a_builtin_generator.sh [--verbose]
set -uo pipefail
GATE_NAME=test_gate_pl_a_thrown_ball_never_redoes_a_builtin_generator
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
VERBOSE=0; for a in "$@"; do [ "$a" = --verbose ] && VERBOSE=1; done
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
command -v gcc >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: no gcc -- the mode-4 arm cannot be linked"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/w.pl" <<'PL'
:- initialization(main).
:- dynamic(f/1).
:- dynamic(g/1).
f(1). f(2). f(3).
g(1). g(2). g(3).
t(between) :- between(1, 3, X), write(X), nl, throw(x).
t(repeat) :- repeat, write(r), nl, throw(x).
t(sub_atom) :- sub_atom(abc, B, 1, _, S), write(B-S), nl, throw(x).
t(clause) :- clause(f(X), true), write(X), nl, throw(x).
t(atom_concat) :- atom_concat(A, B, ab), write(A+B), nl, throw(x).
t(between_throw_in_callee) :- between(1, 3, X), write(X), nl, thr.
t(between_undefined_callee) :- between(1, 3, X), write(X), nl, undefined_zz(X).
t(between_deep_callee) :- between(1, 3, X), write(X), nl, deep(X).
t(user_facts) :- g(X), write(X), nl, throw(x).
t(disjunction) :- (X = 1 ; X = 2 ; X = 3), write(X), nl, throw(x).
t(member) :- member(X, [a, b, c]), write(X), nl, throw(x).
t(retract) :- retract(f(X)), write(X), nl, throw(x).
t(redo_between) :- ( between(1, 3, X), write(X), nl, fail ; true ).
t(redo_repeat) :- flag_reset, repeat, bump(N), write(N), nl, N >= 3, !.
t(redo_sub_atom) :- ( sub_atom(abc, B, 1, _, S), write(B-S), nl, fail ; true ).
t(redo_clause) :- ( clause(g(X), true), write(X), nl, fail ; true ).
t(redo_atom_concat) :- ( atom_concat(A, B, ab), write(A+B), nl, fail ; true ).
t(redo_retract) :- assertz(h(1)), assertz(h(2)), ( retract(h(X)), write(X), nl, fail ; true ).
:- dynamic(h/1).
:- dynamic(cnt/1).
flag_reset :- retractall(cnt(_)), assertz(cnt(0)).
bump(N) :- retract(cnt(M)), N is M + 1, assertz(cnt(N)).
thr :- throw(x).
deep(X) :- X > 0, thr.
formal(error(F, _), F) :- !.
formal(B, B).
names([between, repeat, sub_atom, clause, atom_concat, between_throw_in_callee, between_undefined_callee, between_deep_callee, user_facts, disjunction, member, retract, redo_between, redo_repeat, redo_sub_atom, redo_clause, redo_atom_concat, redo_retract]).
main :- names(L), forall(member(N, L), (write(N), write(':'), nl, catch(t(N), E, (formal(E, F), write(caught(F)), nl)))), halt.
PL
cat > "$T/ref" <<'REF'
between:
1
caught(x)
repeat:
r
caught(x)
sub_atom:
0-a
caught(x)
clause:
1
caught(x)
atom_concat:
+ab
caught(x)
between_throw_in_callee:
1
caught(x)
between_undefined_callee:
1
caught(existence_error(procedure,undefined_zz/1))
between_deep_callee:
1
caught(x)
user_facts:
1
caught(x)
disjunction:
1
caught(x)
member:
a
caught(x)
retract:
1
caught(x)
redo_between:
1
2
3
redo_repeat:
1
2
3
redo_sub_atom:
0-a
1-b
2-c
redo_clause:
1
2
3
redo_atom_concat:
+ab
a+b
ab+
redo_retract:
1
2
REF
if command -v swipl >/dev/null; then
    ( cd "$T" && timeout -k 5 30 swipl -q w.pl < /dev/null > sw.out 2>/dev/null )
    cmp -s "$T/sw.out" "$T/ref" || { echo "⛔ REFUSED(2) [$GATE_NAME]: swipl no longer prints the ref this gate carries -- re-cut it from the oracle, never from SCRIP"; exit 2; }
    [ "$VERBOSE" = 1 ] && echo "  oracle: swipl re-cut agrees with the carried ref"
fi
fail=0
( cd "$T" && timeout -k 5 20 "$SCRIP" w.pl < /dev/null > m3.out 2>&1 ); rc3=$?
if cmp -s "$T/m3.out" "$T/ref"; then echo "  ok   (m3) every generator row delivers its ball on the first answer and every redo row redoes"; else echo "  FAIL (m3) rc=$rc3, first difference:"; diff "$T/ref" "$T/m3.out" | head -6 | sed 's/^/         /'; fail=1; fi
if ( cd "$T" && "$SCRIP" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 && gcc -o w w.s -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 20 ./w < /dev/null > m4.out 2>&1 ); rc4=$?
    if cmp -s "$T/m4.out" "$T/ref"; then echo "  ok   (m4) the same, from the standalone build"; else echo "  FAIL (m4) rc=$rc4, first difference:"; diff "$T/ref" "$T/m4.out" | head -6 | sed 's/^/         /'; fail=1; fi
else echo "  FAIL (m4) the witness did not compile or link in mode 4"; fail=1; fi
[ "$fail" = 0 ] && { echo "✅ GATE PASS [$GATE_NAME]: 18 rows x 2 modes answer as swipl and GNU Prolog 1.6.0 do"; exit 0; }
echo "⛔ GATE RED [$GATE_NAME]"; exit 1

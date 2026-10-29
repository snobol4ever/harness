#!/usr/bin/env bash
# test_gate_pl_catch_between_sub_atom_and_atom_concat_exit_deterministically_on_their_last_answer_as_swipl.sh -- catch/3 around a goal that leaves no
# choice, and between/3, sub_atom/5 and atom_concat/3 on their last answer, EXIT DETERMINISTICALLY, as swipl 9.0.4, m3 and m4 (cfo 2026-10-17, row
# prolog-catch-3-and-atom-concat-3-keep-a-choice-point-on-a-deterministic-exit-so-a-tail-loop-overflows).
# THE DEFECT: each kept its D1 choice header as B after its last answer -- catch/3's bound until the construct was failed out of, a trailed range
# (IR_TO 'ag:trl', which atom_concat/3, sub_atom/5 and between/3 lower to) until it stepped past its bound -- so setup_call_cleanup read the exit
# as nondeterministic, and a tail-recursive loop calling one could never pop its frame (cmp r13 against the frame at the tail call): 20000
# iterations died ERROR 246 at the shipped 4 MB stack where swipl prints done. THE CURE: the range restores B before its last value goes out
# (xa_to_trail_last), catch/3's goal exits through an IR_UNMARK arm (ival 8) that restores the banked B when B is still the bound's own header,
# and atom_concat(+,-,+) bounds its range at the length of its first argument, so its one answer is the range's last.
# CONTROLS, nondeterministic in both systems and graded so: atom_concat(-,-,+) and between(1,3,_). The semantic lines grade backtracking into a
# catch goal that has choices, a cut inside catch, a ball thrown by a range inside catch, and bindings undone after a deterministic exit.
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: the table below was cut 2026-10-17 from /usr/bin/swipl, and every run re-cuts it from the
# live swipl and REFUSES rc=2 when oracle and table disagree or swipl is absent.
# FAIL-ONCE (CEO-1680, a witness red on the commit before the cure): with the five cure files reverted on the same tree, m3 and m4 both read FAIL
# (measured 2026-10-17), and PASS=2 again once they were restored.
# NOT GRADED: atom_concat(-,+,+) -- swipl exits det, SCRIP's range still ends past the one answer (its lower bound would need computing).
# Usage: bash ../harness/scripts/test_gate_pl_catch_between_sub_atom_and_atom_concat_exit_deterministically_on_their_last_answer_as_swipl.sh
set -uo pipefail
GATE_NAME=test_gate_pl_catch_between_sub_atom_and_atom_concat_exit_deterministically_on_their_last_answer_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
cat > "$d/w.pl" <<'PL'
d(N, G) :- setup_call_cleanup(true, G, F = c), ( F == c -> R = det ; R = nondet ), writeq(N-R), nl.
t(N, G) :- ( catch(findall(G, G, L), E, (L = e(E))) -> true ; L = failed ), writeq(N-L), nl.
loop(_, 0) :- !.
loop(H, N) :- call(H), N1 is N-1, loop(H, N1).
h1 :- catch(nb_getval(k, _), _, true).
h2 :- atom_concat(ab, cd, _).
h3 :- atom_concat(ab, _, abcd).
p(X) :- catch(member(X, [1,2,3]), _, true).
q(X) :- catch((member(X, [1,2,3]), !), _, true).
s(R) :- ( catch(true, _, true), X = 1, fail ; var(X) -> R = undone ; R = kept(X) ).
u(R) :- ( atom_concat(ab, cd, A), A = abcd, X = 1, fail ; var(X) -> R = undone ; R = kept(X) ).
v(R) :- ( between(5, 5, B), X = B, fail ; var(X) -> R = undone ; R = kept(X) ).
z(X) :- catch((between(1, 3, X), X > 1, throw(hit(X))), hit(X), true).
main :- nb_setval(k, 0),
        d(catch, catch(nb_getval(k, _), _, true)), d(catch_true, catch(true, _, true)), d(atom_concat_ppm, atom_concat(ab, cd, _)),
        d(atom_concat_pmp, atom_concat(ab, _, abcd)), d(sub_atom, sub_atom(abc, 0, 1, _, _)), d(between_last, between(3, 3, _)),
        d(atom_concat_mmp, atom_concat(_, _, ab)), d(between, between(1, 3, _)),
        loop(h1, 20000), loop(h2, 20000), loop(h3, 20000), writeq(loops-done), nl,
        t(p, p(_)), t(q, q(_)), t(s, s(_)), t(u, u(_)), t(v, v(_)), t(z, z(_)), t(sub, sub_atom(abcab, _, 2, _, ab)),
        t(acpmp, atom_concat(abcde, _, abcd)), t(acmmp, atom_concat(_, _, abc)),
        halt.
:- initialization(main).
PL
cat > "$d/want" <<'WANT'
catch-det
catch_true-det
atom_concat_ppm-det
atom_concat_pmp-det
sub_atom-det
between_last-det
atom_concat_mmp-nondet
between-nondet
loops-done
p-[p(1),p(2),p(3)]
q-[q(1)]
s-[s(undone)]
u-[u(undone)]
v-[v(undone)]
z-[z(2)]
sub-[sub_atom(abcab,0,2,3,ab),sub_atom(abcab,3,2,0,ab)]
acpmp-[]
acmmp-[atom_concat('',abc,abc),atom_concat(a,bc,abc),atom_concat(ab,c,abc),atom_concat(abc,'',abc)]
WANT
(cd "$d" && timeout -k 5 60 "$SWIPL" -q w.pl </dev/null > "$d/oracle" 2>/dev/null)
cmp -s "$d/want" "$d/oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the expectation table is not what $SWIPL prints now"; diff "$d/want" "$d/oracle" | head -5; exit 2; }
fails=0; graded=0
(cd "$d" && timeout -k 5 60 "$SCRIP" w.pl </dev/null 2>/dev/null > "$d/m3"); rc=$?; graded=$((graded + 1))
if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs:"; diff "$d/want" "$d/m3" | head -12; fi
graded=$((graded + 1))
if (cd "$d" && timeout -k 5 60 "$SCRIP" --compile --out=w.s w.pl </dev/null >/dev/null 2>&1 \
    && gcc -no-pie -o w.bin w.s -L"$OUT" -lscrip_rt -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
    (cd "$d" && timeout -k 5 60 ./w.bin </dev/null 2>/dev/null > "$d/m4"); rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs:"; diff "$d/want" "$d/m4" | head -12; fi
else fails=$((fails + 1)); echo "  m4 did not compile or link"; fi
echo "PLDETLASTANSWER_BOARD programs=1 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0

#!/usr/bin/env bash
# test_gate_pl_an_unbounded_integer_is_an_integer_to_arg_functor_and_sub_atom.sh -- the ISO argument guards of arg/3, functor/3 and sub_atom/5
# read an unbounded integer as an integer, as swipl 9.0.4 does, m3 and m4 (cfo 2026-10-17, row
# prolog-arg-3-and-functor-3-reject-an-unbounded-integer-as-a-non-integer-before-the-sign-check, hq_prolog's 2026-09-16 finding).
# THE DEFECT: each guard tested its index or length for DT_I alone, so a DT_BIG -- an integer by integer/1 -- raised type_error(integer, Big)
# and the sign check after it never ran. arg/3 and functor/3 were cured on origin before this gate existed; sub_atom/5 was cured at the landing
# that adds this gate: a negative unbounded Before, Length or After raises domain_error(not_less_than_zero, N), one past size_t raises
# representation_error(size_t), and one between 2^63 and 2^64 (a bignum to SCRIP, a size_t to swipl) simply fails, as swipl.
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: the table below was cut 2026-10-17 from /usr/bin/swipl, and every run re-cuts it from the
# live swipl and REFUSES rc=2 when oracle and table disagree or swipl is absent. The program has no dialect marker: the ISO default, graded
# by swipl (CEO-1536). gprolog cannot read these literals at all ("integer overflow (exceeds max_integer)"), so it grades nothing here.
# NOT GRADED: functor(_, f, PositiveBig) -- ISO and the Logtalk unbounded suite (lgt_unbounded_functor_03) want representation_error(max_arity),
# which SCRIP gives; swipl gives representation_error(size_t). The ISO answer stands; the case is left out rather than graded against either.
# FAIL-ONCE (CEO-1680, a witness red on the commit before the cure): with the sub_atom/5 guard reverted on the same tree, m3 and m4 both read
# FAIL -- err(type_error(integer,18446744073709551616000)) or err(type_error(integer,-18446744073709551616000)) on all five sub_atom lines, the
# 2^63 + 5 Before included -- and PASS=2 again once it was restored (measured 2026-10-17).
# Usage: bash ../harness/scripts/test_gate_pl_an_unbounded_integer_is_an_integer_to_arg_functor_and_sub_atom.sh
set -uo pipefail
GATE_NAME=test_gate_pl_an_unbounded_integer_is_an_integer_to_arg_functor_and_sub_atom
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
t(G) :- catch((G -> R = yes ; R = no), error(E, _), R = err(E)), writeq(R), nl.
main :- B = 18446744073709551616000, N is -B, M is 2^63 + 5,
        t(integer(B)),
        t(arg(N, t(1,2,3), _)), t(arg(B, t(1,2,3), _)),
        t(functor(_, f, N)),
        t(sub_atom(abc, B, _, _, _)), t(sub_atom(abc, _, N, _, _)), t(sub_atom(abc, _, _, B, _)), t(sub_atom(abc, N, _, _, _)),
        t(sub_atom(abc, M, _, _, _)),
        halt.
:- initialization(main).
PL
cat > "$d/want" <<'WANT'
yes
err(domain_error(not_less_than_zero,-18446744073709551616000))
no
err(domain_error(not_less_than_zero,-18446744073709551616000))
err(representation_error(size_t))
err(domain_error(not_less_than_zero,-18446744073709551616000))
err(representation_error(size_t))
err(domain_error(not_less_than_zero,-18446744073709551616000))
no
WANT
(cd "$d" && timeout -k 5 30 "$SWIPL" -q w.pl </dev/null > "$d/oracle" 2>/dev/null)
cmp -s "$d/want" "$d/oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the expectation table is not what $SWIPL prints now"; diff "$d/want" "$d/oracle" | head -5; exit 2; }
fails=0; graded=0
(cd "$d" && timeout -k 5 30 "$SCRIP" w.pl </dev/null 2>/dev/null > "$d/m3"); rc=$?; graded=$((graded + 1))
if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs:"; diff "$d/want" "$d/m3" | head -10; fi
graded=$((graded + 1))
if (cd "$d" && timeout -k 5 60 "$SCRIP" --compile -o w.s w.pl </dev/null >/dev/null 2>&1 \
    && gcc -no-pie -o w.bin w.s -L"$OUT" -lscrip_rt -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
    (cd "$d" && timeout -k 5 30 ./w.bin </dev/null 2>/dev/null > "$d/m4"); rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs:"; diff "$d/want" "$d/m4" | head -10; fi
else fails=$((fails + 1)); echo "  m4 did not compile or link"; fi
echo "PLUNBOUNDEDGUARDS_BOARD programs=1 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0

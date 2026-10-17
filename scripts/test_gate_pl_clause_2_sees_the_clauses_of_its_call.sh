#!/usr/bin/env bash
# test_gate_pl_clause_2_sees_the_clauses_of_its_call.sh -- THE LOGICAL UPDATE VIEW FOR clause/2 AND retract/1 (ISO 7.5.4: a goal that iterates a
# dynamic predicate sees the clauses as they were when it was CALLED; a clause erased meanwhile is still visited, one added meanwhile is not).
# hq_prolog 2026-09-25, CEO-1270. THE BRACKET: Logtalk logical_update_semantics_clause_retract against gpx agreed to step 66 (the first pass through
# clause(cr(X),_), write(X), retract(cr(_)), fail) and diverged at step 67 -- gprolog resumed clause/2 at line 242 for X = 2, SCRIP fell to the
# else-branch at 245. The store kept erased slots in place but rt_pl_db_clause_at hid an erased slot from EVERY reader, including an iteration
# that began before the erase. The cure: an erase stamps its slot with the predicate's next_ref serial (nonzero), the enumeration reads $db_gen
# once at its call, and $db_at shows a slot born before that serial and not erased before it. After the cure the case agrees to its end (124).
# THE EXPECTATIONS ARE gprolog's and swipl's (2026-09-25): eight lines, both modes. RED BEFORE on origin, m3 AND m4: lines 1 and 3 read 1 and 12.
set -u
GATE_NAME=test_gate_pl_clause_2_sees_the_clauses_of_its_call
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/lu.pl" <<'EOP'
:- dynamic(cr/1).
:- dynamic(cs/1).
:- dynamic(ct/1).
:- dynamic(p/1).
cr(1). cr(2). cr(3).
cs(1). cs(2). cs(3).
ct(1). ct(2). ct(3).
p(1). p(2). p(3).
main :- ( clause(cr(X), true), write(X), retract(cr(_)), fail ; nl ),
        ( clause(cs(Y), true), write(Y), retract(cs(Y)), fail ; nl ),
        ( clause(ct(Z), true), write(Z), retract(ct(3)), fail ; nl ),
        ( clause(p(P), true), write(P), assertz(p(9)), fail ; nl ),
        ( retract(p(X2)), write(X2), fail ; nl ), ( p(W) -> write(W) ; write(empty) ), nl,
        assertz(q(1)), assertz(q(2)), ( retract(q(A)), write(A), assertz(q(3)), fail ; nl ),
        findall(B, q(B), Bs), write(Bs), nl.
:- initialization(main).
EOP
want='123
123
123
123
123999
empty
12
[3,3]'
red=0
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then got="$(timeout -k 5 20 "$SCRIP" "$TMPD/lu.pl" </dev/null 2>"$TMPD/err")"; rc=$?
    else
        timeout -k 5 60 "$SCRIP" --compile -o "$TMPD/lu.s" "$TMPD/lu.pl" </dev/null 2>"$TMPD/err" || refuse "m4 compile failed: $(head -c 160 "$TMPD/err")"
        gcc -m64 -no-pie "$TMPD/lu.s" -o "$TMPD/lu.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || refuse "m4 link failed: $(head -c 160 "$TMPD/err")"
        got="$(timeout -k 5 20 "$TMPD/lu.bin" </dev/null 2>"$TMPD/err")"; rc=$?
        rm -f "$TMPD/lu.s" "$TMPD/lu.bin"
    fi
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $mode"
    else echo "  RED $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|')] want [$(printf '%s' "$want" | tr '\n' '|')]"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red mode(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: clause/2 and retract/1 see the clauses of their call -- erased meanwhile still visited, added meanwhile not -- both modes as gprolog"
exit 0

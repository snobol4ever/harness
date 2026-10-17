#!/usr/bin/env bash
# test_gate_pl_two_variables_compare_one_way_only.sh -- THE STANDARD ORDER OF TWO DISTINCT VARIABLES IS ONE-WAY (ISO 7.2.1: Var @< Var is an
# implementation-dependent TOTAL order; hq_prolog 2026-09-25, CEO-1266; the cure is unification.c at 92e8f4db7).
# THE DEFECT. The comparison numbered variables by where a walk of the FIRST argument and then the second met them, so f(_) @< f(_) held in BOTH
# directions, compare/3 answered < both ways round, and bagof/setof, which order free-variable groups by pairwise comparison, could return them in
# an order no sort gives. The cure compares two unbound cells by address.
# ⛔ WHAT THIS GATE DOES NOT CLAIM: that a variable's place in the order survives var-var unification. It does not today -- the binding moves the
# variable's representative to a newer cell (plw_unify_cells), so msort([K2,K1]) and msort([K1,K2]) disagree once K1 and K2 were unified into a
# structure. That is its own row (prolog-a-var-var-binding-moves-the-older-variable-so-the-standard-order-of-variables-flips-across-calls).
# THE EXPECTATIONS ARE THE ORACLE'S: gprolog prints the five lines below (2026-09-25); the order it picks is its own, only the one-way-ness is graded.
# RED BEFORE on a clean origin build 62a21f70f: lines 1-3 read both(lt) both(lt) < < in m3 AND m4.
set -u
GATE_NAME=test_gate_pl_two_variables_compare_one_way_only
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/vo.pl" <<'EOP'
:- initialization(main).
tot(A, B, T) :- ( A @< B -> X = lt ; X = ge ), ( B @< A -> Y = lt ; Y = ge ), ( X \== Y -> T = total ; T = both(X) ).
anti(O1, O2, R) :- ( O1 == (<), O2 == (>) -> R = antisymmetric ; O1 == (>), O2 == (<) -> R = antisymmetric ; R = same_both_ways ).
main :- A = f(_), B = f(_), tot(A, B, T1), write(T1), nl,
        C = g(_, _), C = g(P, Q), tot(C, g(Q, P), T2), write(T2), nl,
        D = h(_), compare(O1, D, h(_)), E = h(_), compare(O2, h(_), E), anti(O1, O2, R), write(R), nl,
        findall(W, bagof(t, (U = W ; V = W ; Z = W), _), Ws), length(Ws, N), write(N), nl,
        L = [_, _, _], sort(L, SL), length(SL, NL), write(NL), nl.
EOP
want='total
total
antisymmetric
3
3'
red=0
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then got="$(timeout -k 5 20 "$SCRIP" "$TMPD/vo.pl" </dev/null 2>"$TMPD/err")"; rc=$?
    else
        timeout -k 5 60 "$SCRIP" --compile -o "$TMPD/vo.s" "$TMPD/vo.pl" </dev/null 2>"$TMPD/err" || refuse "m4 compile failed: $(head -c 160 "$TMPD/err")"
        gcc -m64 -no-pie "$TMPD/vo.s" -o "$TMPD/vo.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || refuse "m4 link failed: $(head -c 160 "$TMPD/err")"
        got="$(timeout -k 5 20 "$TMPD/vo.bin" </dev/null 2>"$TMPD/err")"; rc=$?
        rm -f "$TMPD/vo.s" "$TMPD/vo.bin"
    fi
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $mode"
    else echo "  RED $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|')] want [$(printf '%s' "$want" | tr '\n' '|')]"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red mode(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: two distinct variables compare one way only, compare/3 is antisymmetric over them, both modes as gprolog"
exit 0

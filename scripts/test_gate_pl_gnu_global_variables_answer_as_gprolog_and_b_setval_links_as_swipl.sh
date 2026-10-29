#!/usr/bin/env bash
# test_gate_pl_gnu_global_variables_answer_as_gprolog_and_b_setval_links_as_swipl.sh -- GNU Prolog's global
# variables (g_assign, g_assignb, g_link, g_read, g_array_size, g_inc/g_dec/g_inco/g_deco, the bit predicates and the
# g_array/g_array_auto/g_array_extend arrays with their index and argument-selector paths) answer as GNU Prolog does,
# and b_setval/2 LINKS its value as swipl does (cfo 2026-10-08, row prolog-gnu-drivers-find-wrong-answers-bagof-setof-
# through-call-findall-4-for-3-name-2-g-read-and-tell-user, chunk 2).
#
# WHAT THIS PINS. (1) GNU's own driver corpus/packages/prolog/gnu_prolog/BipsPl/g_var_inl_driver.pl against its
# gprolog ref (65 lines: link, copy and array cells, nested arrays, auto-extension to the next power of two, an index
# that is another gvar's integer, Name-K selectors, and the instantiation, type and domain errors in GNU's order), in
# m3 and m4. The family is prelude Prolog over nb_setval/nb_getval/b_setval in the key namespace '$gv:'+Name
# (PL_PRELUDE_SRC in src/parsers/prolog/prolog_parse.c). (2) b_setval/2 stores a LINK to the value, not a copy: a
# variable bound after the store is seen by b_getval, a variable bound through b_getval is the stored one, the store
# is undone on backtracking to the old value, and a run-time key takes the same road (rt_pl_b_set in
# src/runtime/unification.c; the two lowerings in src/lower/lower_prolog.c pass the value as an lvalue).
#
# THE REFS. (1) is the corpus ref beside the driver. (2) is swipl's output, carried here; the gate re-cuts it when
# swipl is on the box and refuses rc=2 on disagreement -- re-cut it from the oracle, never from SCRIP.
#
# RED BEFORE (measured on SCRIP cfcfaf46d, m3 and m4 alike): the driver 15 of 65 lines equal by position (g_assign and
# g_read were a two-clause stub over assertz and a catch with no name check, every other g_* predicate an existence
# error) and the link witness 3 of 9, printing a(f(_G0)): b_setval copied. GREEN AFTER: m3 and m4 byte-identical to
# both refs.
#
# Usage: bash ../harness/scripts/test_gate_pl_gnu_global_variables_answer_as_gprolog_and_b_setval_links_as_swipl.sh
set -uo pipefail
GATE_NAME=test_gate_pl_gnu_global_variables_answer_as_gprolog_and_b_setval_links_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
DRV="$HERE/../../corpus/packages/prolog/gnu_prolog/BipsPl/g_var_inl_driver"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
command -v gcc >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: no gcc -- the mode-4 arm cannot be linked"; exit 2; }
[ -f "$DRV.pl" ] && [ -f "$DRV.ref" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no driver or ref at $DRV.{pl,ref} -- the corpus must sit beside SCRIP"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp "$DRV.pl" "$T/g.pl"; cp "$DRV.ref" "$T/g.ref"
cat > "$T/b.pl" <<'PL'
:- initialization(main).
main :-
    b_setval(v, f(X)), X = 1, b_getval(v, Y), writeq(a(Y)), nl,
    b_setval(u, Z), b_getval(u, Z2), Z = 5, writeq(b(Z2)), nl,
    nb_setval(q, 0), ( b_setval(q, g(A)), A = 3, b_getval(q, Q1), writeq(c(Q1)), nl, fail ; true ), b_getval(q, Q2), writeq(d(Q2)), nl,
    nb_setval(r, 1), ( b_setval(r, 2), b_getval(r, R1), writeq(e(R1)), nl, fail ; true ), b_getval(r, R2), writeq(f(R2)), nl,
    W = W, b_setval(w, W), b_getval(w, W2), W = 6, writeq(g(W2)), nl,
    b_setval(x, V), b_getval(x, V2), V2 = 7, writeq(h(V)), nl,
    K = k, b_setval(K, T), T = 8, b_getval(K, T2), writeq(i(T2)), nl,
    halt.
PL
cat > "$T/b.ref" <<'REF'
a(f(1))
b(5)
c(g(3))
d(0)
e(2)
f(1)
g(6)
h(7)
i(8)
REF
if command -v swipl >/dev/null; then
    ( cd "$T" && timeout -k 5 30 swipl -q b.pl < /dev/null > sw.out 2>/dev/null )
    cmp -s "$T/sw.out" "$T/b.ref" || { echo "⛔ REFUSED(2) [$GATE_NAME]: swipl no longer prints the carried b_setval ref -- re-cut it from the oracle, never from SCRIP"; exit 2; }
fi
fail=0
for w in g b; do
    ( cd "$T" && timeout -k 5 30 "$SCRIP" "$w.pl" < /dev/null > "$w.m3" 2>/dev/null ); rc3=$?
    if cmp -s "$T/$w.m3" "$T/$w.ref"; then echo "  ok   (m3) $w: $(wc -l < "$T/$w.ref") lines equal the ref"; else echo "  FAIL (m3) $w rc=$rc3, first difference:"; diff "$T/$w.ref" "$T/$w.m3" | head -6 | sed 's/^/         /'; fail=1; fi
    if ( cd "$T" && "$SCRIP" --compile --out="$w.s" "$w.pl" < /dev/null > /dev/null 2>&1 && gcc -o "$w.x" "$w.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>/dev/null ); then
        ( cd "$T" && timeout -k 5 30 "./$w.x" < /dev/null > "$w.m4" 2>/dev/null ); rc4=$?
        if cmp -s "$T/$w.m4" "$T/$w.ref"; then echo "  ok   (m4) $w: the same, from the standalone build"; else echo "  FAIL (m4) $w rc=$rc4, first difference:"; diff "$T/$w.ref" "$T/$w.m4" | head -6 | sed 's/^/         /'; fail=1; fi
    else echo "  FAIL (m4) $w did not compile or link in mode 4"; fail=1; fi
done
[ "$fail" = 0 ] && { echo "✅ GATE PASS [$GATE_NAME]: the g_var_inl driver answers as gprolog and b_setval links as swipl, m3 and m4"; exit 0; }
echo "⛔ GATE RED [$GATE_NAME]"; exit 1

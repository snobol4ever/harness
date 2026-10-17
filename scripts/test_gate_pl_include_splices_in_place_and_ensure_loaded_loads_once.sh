#!/usr/bin/env bash
# test_gate_pl_include_splices_in_place_and_ensure_loaded_loads_once.sh -- :- include(F) IS TEXTUAL INCLUSION AT THE DIRECTIVE'S PLACE (ISO 7.4.2.7) AND
# :- ensure_loaded(F) LOADS F ONCE (ISO 7.4.2.8); an initialization goal inside an included file runs in load order (hq_prolog 2026-09-25, CEO-1270).
# THE DEFECT. SCRIP dropped both directives: the lowering lists ensure_loaded among ignored declarations and include had no handling at all, so a
# file's clauses never arrived (Logtalk directives include_1, ensure_loaded_1: existence_error(procedure, a/1)). THE CURE: prolog_parse.c parses an
# include's file in place, before clauses are grouped by predicate, so a(1) a(2) from two included files and the including file's own a(3) are one
# predicate in textual order -- a splice after grouping (tried first) kept only one of the groups; prolog_driver.c's load-time consult splice now
# takes ensure_loaded too, which already loads a path once. THE EXPECTATIONS ARE swipl's (2026-09-25); gprolog agrees on the include line and
# has no ensure_loaded/1. RED BEFORE on origin 6ac5caa1b, m3 AND m4: [3], then existence_error for e/1 (rc=2).
set -u
GATE_NAME=test_gate_pl_include_splices_in_place_and_ensure_loaded_loads_once
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
printf 'a(1).\n' > "$TMPD/inc_a.pl"
printf 'a(2).\n:- initialization(assertz(d(i2))).\n' > "$TMPD/inc_b.pl"
printf 'e(1).\n' > "$TMPD/once.pl"
cat > "$TMPD/main.pl" <<'EOP'
:- dynamic(d/1).
:- initialization(assertz(d(m1))).
:- include(inc_a).
:- include('inc_b.pl').
a(3).
:- ensure_loaded(once).
:- ensure_loaded(once).
main :- findall(X, a(X), L), write(L), nl, findall(Y, e(Y), M), write(M), nl, findall(Z, d(Z), N), write(N), nl.
:- initialization(main).
EOP
want='[1,2,3]
[1]
[m1,i2]'
red=0
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 20 "$SCRIP" main.pl </dev/null 2>"$TMPD/err")"; rc=$?
    else
        (cd "$TMPD" && timeout -k 5 60 "$SCRIP" --compile -o w.s main.pl </dev/null 2>"$TMPD/err") || refuse "m4 compile failed: $(head -c 160 "$TMPD/err")"
        gcc -m64 -no-pie "$TMPD/w.s" -o "$TMPD/w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || refuse "m4 link failed: $(head -c 160 "$TMPD/err")"
        got="$(cd "$TMPD" && timeout -k 5 20 ./w.bin </dev/null 2>"$TMPD/err")"; rc=$?
        rm -f "$TMPD/w.s" "$TMPD/w.bin"
    fi
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $mode"
    else echo "  RED $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|')] want [$(printf '%s' "$want" | tr '\n' '|')]"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red mode(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: include splices in place, ensure_loaded loads once, included initialization runs in order, both modes as swipl"
exit 0

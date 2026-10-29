#!/usr/bin/env bash
# test_gate_pl_a_bounded_conditional_runs_assert_2_exists_and_a_huge_length_is_a_resource_error.sh -- THREE SWI-SUITE DEATHS, ONE PROGRAM.
# hq_prolog 2026-10-03 (row prolog-every-suite-to-100-under-nonet-ceo-1266, SWI crawl). (1) The reader's :- if(current_prolog_flag(bounded, V)) read the flag
# BACKWARDS (bounded true -> taken), while the runtime flag table, the arithmetic (2^100 is exact) and swipl all say bounded=false, so every
# :- if(current_prolog_flag(bounded, false)) block of the SWI suite was DROPPED at read time: test_arith's whole bigint unit read EMPTY and test_locale lost 51 cases.
# (2) assert/2 (a clause and its reference, swipl's alias of assertz/2) was refused by the lowerer as "not on the ladder yet", exit 2, so a file naming it graded 0:
# test_db, test_dbref, test_module, test_undo. (3) length(L, 1<<66) looped until the C stack died (ERROR 246, no catch); swipl raises
# resource_error(stack), and test_arith's bigint:length case ends the whole file at that point under the corrected conditional.
# (4) THE PROC TABLE HAD A FIXED CAP OF 256 (PL_BB_TABLE_MAX): past it pl_bb_register returned NULL and a later lookup missed. The corrected conditional lets test_arith's bigint unit in,
# whose clause(H, B, Ref) has a variable head, so every static predicate is seeded (CEO-1467), the procs pass 256, and mode 4 emitted test/0 and test/1 TWICE (`symbol already
# defined`, the assembler refuses the whole file). The table is a growing vector now; the last arm assembles and links the real shim plus core/test_arith.pl.
# RED BEFORE on origin 83bb0341e, m3 AND m4: the first three lines read no/yes/no (the block dropped), assert/2 exit 2 at compile, length died fatally.
set -u
GATE_NAME=test_gate_pl_a_bounded_conditional_runs_assert_2_exists_and_a_huge_length_is_a_resource_error
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/w.pl" <<'EOP'
:- dynamic f/1.
:- if(current_prolog_flag(bounded, false)).
big(yes).
:- else.
big(no).
:- endif.
:- if(current_prolog_flag(bounded, true)).
bnd(yes).
:- else.
bnd(no).
:- endif.
:- if(\+ current_prolog_flag(bounded, true)).
nb(yes).
:- else.
nb(no).
:- endif.
t :- big(B), write(B), nl, bnd(C), write(C), nl, nb(D), write(D), nl,
     assert(f(1), R), ( clause(f(X), true, R) -> write(X) ; write(noref) ), nl,
     erase(R), ( f(_) -> write(still) ; write(erased) ), nl,
     catch((N is 1<<66, length(_, N)), error(E, _), (write(E), nl)).
:- initialization(t).
EOP
want='yes
no
yes
1
erased
resource_error(stack)'
red=0
CORPUS="${S4E_CORPUS:-$HERE/../../corpus}"; PLUNIT="$CORPUS/tests/prolog/plunit.pl"; TARITH="$CORPUS/packages/prolog/swi_tests/core/test_arith.pl"
[ -f "$PLUNIT" ] && [ -f "$TARITH" ] || refuse "no plunit shim or test_arith.pl under $CORPUS"
printf 'main :- run_tests.\n:- initialization(main).\n' > "$TMPD/wrap.pl"
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 20 "$SCRIP" w.pl </dev/null 2>"$TMPD/err")"; rc=$?
    else
        timeout -k 5 60 "$SCRIP" --compile --out="$TMPD/w.s" "$TMPD/w.pl" </dev/null 2>"$TMPD/err" || { echo "  RED m4: the compile refused: $(head -c 160 "$TMPD/err")"; red=$((red+1)); continue; }
        gcc -m64 -no-pie "$TMPD/w.s" -o "$TMPD/w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || refuse "m4 link failed: $(head -c 160 "$TMPD/err")"
        got="$(cd "$TMPD" && timeout -k 5 20 ./w.bin </dev/null 2>"$TMPD/err")"; rc=$?
        rm -f "$TMPD/w.s" "$TMPD/w.bin"
    fi
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $mode"
    else echo "  RED $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-200)] err=[$(head -c 120 "$TMPD/err" | tr '\n' '|')] want [$(printf '%s' "$want" | tr '\n' '|')]"; red=$((red+1)); fi
done
timeout -k 5 180 "$SCRIP" --compile --out="$TMPD/ta.s" "$PLUNIT" "$TARITH" "$TMPD/wrap.pl" </dev/null 2>"$TMPD/err" || { echo "  RED test_arith m4: the compile refused: $(head -c 160 "$TMPD/err")"; red=$((red+1)); }
if [ -s "$TMPD/ta.s" ]; then
    if gcc -m64 -no-pie "$TMPD/ta.s" -o "$TMPD/ta.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err"; then echo "  ok  test_arith m4 assembles and links"
    else echo "  RED test_arith m4: the assembler or linker refused: $(grep -m2 -E 'Error|error' "$TMPD/err" | head -c 260 | tr '\n' '|')"; red=$((red+1)); fi
fi
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red mode(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: a bounded=false :- if block is read, assert/2 returns a clause reference, length(L, 1<<66) raises resource_error(stack), both modes, and test_arith assembles in mode 4"
exit 0

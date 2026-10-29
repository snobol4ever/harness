#!/usr/bin/env bash
# test_gate_pl_directives_run_in_place_in_source_order_as_swipl.sh -- A DIRECTIVE RUNS WHERE THE CONSULT REACHES IT, AND
# begin_tests/1,2 OPEN plunit_<Unit> AS THE SOURCE MODULE prolog_load_context(module, M) ANSWERS (cfo 2026-10-14, row
# prolog-swi-library-test-record-every-case-agrees-with-swipl-in-both-modes-ceo-1664, CEO-1700).
#
# swipl and gprolog run a directive when the consult reaches it; only initialization/1 defers its goal to after the load.
# prolog_lower.c turned a bare :- begin_tests(U), :- begin_tests(U, O), :- end_tests(U) and :- nb_setval(K, V) into a helper
# clause pj_dir_N run as :- initialization(pj_dir_N), AFTER every plain directive of the file: a later :- nb_getval(K, V)
# directive raised existence_error, and a unit's own directives ran before the unit had begun, so the plunit shim could not
# answer prolog_load_context(module, M) as plunit_record inside begin_tests(record) (SWI library/test_record point#11). The
# cure deletes the deferral (a directive is a statement in source order like every other), lower_prolog.c's load-unit reader
# reads the bare begin_tests/end_tests directive, the prelude's prolog_load_context(module, M) answers the source module
# '$set_source_module'/1,2 set (user until one is set), and the shim (corpus tests/prolog/plunit.pl) seeds its suite list in
# place and opens and closes the unit's module. NOT HERE: :- module/2 setting the source module (SCRIP's one flat module stays
# user outside a unit), prolog_load_context/2 at run time (swipl fails, nothing is loading) and every key but module.
#
# THE ARMS: one program under the shim, eight lines, stdout cut against swipl running the same program with its own
# library(plunit) in this run, mode 3 and mode 4. FAIL-ONCE, measured on the parent 1ae478e69 rebuilt, under the cure's shim:
# 4 of 8 lines missing or different in both modes (nb_setval_in_place-1 missing, in_unit-user, in_unit_with_options-user, init
# missing); with the cure 8 of 8 as swipl in both modes.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no shim, no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_directives_run_in_place_in_source_order_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
PLUNIT="${S4E_CORPUS:-$B/../corpus}/tests/prolog/plunit.pl"; [ -f "$PLUNIT" ] || refuse "no plunit shim at $PLUNIT"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- use_module(library(plunit)).
:- writeq(d1), nl.
:- nb_setval(k, 1).
:- nb_getval(k, V), writeq(nb_setval_in_place-V), nl.
:- prolog_load_context(module, M), writeq(before_unit-M), nl.
:- begin_tests(u).
:- prolog_load_context(module, M), writeq(in_unit-M), nl.
:- end_tests(u).
:- prolog_load_context(module, M), writeq(after_unit-M), nl.
:- begin_tests(v, []).
:- prolog_load_context(module, M), writeq(in_unit_with_options-M), nl.
:- end_tests(v).
:- writeq(d2), nl.
:- initialization((writeq(init), nl)).
PL
want="$(cd "$D" && timeout -k 5 20 "$SW" -q w.pl -t halt < /dev/null 2>/dev/null | grep .)"
[ "$(printf '%s\n' "$want" | grep -c .)" = 8 ] || refuse "swipl did not answer the eight lines: [$want]"
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s "$PLUNIT" w.pl < /dev/null > /dev/null 2>&1 ) || refuse "mode 4 compile failed"
( cd "$D" && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || refuse "mode 4 link failed"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 8 of 8 lines as swipl"
    else echo "  $label RED: $n of 8 swipl lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run "$PLUNIT" w.pl < /dev/null
arm m4 timeout -k 5 20 ./w.bin < /dev/null
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"

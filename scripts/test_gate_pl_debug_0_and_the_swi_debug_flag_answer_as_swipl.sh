#!/usr/bin/env bash
# test_gate_pl_debug_0_and_the_swi_debug_flag_answer_as_swipl.sh -- debug/0 AND nodebug/0 SET THE debug FLAG, AND IN THE SWI DIALECT THE
# FLAG IS THE BOOLEAN swipl 9.0.4 KEEPS (cfo 2026-10-14, row prolog-swi-...-ceo-1664, CEO-1698: core/test_call's five setup_call_cleanup
# *_debug cases name setup(debug) and read red once the plunit shim ran case setups, corpus 02761e4cf; test_pio's abc_debug sets it true).
#
# debug/0 was absent and nodebug/0 a no-op; the debug flag took on/off only, the ISO values, so set_prolog_flag(debug, true) raised
# domain_error(flag_value, debug+true). Now debug/0 and nodebug/0 set it on and off (prolog_parse.c's base prelude); set_prolog_flag
# accepts true and false for it and stores on/off; current_prolog_flag answers true/false in the SWI dialect and on/off otherwise
# (by_name_dispatch.c), so an ISO program reads it as before.
#
# THE ARM: one SWI-marked program, eight lines, cut against swipl in this run, mode 3 and mode 4. FAIL-ONCE, measured on the parent
# c0d908bb2 rebuilt: 6 of 8 lines differ in both modes (off for false, debug/0 existence_error, the true/false domain errors); with the
# cure 8 of 8 as swipl.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_debug_0_and_the_swi_debug_flag_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
t(N, G) :- catch((G -> R = yes ; R = no), error(E, _), R = E), writeq(N-R), nl.
main :- current_prolog_flag(debug, D0), writeq(default(D0)), nl, t(debug0, debug), current_prolog_flag(debug, D1), writeq(after_debug(D1)), nl,
  t(nodebug0, nodebug), current_prolog_flag(debug, D2), writeq(after_nodebug(D2)), nl, t(set_true, set_prolog_flag(debug, true)), t(set_on, set_prolog_flag(debug, on)), t(set_false, set_prolog_flag(debug, false)).
PL
want="$(cd "$D" && timeout -k 5 20 "$SW" -q w.pl -t halt < /dev/null 2>/dev/null | sed '/^$/d')"
[ "$(printf '%s\n' "$want" | grep -c .)" = 8 ] || refuse "swipl did not answer the eight lines: [$want]"
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 ) || refuse "mode 4 compile failed"
( cd "$D" && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || refuse "mode 4 link failed"
red=0
for m in m3 m4; do
    if [ "$m" = m3 ]; then got="$(cd "$D" && timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null 2>/dev/null | sed '/^$/d')"; else got="$(cd "$D" && timeout -k 5 20 ./w.bin < /dev/null 2>/dev/null | sed '/^$/d')"; fi
    if [ "$got" = "$want" ]; then echo "  $m GREEN: 8 of 8 lines as swipl"
    else echo "  $m RED: $(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^>') line(s) differ from swipl"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"

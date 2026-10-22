#!/usr/bin/env bash
# test_gate_pl_the_standard_output_streams_report_mode_append_in_the_iso_default_and_write_in_the_swi_dialect.sh -- stream_property(S, mode(M)) of user_output,
# user_error and current_output answers append in SCRIP's ISO default and write under the SWI dialect marker, in both modes (row
# prolog-logtalk-clause-2-and-stream-property-2-three-cases-fail-in-both-modes-ceo-1887, hq_prolog 2026-10-22: Logtalk stream_property_2 cases
# sics_stream_property_2_06d, lgt_stream_property_2_09c and lgt_stream_property_2_10c expect append and read write).
# THE TWO ARMS AND THEIR PROVENANCE. ISO arm: ISO/IEC 13211-1 opens the standard output streams in append mode; the expectation is the suite's own, lifted from
# corpus/packages/prolog/logtalk_iso/predicates/stream_property_2/tests.lgt (the three cases above), and NO oracle answers it (swipl 10 and gprolog 1.6 both
# say write), so it is the standard's word and not an oracle's. SWI arm: a program opening with the use_module(library(lists)) marker (the SWI dialect, as
# every swipl-graded package runs) is cut from /usr/bin/swipl by absolute path and every run re-cuts it live, REFUSING rc=2 when the oracle and the table
# disagree or swipl is absent -- a flip of the dialect arm to append would break every swipl-graded program that prints a standard stream's mode.
# THE PROGRAM: user_input, user_output, user_error read through their aliases, current_output, and a file opened for append (always append); prints alias-mode lines.
# FAIL-ONCE: on origin 6141e5265 the ISO arm printed write for user_output, user_error and current_output in m3 and m4 (the SWI arm agreed).
# Usage: bash ../harness/scripts/test_gate_pl_the_standard_output_streams_report_mode_append_in_the_iso_default_and_write_in_the_swi_dialect.sh
set -uo pipefail
GATE_NAME=test_gate_pl_the_standard_output_streams_report_mode_append_in_the_iso_default_and_write_in_the_swi_dialect
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
cat > "$d/iso.pl" <<PL
:- initialization(main).
main :-
    forall(member(A, [user_input, user_output, user_error]),
           ( stream_property(S, alias(A)), stream_property(S, mode(M)), write(A-M), nl )),
    current_output(C), stream_property(C, mode(CM)), write(current_output-CM), nl,
    open('$d/appended.txt', append, F), stream_property(F, mode(FM)), write(file-FM), nl, close(F),
    halt.
PL
{ echo ':- use_module(library(lists)).'; cat "$d/iso.pl"; } > "$d/swi.pl"
cat > "$d/iso.want" <<'WANT'
user_input-read
user_output-append
user_error-append
current_output-append
file-append
WANT
cat > "$d/swi.want" <<'WANT'
user_input-read
user_output-write
user_error-write
current_output-write
file-append
WANT
fails=0; graded=0
"$SWIPL" -q -g main -t halt "$d/swi.pl" </dev/null > "$d/swi.oracle" 2>/dev/null
cmp -s "$d/swi.want" "$d/swi.oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the swi expectation table is not what $SWIPL prints now"; diff "$d/swi.want" "$d/swi.oracle" | head -5; exit 2; }
for w in iso swi; do
    timeout -k 5 20 "$SCRIP" "$d/$w.pl" </dev/null 2>/dev/null > "$d/$w.m3"; rc=$?; graded=$((graded + 1))
    if [ $rc -ne 0 ] || ! cmp -s "$d/$w.want" "$d/$w.m3"; then fails=$((fails + 1)); echo "  $w m3 rc=$rc differs:"; diff "$d/$w.want" "$d/$w.m3" | head -10; fi
    graded=$((graded + 1))
    if timeout -k 5 60 "$SCRIP" --compile -o "$d/$w.s" "$d/$w.pl" </dev/null >/dev/null 2>&1; then
        if as --64 -o "$d/$w.o" "$d/$w.s" 2> "$d/$w.aserr" && gcc -no-pie -o "$d/$w.bin" "$d/$w.o" "$OUT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$OUT" 2>/dev/null; then
            timeout -k 5 20 "$d/$w.bin" </dev/null 2>/dev/null > "$d/$w.m4"; rc=$?
            if [ $rc -ne 0 ] || ! cmp -s "$d/$w.want" "$d/$w.m4"; then fails=$((fails + 1)); echo "  $w m4 rc=$rc differs:"; diff "$d/$w.want" "$d/$w.m4" | head -10; fi
        else fails=$((fails + 1)); echo "  $w m4 did not assemble or link:"; head -3 "$d/$w.aserr" | cut -c1-200; fi
    else fails=$((fails + 1)); echo "  $w m4 did not compile"; fi
done
echo "PLSTDMODE_BOARD programs=2 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0

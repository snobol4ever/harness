#!/usr/bin/env bash
# test_gate_pl_a_use_module_directive_after_the_clauses_changes_nothing_in_mode_4.sh -- a program prints the same in m3 and m4, and the same as swipl 9.0.4, when its  :- use_module(library(lists)).  directive
# carries a long trailing % comment and sits just before the clauses of an appended driver (hq_packages 2026-10-22, found moving the XSB package's dialect marker: the vendored table_tests/abol_test.pl printed
# nothing in mode 4 while mode 3 was right; the SAME text with the directive bare, or with the comment but on the first line, prints right in both modes -- so the trigger is the comment in that position, measured).
# WITNESS: corpus/packages/prolog/xsb_tests/table_tests_abol_test.pl (a static tabled program using get_calls/3 and abolish_table_pred/1); the gate moves its first line to just before the appended driver block (the driver's own predicates follow it).
# THE REF IS CUT FROM THE ORACLE, NEVER FROM SCRIP: swipl 9.0.4 runs the same text live each time and the gate REFUSES rc=2 when swipl prints nothing.
# Usage: bash ../harness/scripts/test_gate_pl_a_use_module_directive_after_the_clauses_changes_nothing_in_mode_4.sh
set -uo pipefail
GATE_NAME=test_gate_pl_a_use_module_directive_after_the_clauses_changes_nothing_in_mode_4
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"; OUT="${RT_DIR:-$HERE/../../SCRIP/out}"; SWIPL=/usr/bin/swipl
SRC="${S4E_CORPUS:-$HERE/../../corpus}/packages/prolog/xsb_tests/table_tests_abol_test.pl"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
[ -f "$SRC" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no witness $SRC"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT
mk="$(head -1 "$SRC")"; case "$mk" in ":- use_module(library(lists))."*) ;; *) echo "⛔ REFUSED(2) [$GATE_NAME]: the witness no longer starts with the dialect marker"; exit 2;; esac
tail -n +2 "$SRC" > "$d/late.pl"; printf '%s\n' ':- use_module(library(lists)).   % the dialect marker: the oracle is swipl, so SCRIP reads this program as SWI-Prolog does (double_quotes, listing, format ~Ns, portray_clause)' >> "$d/late.pl"
python3 - "$d/late.pl" <<'PY'
import sys
p=sys.argv[1]; L=open(p).read().split('\n'); L=[l for l in L if l!='']
# the marker is last; move it to just before the driver block (the position that printed nothing in mode 4): the driver's own predicates follow it
mk=L.pop(); i=min(k for k,l in enumerate(L) if l.startswith('% DRIVER')); L.insert(i,mk); open(p,'w').write('\n'.join(L)+'\n')
PY
(cd "$d" && timeout -k 5 60 "$SWIPL" -q late.pl </dev/null > "$d/want" 2>/dev/null)
[ -n "$(cat "$d/want")" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: the oracle printed nothing"; exit 2; }
fails=0; graded=0
(cd "$d" && SCRIP_HEAP_CAP_KB=131072 SCRIP_STACK=8192k timeout -k 5 60 "$SCRIP" late.pl </dev/null 2>/dev/null > "$d/m3"); graded=$((graded + 1))
[ "$(cat "$d/want")" = "$(cat "$d/m3")" ] || { fails=$((fails + 1)); echo "  m3 differs: $(wc -l < "$d/want") oracle lines, $(wc -l < "$d/m3") got"; }
graded=$((graded + 1))
if (cd "$d" && timeout -k 5 120 "$SCRIP" --compile -o late.s late.pl </dev/null >/dev/null 2>&1 && gcc -no-pie -o late.bin late.s "$OUT/libscrip_rt.so" -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
    (cd "$d" && SCRIP_HEAP_CAP_KB=131072 SCRIP_STACK=8192k timeout -k 5 60 ./late.bin </dev/null 2>/dev/null > "$d/m4")
    [ "$(cat "$d/want")" = "$(cat "$d/m4")" ] || { fails=$((fails + 1)); echo "  m4 differs: $(wc -l < "$d/want") oracle lines, $(wc -l < "$d/m4") got"; }
else fails=$((fails + 1)); echo "  m4 did not compile or link"; fi
echo "PLLATEUSEMODULE_BOARD programs=1 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0

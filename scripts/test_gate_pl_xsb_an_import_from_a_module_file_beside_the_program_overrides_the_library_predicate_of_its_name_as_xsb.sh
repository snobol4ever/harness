#!/usr/bin/env bash
# test_gate_pl_xsb_an_import_from_a_module_file_beside_the_program_overrides_the_library_predicate_of_its_name_as_xsb.sh -- XsbTests ai_tests (the cfo, 2026-11-07, CTO-533 (4)):
# :- import flatten/2 from m. where m.P lies beside the importing file and exports flatten/2 reaches m's flatten/2, in the importing file and in a module
# file that imports it the same way, as XSB 5.0.0 answers; an import from the system module basics (append/3, which no file beside exports) still reaches the library.
# NOT GRADED HERE (a module-namespace design question for the cto): a second module importing flatten/2 from basics while m exports flatten/2 -- XSB keeps
# the two apart, SCRIP's exported names are global, so that module reaches m's flatten/2.
# MEASURED (the cfo, SCRIP 12f2d7b18, m3 and m4): SCRIP printed t1([a,b]) t2([a,b]) where XSB prints t1(mine) t2(mine): prolog_inject_prelude composed the
# importing file's prelude before pl_splice_consults loaded m.P, so library(lists) flatten/2 was linked and m's exported flatten/2 never reached; five
# ai_tests programs (disj, queens, read, plan, kalah) lose answers through set_unify.P's flatten/2 imported from set_basics_mono.
# The program is read as the xsb_tests package reads every entry: its ALL.prelude text (the XSB operators and the SWI marker) before the first line.
# THE REF IS CUT FROM THE ORACLE ON EVERY RUN through util_oracle.sh xsb (one run slot, the shared cache keyed on every file the run reads); the table below is what XSB printed when this gate was written, and a disagreement
# between the table and the live oracle REFUSES rc=2.
# EXIT 0 both modes print the table; 1 a mode differs (named); 2 no scrip, a stale build, no oracle, or the oracle disagrees with the table.
set -uo pipefail
GATE_NAME=test_gate_pl_xsb_an_import_from_a_module_file_beside_the_program_overrides_the_library_predicate_of_its_name_as_xsb
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
PRE="$HERE/../../corpus/packages/prolog/xsb_tests/ALL.prelude"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
[ -f "$PRE" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no $PRE"; exit 2; }
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
printf '%s\n' ':- export flatten/2.' 'flatten(_, mine).' > "$d/m.P"
printf '%s\n' ':- export via_n/1.' ':- import flatten/2 from m.' 'via_n(X) :- flatten([a,[b]], X).' > "$d/n.P"
printf '%s\n' ':- export via_s/1.' ':- import append/3 from basics.' 'via_s(X) :- append([a], [b], X).' > "$d/s.P"
cat > "$d/body" <<'PL'
:- import flatten/2 from m.
:- import via_n/1 from n.
:- import via_s/1 from s.
t1 :- flatten([a,[b]], X), write(t1(X)), nl.
t2 :- via_n(X), write(t2(X)), nl.
t3 :- via_s(X), write(t3(X)), nl.
:- t1, t2, t3.
PL
cp "$d/body" "$d/main.P"
{ grep -v '^#' "$PRE" | grep -v '^[[:space:]]*$' | tr '\n' ' '; cat "$d/body"; } > "$d/main.pl"
printf '%s\n' 't1(mine)' 't2(mine)' 't3([a,b])' > "$d/want"
printf '%s\n' '[main].' 'halt.' > "$d/xin"
(cd "$d" && bash "$HERE/util_oracle.sh" xsb --stdin "$d/xin" --timeout 60 --key-file main.P --key-file m.P --key-file n.P --key-file s.P -- 2>/dev/null) > "$d/xout"; orc=$?
[ "$orc" = 2 ] && { echo "⛔ REFUSED(2) [$GATE_NAME]: util_oracle.sh could not run XSB"; exit 2; }
sed 's/^\(| ?- \)*//' "$d/xout" | grep -E '^t[0-9]\(' > "$d/oracle"
cmp -s "$d/want" "$d/oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the table is not what XSB (util_oracle.sh xsb, rc $orc) prints now"; diff "$d/want" "$d/oracle" | head -5; exit 2; }
rm -f "$d"/*.xwam
fails=0; graded=0
(cd "$d" && timeout -k 5 60 "$SCRIP" --run main.pl </dev/null 2>/dev/null > "$d/m3"); rc=$?; graded=$((graded + 1))
if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs from XSB:"; diff "$d/want" "$d/m3" | head -10; fi
graded=$((graded + 1))
if (cd "$d" && timeout -k 5 120 "$SCRIP" --compile main.pl </dev/null > w.s 2>/dev/null && gcc -c w.s -o w.o 2>/dev/null \
    && gcc w.o -fuse-ld=gold -L "$OUT" -lscrip_rt -lm -Wl,-rpath,"$OUT" -o w.bin 2>/dev/null); then
    (cd "$d" && timeout -k 5 60 ./w.bin </dev/null 2>/dev/null > "$d/m4"); rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs from XSB:"; diff "$d/want" "$d/m4" | head -10; fi
else fails=$((fails + 1)); echo "  m4 did not compile or link"; fi
echo "PLXSBIMPORTOVERRIDE_BOARD programs=1 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails (tree $(git -C "$HERE/../../SCRIP" rev-parse --short HEAD 2>/dev/null))"
[ $fails -eq 0 ] && { echo "GATE OK [$GATE_NAME]"; exit 0; }
echo "GATE FAIL [$GATE_NAME]"; exit 1

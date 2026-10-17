#!/usr/bin/env bash
# test_gate_swi_runner_excludes_a_case_named_in_excluded_cases.sh -- THE SWI RUNNER READS EXCLUDED_CASES.tsv AT CASE LEVEL (ceo CEO-1710, Lon
# 2026-10-14 13:3x CDT: "We want dynamic growing everything. So if another oracle has fixed and we can do better and go longer. That we
# should."). A case named there with class SCRIP_EXCEEDS_ORACLE, NO_ORACLE_ANSWER or THREADS_EXCLUDED_BY_LON (CEO-1766: Lon 2026-10-15,
# "Put the multi-threaded Prolog work as excluded for now.") leaves the denominator as Excl, counted by class and never a pass; a row naming a case the graded file does not declare is STALE and reds the run; a row with any other class refuses rc 2.
# FIXTURE: a mktemp corpus holding a COPY of the real db/test_db.pl and its oracle ref (outside corpus/, CEO-547), graded with --file in
# mode 3, so no progress row and no suite row is written. The cfo's first CEO-1710 cases are that file's assert:max_procedure_arity
# instances (swipl caps the arity at 1024; SCRIP grows past it).
# ARMS: (1) the named cases leave the graded count by exactly their number, the board names SCRIP_EXCEEDS_ORACLE, rc 0, 0 STALE
#       (2) the same with a stale row added reads rc 1 and names the stale row
#       (3) a row whose class is not in the vocabulary refuses rc 2 before grading
#       (4) CONTROL: with no EXCLUDED_CASES.tsv the same file grades those cases (the graded count is higher by their number)
#       (5) the same cases named THREADS_EXCLUDED_BY_LON leave the graded count by exactly their number, the board names that class (CEO-1766)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"; SRC="${S4E_CORPUS:-$ROOT/corpus}/packages/prolog/swi_tests/db"
refuse() { echo "⛔ REFUSED(2) [swi_runner_excludes_a_case_named_in_excluded_cases]: $*"; exit 2; }
[ -f "$SRC/test_db.pl" ] && [ -f "$SRC/test_db.ref" ] || refuse "no db/test_db.pl and its ref under $SRC"
T="$(mktemp -d)" || refuse "mktemp failed"; trap 'rm -rf "$T"' EXIT
S="$T/packages/prolog/swi_tests"; mkdir -p "$S/db" && cp "$SRC/test_db.pl" "$SRC/test_db.ref" "$S/db/" || refuse "fixture copy failed"
run() { S4E_CORPUS="$T" S4E_PROGRESS_OFF=1 timeout -k 5 600 bash "$HERE/test_prolog_swi_suite.sh" --file db/test_db.pl --modes m3 > "$T/out" 2>&1; echo $?; }
graded() { sed -n 's/^  db\/test_db.pl  *[0-9]*\/\([0-9]*\) .*/\1/p' "$T/out" | head -1; }
fails=0; ck() { if [ "$1" = ok ]; then echo "  ok    $2"; else echo "  FAIL  $2"; fails=$((fails+1)); fi; }
echo "=== gate: the SWI runner excludes a case named in EXCLUDED_CASES.tsv (CEO-1710) ==="
rc=$(run); g0=$(graded); [ "$rc" -le 1 ] && [ -n "$g0" ] || refuse "the control run could not grade the fixture (rc=$rc): $(tail -2 "$T/out")"
n=$(grep -c 'max_procedure_arity' "$S/db/test_db.ref"); [ "$n" -gt 0 ] || refuse "the ref names no max_procedure_arity case -- the fixture moved"
printf 'db/test_db.pl\tassert:max_procedure_arity\tSCRIP_EXCEEDS_ORACLE\tswipl caps max_procedure_arity at 1024, SCRIP grows past it (gate fixture)\n' > "$S/EXCLUDED_CASES.tsv"
rc=$(run); g1=$(graded); ex=$(sed -n 's/.*SCRIP_EXCEEDS_ORACLE(EXCLUDED_CASES.tsv)=\([0-9]*\).*/\1/p' "$T/out" | head -1)
[ "$rc" = 0 ] && [ -n "$ex" ] && [ "$ex" -gt 0 ] && [ "$g1" = "$((g0 - ex))" ] && grep -q '0 STALE' "$T/out" \
  && ck ok "(1) $ex case(s) excluded as SCRIP_EXCEEDS_ORACLE: graded $g0 -> $g1, rc 0, 0 STALE" \
  || ck no "(1) rc=$rc graded $g0 -> ${g1:-?} excluded=${ex:-none}: $(grep -E 'EXCLUDED_CASES|STALE' "$T/out" | head -2)"
printf 'db/test_db.pl\tassert:no_such_case_by_the_gate\tSCRIP_EXCEEDS_ORACLE\ta stale row (gate fixture)\n' >> "$S/EXCLUDED_CASES.tsv"
rc=$(run); [ "$rc" = 1 ] && grep -q 'STALE -- db/test_db.pl:assert:no_such_case_by_the_gate' "$T/out" \
  && ck ok "(2) a stale row reds the run (rc 1) and is named" || ck no "(2) stale row: rc=$rc $(grep -E 'STALE' "$T/out" | head -1)"
printf 'db/test_db.pl\tassert:max_procedure_arity\tNOT_A_CLASS\twhatever (gate fixture)\n' > "$S/EXCLUDED_CASES.tsv"
rc=$(run); [ "$rc" = 2 ] && grep -q 'REFUSED (rc 2)' "$T/out" && ck ok "(3) an unknown class refuses rc 2" || ck no "(3) unknown class: rc=$rc $(grep -m1 REFUSED "$T/out")"
rm -f "$S/EXCLUDED_CASES.tsv"; [ -n "${ex:-}" ] && [ "$g0" -gt "${g1:-$g0}" ] && ck ok "(4) CONTROL: without the file the cases grade ($g0 graded, $ex more than with it)" || ck no "(4) control: g0=$g0 g1=${g1:-?}"
printf 'db/test_db.pl\tassert:max_procedure_arity\tTHREADS_EXCLUDED_BY_LON\treaches thread_create/3 (gate fixture)\n' > "$S/EXCLUDED_CASES.tsv"
rc=$(run); g5=$(graded); ex5=$(sed -n 's/.*THREADS_EXCLUDED_BY_LON(EXCLUDED_CASES.tsv)=\([0-9]*\).*/\1/p' "$T/out" | head -1)
[ "$rc" = 0 ] && [ -n "$ex5" ] && [ "$ex5" -gt 0 ] && [ "$g5" = "$((g0 - ex5))" ] && grep -q '0 STALE' "$T/out" \
  && ck ok "(5) $ex5 case(s) excluded as THREADS_EXCLUDED_BY_LON: graded $g0 -> $g5, rc 0, 0 STALE" \
  || ck no "(5) rc=$rc graded $g0 -> ${g5:-?} excluded=${ex5:-none}: $(grep -E 'EXCLUDED_CASES|STALE|REFUSED' "$T/out" | head -2)"
echo "population: one real SWI file (db/test_db.pl) in mode 3, 5 arms, $fails FAIL"
[ "$fails" = 0 ] && { echo "GATE PASS [swi_runner_excludes_a_case_named_in_excluded_cases]: 5 of 5 arms hold"; exit 0; }
echo "⛔ GATE RED [swi_runner_excludes_a_case_named_in_excluded_cases]: $fails of 5 arms FAIL"; exit 1

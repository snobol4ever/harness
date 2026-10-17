#!/usr/bin/env bash
# test_gate_from_progress_assembles_a_package_as_shipped_minus_excluded.sh -- THE ASSEMBLED PACKAGE ROW IS THE RUNNER'S ROW (ceo CEO-1802/1803; Lon
# 2026-10-15 via the ceo, verbatim: "Why is not the suite board a list of tests and not a list of suites? Then each set gets updated in round robin.").
# A package read a chunk at a time has its suite row ASSEMBLED by util_score_row.py from-progress from the latest per-program readings, and that row
# must be the one lib_container_package_runner.sh publishes from a whole run: shipped minus EXCLUDED, so shipped = denominator + Excl.
# THE FIXTURE (a scratch corpus and progress DB; the real table and DB are never read or written): package zzpkg ships a b c d e f g (.pl); the
# container ALL.pl/ALL.csv grades a b c d; e is shipped and ungraded (debt, no reading needed); f is an EXCLUDED.tsv row (NO_ORACLE_ANSWER); g is
# a CONTAINERS.tsv fragment. Readings: a, c and d PASS in both modes; b PASS m3, FAIL m4; d's m4 reading is named d.pl (GNU's spelling).
#   ARM 1  the row is 3/5 with excluded=2: pass 3 (a c d), denominator {a b c d e} = 5, Excl = 1 EXCLUDED row + 1 fragment.
#   ARM 2  SUITE_ROW_PACKAGE prints shipped=7 table=4 excluded=2 denominator=5 debt_unread_by_design=1.
#   ARM 3  a master key is untouched: the rebus rungs fixture keys its total on ALL.csv alone (no SUITE_ROW_PACKAGE line).
#   ARM 4  an entry whose latest readings are OUTSIDE in both modes leaves the denominator into excluded (CEO-1696): 2/4 excluded=3.
#   ARM 5  SWI assembles BY CASE from the oracle's enumeration (its table lists files, its rows name cases): files u/test_a (ua:t1 PASS, ua:t2 PASS,
#          ua:t3 FAIL in the ref, unit ub EMPTY with test t4) and u/test_b (uc:x PASS); EXCLUDED_CASES.tsv names ua:t2#1. Declared 5, Excl 2 (t4 has no
#          oracle answer, t2 is excluded), graded 3. Readings: t1 and x PASS both modes, t3 PASS m3 / FAIL m4, and a reading of the excluded t2 that
#          must not count. The row is 2/3 excluded=2.
#   ARM 6  SWI's Excl comes from the corpus, never from a row: the fixture's SUITES.tsv says swi excluded 167, and the row still reads excluded=2.
#   ARM 7  Logtalk assembles BY CASE as its grader keys them: its table lists g:a, g:b twice, g:w twice, g:x and g:o; EXCLUDED_CASES.tsv names g:w
#          WINDOWS_ONLY (one instance out) and g:x BOUNDED_INTEGERS_ONLY (every instance out); CONTAINERS.tsv names three files, which are no cases.
#          Population g:a g:b#1 g:b#2 g:w g:o (5), Excl 2. Readings: a, b#1 and w PASS both modes, b#2 PASS m3 / FAIL m4, o OUTSIDE both modes (it
#          stays in the denominator, as the runner's row), and a stale bare g:b reading from before the #k keys. The row is 3/5 excluded=2.
#   PROVEN TO FAIL: on origin c6b9a6953 arms 5 and 6 FAIL (the cases match no table entry: 0/2 excluded=0, 2 unread); on the first cut of the SWI
#   assembly (local 5d51861a3) arms 5 and 6 FAIL: it reads 2/3 excluded=167, the fixture's SUITES.tsv number read back. On origin b3a834ba4 arm 7
#   FAILS: 3/4 excluded=4 (the table's names, not the grader's keys: the #k rows are dropped, the stale bare g:b reading stands in for both, and
#   the three container files and the OUTSIDE case count as Excl).
# PROVEN TO FAIL on the assembler before this rule (origin 717ddfca3's util_score_row.py): arms 1 and 2 FAIL -- it reads 3/4 with no excluded= (ALL.csv's count; d.pl unmatched, so d is half read).
# EXIT 0 every arm holds; 1 an arm failed; 2 could not measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SR="${FROM_PROGRESS_SR:-$HERE/util_score_row.py}"
[ -f "$SR" ] || { echo "GATE REFUSE(2): $SR is missing"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
P="$T/corpus/packages/prolog/zzpkg"; mkdir -p "$P" "$T/corpus/tests/rebus"
for n in a b c d e f g; do printf ':- initialization(main).\nmain :- write(%s), nl.\n' "$n" > "$P/$n.pl"; done
printf 'all\n' > "$P/ALL.pl"; printf 'a\nb\nc\nd\n' > "$P/ALL.ref"
printf 'rank,entry,origin\n1,a,x\n2,b,x\n3,c,x\n4,d,x\n' > "$P/ALL.csv"
printf '# EXCLUDED.tsv\nf.pl\tNO_ORACLE_ANSWER\tthe oracle prints nothing\n' > "$P/EXCLUDED.tsv"
printf '# CONTAINERS.tsv\ng.pl\tINCLUDED_BY\ta.pl\n' > "$P/CONTAINERS.tsv"
printf 'rank,entry,origin\n1,r1,x\n2,r2,x\n' > "$T/corpus/tests/rebus/ALL.csv"
DB="$T/results.tsv"
printf 'ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\tfingerprint\tconfig\n' > "$DB"
row() { printf '2026-10-15T20:00:%02d\tabc1234\tc0ffee0\tcoo\tpackage\t%s\t%s\t%s\t%s\t%s\t1.0\t\t\tpartition=chunk:01\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$DB"; }
row 1 zzpkg prolog a m3 PASS; row 2 zzpkg prolog a m4 PASS; row 3 zzpkg prolog b m3 PASS; row 4 zzpkg prolog b m4 FAIL
row 5 zzpkg prolog c m3 PASS; row 6 zzpkg prolog c m4 PASS; row 7 zzpkg prolog d m3 PASS; row 8 zzpkg prolog d.pl m4 PASS
row 9 rebus-rungs rebus r1 m3 PASS; row 10 rebus-rungs rebus r1 m4 PASS; row 11 rebus-rungs rebus r2 m3 PASS; row 12 rebus-rungs rebus r2 m4 PASS
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
o1="$(S4E_CORPUS_ROOT="$T/corpus" S4E_PROGRESS_DB="$DB" python3 "$SR" from-progress --suite zzpkg --dry-run 2>&1)"; r1=$?
o3="$(S4E_CORPUS_ROOT="$T/corpus" S4E_PROGRESS_DB="$DB" python3 "$SR" from-progress --suite reb-rungs --dry-run 2>&1)"; r3=$?
[ "$r1" = 0 ] && [ "$r3" = 0 ] || { printf '%s\n%s\n' "$o1" "$o3" | tail -6; echo "GATE REFUSE(2): from-progress --dry-run did not run (rc $r1, $r3)"; exit 2; }
ck "1 the package row is 3/5 excluded=2 (shipped minus EXCLUDED, d.pl matched to d)" 'grep -q "would set zzpkg -> 3/5 excluded=2 " <<<"$o1"'
ck "2 SUITE_ROW_PACKAGE shipped=7 table=4 excluded=2 denominator=5 debt_unread_by_design=1" 'grep -q "^SUITE_ROW_PACKAGE suite=zzpkg shipped=7 table=4 excluded_rows=1 containers=1 outside=0 excluded=2 denominator=5 debt_unread_by_design=1$" <<<"$o1"'
ck "3 a master key keeps ALL.csv as its population (reb-rungs 2/2, no SUITE_ROW_PACKAGE)" 'grep -q "would set reb-rungs -> 2/2 stamped" <<<"$o3" && ! grep -q "^SUITE_ROW_PACKAGE" <<<"$o3"'
# arm 4: an entry the oracle refuses in BOTH modes (latest readings OUTSIDE m3 and m4) leaves the denominator and counts in excluded (CEO-1696)
row 13 zzpkg prolog c m3 OUTSIDE; row 14 zzpkg prolog c m4 OUTSIDE
o4="$(S4E_CORPUS_ROOT="$T/corpus" S4E_PROGRESS_DB="$DB" python3 "$SR" from-progress --suite zzpkg --dry-run 2>&1)"
ck "4 c refused by the oracle in both modes leaves the denominator: 2/4 excluded=3, outside=1" 'grep -q "would set zzpkg -> 2/4 excluded=3 " <<<"$o4" && grep -q " outside=1 excluded=3 denominator=4 " <<<"$o4"'
# arms 5 and 6: SWI by case (a scratch swi_tests table, refs, EXCLUDED_CASES.tsv, and a SUITES.tsv whose swi row says excluded 167)
W="$T/corpus/packages/prolog/swi_tests"; mkdir -p "$W/u"
printf 'rank,entry,origin\n1,u/test_a,x\n2,u/test_b,x\n' > "$W/ALL.csv"
printf ':- begin_tests(ua).\ntest(t1) :- true.\ntest(t2) :- true.\ntest(t3) :- true.\n:- end_tests(ua).\n:- begin_tests(ub).\ntest(t4) :- true.\n:- end_tests(ub).\n' > "$W/u/test_a.pl"
printf 'PASS ua:t1\nPASS ua:t2\nFAIL ua:t3\nEMPTY ub\n' > "$W/u/test_a.ref"
printf ':- begin_tests(uc).\ntest(x) :- true.\n:- end_tests(uc).\n' > "$W/u/test_b.pl"; printf 'PASS uc:x\n' > "$W/u/test_b.ref"
printf '# EXCLUDED_CASES.tsv\nu/test_a.pl\tua:t2#1\tNO_ORACLE_ANSWER\tthe fixture names it\n' > "$W/EXCLUDED_CASES.tsv"
row 21 swi prolog u/test_a.pl:ua:t1#1 m3 PASS; row 22 swi prolog u/test_a.pl:ua:t1#1 m4 PASS; row 23 swi prolog u/test_a.pl:ua:t2#1 m3 PASS; row 24 swi prolog u/test_a.pl:ua:t2#1 m4 PASS
row 25 swi prolog u/test_a.pl:ua:t3#1 m3 PASS; row 26 swi prolog u/test_a.pl:ua:t3#1 m4 FAIL; row 27 swi prolog u/test_b.pl:uc:x#1 m3 PASS; row 28 swi prolog u/test_b.pl:uc:x#1 m4 PASS
printf 'key\tlabel\ticon\tlang\tfirst_date\tfirst_pass\tfirst_total\ttoday_date\ttoday_pass\ttoday_total\ttree\tcriterion_changed\ttoday_excluded\nswi\tSWI\tx\tprolog\t2026-10-01\t0\t1\t2026-10-15\t2129\t2768\tabc1234\t\t167\n' > "$T/SUITES.tsv"
o5="$(S4E_SUITES_TSV="$T/SUITES.tsv" S4E_CORPUS_ROOT="$T/corpus" S4E_PROGRESS_DB="$DB" python3 "$SR" from-progress --suite swi --dry-run 2>&1)"
ck "5 SWI assembles by case: 2/3, declared 5, graded 3, excluded 2" 'grep -q "would set swi -> 2/3 excluded=2 " <<<"$o5" && grep -q "^SUITE_ROW_SWI files=2 declared=5 graded=3 excluded=2 " <<<"$o5"'
ck "6 SWI's Excl is the corpus's 2, not the 167 its SUITES.tsv row says" 'grep -q " excluded=2 " <<<"$o5" && ! grep -q "excluded=167" <<<"$o5"'
# arm 7: Logtalk by case (a scratch logtalk_iso table with repeated names, two exclusion classes and container files)
L="$T/corpus/packages/prolog/logtalk_iso"; mkdir -p "$L"
printf 'rank,entry,origin\n1,g:a,x\n2,g:b,x\n3,g:b,x\n4,g:w,x\n5,g:w,x\n6,g:x,x\n7,g:o,x\n' > "$L/ALL.csv"
printf '# EXCLUDED_CASES.tsv\ng:w\tWINDOWS_ONLY\t:- if(windows)\ng:x\tBOUNDED_INTEGERS_ONLY\tcondition(bounded)\n' > "$L/EXCLUDED_CASES.tsv"
printf '# CONTAINERS.tsv\nd1.lgt\tDRIVER\tx\nd2.lgt\tDRIVER\tx\nd3.lgt\tDRIVER\tx\n' > "$L/CONTAINERS.tsv"
row 30 logtalk prolog g:b m3 PASS; row 31 logtalk prolog g:b m4 PASS
row 41 logtalk prolog g:a m3 PASS; row 42 logtalk prolog g:a m4 PASS; row 43 logtalk prolog "g:b#1" m3 PASS; row 44 logtalk prolog "g:b#1" m4 PASS
row 45 logtalk prolog "g:b#2" m3 PASS; row 46 logtalk prolog "g:b#2" m4 FAIL; row 47 logtalk prolog g:w m3 PASS; row 48 logtalk prolog g:w m4 PASS
row 49 logtalk prolog g:o m3 OUTSIDE; row 50 logtalk prolog g:o m4 OUTSIDE
o7="$(S4E_CORPUS_ROOT="$T/corpus" S4E_PROGRESS_DB="$DB" python3 "$SR" from-progress --suite logtalk --dry-run 2>&1)"
ck "7 Logtalk assembles by case: 3/5 excluded=2 (name#k keys, a guard class takes one instance, OUTSIDE stays, containers are no cases)" 'grep -q "would set logtalk -> 3/5 excluded=2 " <<<"$o7"'
[ "$fails" = 0 ] || printf '%s\n%s\n%s\n' "$o1" "$o5" "$o7" | grep -E '^SUITE_ROW|would set|REFUSE' | sed 's/^/      /'
if [ "$fails" = 0 ]; then echo "✅ GATE PASS [from_progress_assembles_a_package_as_shipped_minus_excluded]: $n of $n arms hold"; exit 0; fi
echo "⛔ GATE FAIL [from_progress_assembles_a_package_as_shipped_minus_excluded]: $fails of $n arm(s) failed"; exit 1

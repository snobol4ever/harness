#!/usr/bin/env bash
# test_gate_from_progress_takes_a_bench_or_demo_population_from_its_runner.sh -- A BENCH OR DEMO ROW FROM THE PER-PROGRAM READINGS, ITS POPULATION
# THE RUNNER'S OWN (the coo 2026-10-23, on the ceo's word, verbatim: "from-progress: yes, teach it the bench and demo keys, so a one-program re-grade
# writes those rows."; CEO-1926/1927).
#
# util_score_row.py from-progress assembled a row only for a key with an ALL.csv (the masters, the packages) or a port's census; SCRIP's bench and demo
# rows came from a whole runner pass alone, so a one-program re-grade (S4E_CHUNK=entry:NAME) left IcnDemo, ProDemo, ProBench and RakBench stale. Now a
# runner under S4E_LIST=1 prints the members it grades (RR_POP) and those it names out of the denominator (RR_EXCL) and grades nothing (lib_rr.sh
# rr_list), and from-progress reads that listing -- the runner's enumeration stays the one rule. FIXTURE ARMS, a scratch corpus and a scratch
# progress table (S4E_CORPUS_ROOT, S4E_PROGRESS_DB; the runners pointed there by their own DEMOS_DIR and BENCH_RAKU_DIR), dry runs only:
#   1 the demos runner lists alpha and beta and names gamma (CONTAINERS.tsv) RR_EXCL -- and grades nothing
#   2 prolog-demos assembles 1/2 excluded=1 (alpha PASS both modes, beta FAIL in m4; gamma out)
#   3 the raku bench runner lists k1 and k2 and names k3 (OUTSIDE.tsv OUTSIDE_SLOW) RR_EXCL; raku-bench-ref assembles 2/2 excluded=1
#   4 an S4E_CHUNK in from-progress's environment does not narrow the population (still 1/2)
#   5 a runner that lists no member (an empty demo tree) refuses rc 2 -- a population of zero is never a row
#   6 a runner that names nothing out of the denominator reads excluded=0 -- a cell the runner's own write left stale is cleared (ProBench, 10-11..10-23)
#   7-9 THE SEAM CENSUS (CEO-1927): the snobol4 bench runner lists its real tree and grades nothing; under S4E_CHUNK=entry:<kernel> it grades that one
#     kernel, its two rows in this gate's table, and writes no suite row; every test_*_bench_suite.sh and test_demos_suite.sh carries rr_load, rr_list, rr_end
# FAIL-ONCE: on util_score_row.py before this gate's landing every from-progress here refuses "no suite table for key" (rc 2) -- arms 2-6 red.
set -uo pipefail
GATE_NAME=test_gate_from_progress_takes_a_bench_or_demo_population_from_its_runner
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SR="$HERE/util_score_row.py"
[ -x "$HERE/../../SCRIP/scrip" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no SCRIP binary beside the harness -- the runners' list mode checks the build first"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
D="$T/corpus/demos/prolog"; B="$T/corpus/benchmarks/raku"; E="$T/corpus/demos/icon"; mkdir -p "$D/alpha" "$D/beta" "$D/gamma" "$B" "$E"
for n in alpha beta gamma; do printf ':- initialization((write(%s), nl)).\n' $n > "$D/$n/$n.pl"; printf '%s\n' $n > "$D/$n/$n.ref"; done
printf '# CONTAINERS.tsv\ngamma/gamma.pl\tLOADED_BY\talpha/alpha.pl -- fixture\n' > "$D/CONTAINERS.tsv"
for k in k1 k2 k3; do printf 'say "%s";\n' $k > "$B/$k.raku"; printf '%s\n' $k > "$B/$k.ref"; done
printf 'k3\tOUTSIDE_SLOW\tfixture: 40 s a run\n' > "$B/OUTSIDE.tsv"
DB="$T/results.tsv"
printf 'ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\tfingerprint\tconfig\n' > "$DB"
row() { printf '2026-10-23T18:00:%02d\tabc1234\tc0ffee0\tcoo\tbenchmark\t%s\t%s\t%s\t%s\t%s\t1.0\t\t\tshipped\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$DB"; }
row 1 prolog-demos prolog demos/prolog/alpha/alpha.pl m3 PASS; row 2 prolog-demos prolog demos/prolog/alpha/alpha.pl m4 PASS
row 3 prolog-demos prolog demos/prolog/beta/beta.pl m3 PASS; row 4 prolog-demos prolog demos/prolog/beta/beta.pl m4 FAIL
row 5 raku-bench-ref raku k1 m3 PASS; row 6 raku-bench-ref raku k1 m4 PASS; row 7 raku-bench-ref raku k2 m3 PASS; row 8 raku-bench-ref raku k2 m4 PASS
export S4E_SEAT=coo S4E_CORPUS_ROOT="$T/corpus" S4E_PROGRESS_DB="$DB" DEMOS_DIR="$D" BENCH_RAKU_DIR="$B"
fails=0
ck() { if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
l1="$(cd "$HERE/../../SCRIP" && S4E_LIST=1 bash "$HERE/test_demos_suite.sh" prolog 2>&1)"; lr=$?
ck "1 the demos runner lists alpha and beta, names gamma RR_EXCL, grades nothing (rc $lr)" \
   '[ "$lr" = 0 ] && [ "$(grep -c "^RR_POP demos/prolog/" <<<"$l1")" = 2 ] && grep -q "^RR_EXCL demos/prolog/gamma/gamma.pl$" <<<"$l1" && ! grep -q -E "^(alpha|beta)" <<<"$l1"'
o2="$(python3 "$SR" from-progress --suite prolog-demos --dry-run 2>&1)"
ck "2 prolog-demos from-progress: 1/2 excluded=1" 'grep -q "would set prolog-demos -> 1/2 excluded=1 " <<<"$o2"'
o3="$(python3 "$SR" from-progress --suite raku-bench-ref --dry-run 2>&1)"
ck "3 raku-bench-ref from-progress: 2/2 excluded=1 (k3 OUTSIDE_SLOW)" 'grep -q "would set raku-bench-ref -> 2/2 excluded=1 " <<<"$o3"'
o4="$(S4E_CHUNK=entry:alpha python3 "$SR" from-progress --suite prolog-demos --dry-run 2>&1)"
ck "4 an S4E_CHUNK in the environment does not narrow the population (1/2)" 'grep -q "would set prolog-demos -> 1/2 excluded=1 " <<<"$o4"'
o5="$(DEMOS_DIR="$E" python3 "$SR" from-progress --suite icon-demos --dry-run 2>&1)"; r5=$?
ck "5 a runner that lists no member refuses rc 2 (rc $r5)" '[ "$r5" = 2 ] && grep -q "^REFUSE(2)" <<<"$o5"'
Z="$T/corpus2/demos/prolog"; mkdir -p "$Z/alpha" "$Z/beta"; cp "$D/alpha/alpha.pl" "$D/alpha/alpha.ref" "$Z/alpha/"; cp "$D/beta/beta.pl" "$D/beta/beta.ref" "$Z/beta/"
o6="$(S4E_CORPUS_ROOT="$T/corpus2" DEMOS_DIR="$Z" python3 "$SR" from-progress --suite prolog-demos --dry-run 2>&1)"
ck "6 a runner that names nothing out reads excluded=0, never a stale count (1/2 excluded=0)" 'grep -q "would set prolog-demos -> 1/2 excluded=0 " <<<"$o6"'
# THE SEAM CENSUS (CEO-1927): every bench runner and the demos runner takes S4E_CHUNK and S4E_LIST through lib_rr.sh -- one runner behaviourally,
# all of them by their source. The real snobol4 bench tree, read only; its one graded kernel's rows go to this gate's scratch table.
unset S4E_CORPUS_ROOT DEMOS_DIR BENCH_RAKU_DIR
SB="$HERE/../../corpus/benchmarks/snobol4"; nsb=$(find "$SB" -maxdepth 1 -type f -name '*.sno' | wc -l); k1=$(find "$SB" -maxdepth 1 -type f -name '*.sno' -printf '%f\n' | LC_ALL=C sort | head -1 | sed 's/\.sno$//')
l7="$(cd "$HERE/../../SCRIP" && S4E_LIST=1 timeout 120 bash "$HERE/test_snobol4_bench_suite.sh" 2>&1)"
ck "7 the snobol4 bench runner lists its $nsb kernels and grades nothing" '[ "$(grep -c "^RR_POP " <<<"$l7")" = "$nsb" ] && [ "$nsb" -gt 0 ] && ! grep -q "^SUITE_BOARD" <<<"$l7"'
o8="$(cd "$HERE/../../SCRIP" && S4E_SCORE_NO_WRITE="gate $GATE_NAME" S4E_CHUNK="entry:$k1" timeout 600 bash "$HERE/test_snobol4_bench_suite.sh" 2>&1)"
ck "8 under S4E_CHUNK=entry:$k1 it grades that one kernel (total=1, 2 rows in the scratch table) and writes no suite row" \
   'grep -q "^SUITE_BOARD.* total=1 " <<<"$o8" && [ "$(awk -F"\t" -v k="$k1" "\$6==\"snobol4-bench-ref\" && \$8==k" "$DB" | wc -l)" = 2 ] && grep -q "^SNOBOL4_BENCH_REF_CHUNK entry:$k1 " <<<"$o8" && ! grep -q "row write: yes" <<<"$o8"'
bad9=""; for r in "$HERE"/test_*_bench_suite.sh "$HERE/test_demos_suite.sh"; do for w in 'lib_rr.sh" && rr_load' 'rr_list' 'rr_end'; do grep -qF "$w" "$r" || bad9="$bad9 ${r##*/}:$w"; done; done
ck "9 every bench runner and the demos runner carries rr_load, rr_list and rr_end${bad9:+ (missing:$bad9)}" '[ -z "$bad9" ]'
echo "population: 9 arms, a scratch demo tree of 3 (1 container), a scratch raku bench of 3 (1 OUTSIDE), 8 progress rows"
if [ "$fails" != 0 ]; then printf '%s\n' "$o2" "$o3" "$o5" | grep -E 'REFUS|would set' | head -4 | sed 's/^/    /'; echo "⛔ GATE FAIL [$GATE_NAME]: $fails arm(s) red"; exit 1; fi
echo "✅ GATE PASS [$GATE_NAME]: a bench or demo row assembles from the readings over the population its runner lists"
exit 0

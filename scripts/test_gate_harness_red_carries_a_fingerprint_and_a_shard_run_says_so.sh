#!/usr/bin/env bash
# test_gate_harness_red_carries_a_fingerprint_and_a_shard_run_says_so.sh -- A RED IS A BUCKET, NOT A VERDICT (hq_snobol4 2026-09-16 to the
# coo; rows instruments-a-red-is-a-bucket-every-board-prints-a-fingerprint-beside-each-red-and-the-denominator-of-its-comparison and
# instruments-a-sharded-harness-run-appends-progress-rows-wearing-a-full-boards-suite-name-the-shard-is-not-in-the-row).
#
# THE DEFECT, MEASURED: SnoRungs read 1962/1981 with a defect and 1962/1981 without it, all seven SNOBOL4 package boards at their totals,
# red NAME SETS identical -- while spitbol_testpgms test1 was red on base AND head with a DIFFERENT first diff each time (ERROR AT 137
# ERRTYPE 22 became ERROR AT 72 ERRTYPE 29).  Counts and name sets treat reds as interchangeable, so a program that got MORE wrong
# while staying red was invisible.  And a --shard k/N harness run appended progress rows a reader could not tell from a full board's.
#
# ARMS (a three-entry fixture cut from the SNOBOL4 rungs into mktemp, entry 2's ref broken so it reads FAIL both runs; a scratch DB):
#   (a) run A: the RED line for entry 2 carries [fp=<md5/8 of our stdout> rc=<n>] and the DB row's note carries the same fp= token
#   (b) run B: entry 2's SOURCE replaced by entry 3's (same name, same broken ref): the count is unchanged (1 red, same name) and the
#       fingerprint MOVED -- the shape change the counts and name sets could not see
#   (c) a --shard 1/2 run stamps shard=1/2 into every progress row it appends; the full runs stamped none
# FAIL_ONCE=1 copies run A's fingerprint over run B's before arm (b) asserts, to prove the arm trips.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H="$HERE/corpus_suite_harness.py"; RUNGS="${S4E_CORPUS_ROOT:-$HERE/../../corpus}/tests/snobol4"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -f "$H" ] || refuse "no harness at $H"
[ -x "$HERE/../../SCRIP/scrip" ] || refuse "no ./scrip binary beside ../harness/scripts/ -- make first"
[ -f "$RUNGS/ALL.sno" ] && [ -f "$RUNGS/ALL.ref" ] || refuse "no rungs pair under $RUNGS to cut a fixture from"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_red_fp.XXXXXX")" || refuse "mktemp failed"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/tests/snobol4"; F="$W/tests/snobol4/ALL.sno"; R="$W/tests/snobol4/ALL.ref"
head -3 "$RUNGS/ALL.sno" > "$F"; head -3 "$RUNGS/ALL.ref" > "$R"
[ "$(wc -l < "$F")" = 3 ] && [ "$(wc -l < "$R")" = 3 ] || refuse "the rungs' first three lines did not cut cleanly"
NAME="$(sed -n 2p "$F" | sed 's/.*;\* //')"; [ -n "$NAME" ] || refuse "cannot read entry 2's name from its ';* name' tail"
sed -i '2s/.*/FIXTURE-BROKEN-REF: this line is not what the program prints/' "$R"
DB="$W/results.tsv"; printf 'ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\n' > "$DB"
fails=0; checks=0; ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: every red carries a fingerprint of our stdout, and a sharded run says so in its rows ==="
run(){ S4E_PROGRESS_DB="$DB" timeout -k 5 180 python3 "$H" run "$F" "$R" --modes m3 "$@" 2>&1; }
outA="$(run)"; rcA=$?; [ "$rcA" -le 1 ] || refuse "run A could not grade the fixture (rc=$rcA): $(tail -3 <<<"$outA")"
lineA="$(grep -E "^  FAIL m3 $NAME:" <<<"$outA" | head -1)"; fpA="$(grep -oE 'fp=[0-9a-f]{8}' <<<"$lineA" | head -1)"
dbA="$(awk -F'\t' -v p="$NAME" '$8==p && $9=="m3" && $10=="FAIL"{print $12}' "$DB" | tail -1)"
[ -n "$fpA" ] && grep -qE 'rc=(-|[0-9]+)\]' <<<"$lineA" && grep -qw "$fpA" <<<"$dbA" \
  && ck ok "(a) run A: the RED line carries [$fpA rc=…] and the DB note for $NAME carries the same token ('$dbA')" \
  || ck no "(a) run A: RED line '$lineA' / DB note '$dbA'"
src3="$(sed -n 3p "$F" | sed 's/;\* [^;]*$//')"; python3 - "$F" "$src3" "$NAME" <<'PY'
import sys; f, src, name = sys.argv[1:4]; L = open(f, encoding="utf-8").read().split("\n"); L[1] = src + ";* " + name; open(f, "w", encoding="utf-8").write("\n".join(L))
PY
outB="$(run)"; rcB=$?; [ "$rcB" -le 1 ] || refuse "run B could not grade the fixture (rc=$rcB): $(tail -3 <<<"$outB")"
lineB="$(grep -E "^  FAIL m3 $NAME:" <<<"$outB" | head -1)"; fpB="$(grep -oE 'fp=[0-9a-f]{8}' <<<"$lineB" | head -1)"
[ -n "${FAIL_ONCE:-}" ] && fpB="$fpA"
fA="$(grep -oE 'm3_fail=[0-9]+' <<<"$outA" | head -1)"; fB="$(grep -oE 'm3_fail=[0-9]+' <<<"$outB" | head -1)"
[ -n "$fpB" ] && [ "$fA" = "$fB" ] && [ "$fA" = "m3_fail=1" ] && [ "$fpA" != "$fpB" ] \
  && ck ok "(b) run B: same count ($fA, same name $NAME) and the fingerprint MOVED ($fpA -> $fpB): the shape change counts cannot see" \
  || ck no "(b) run B: counts $fA/$fB, fingerprints $fpA/$fpB, line '$lineB'"
outC="$(run --shard 1/2)"; rcC=$?; [ "$rcC" -le 1 ] || refuse "the shard run could not grade (rc=$rcC): $(tail -2 <<<"$outC")"
nsh="$(awk -F'\t' '$12 ~ /shard=1\/2/' "$DB" | wc -l)"; nfull="$(awk -F'\t' 'NR>1 && $12 !~ /shard=/' "$DB" | wc -l)"; ntot="$(awk -F'\t' 'NR>1' "$DB" | wc -l)"
[ "$nsh" -ge 1 ] && [ "$nfull" -ge 2 ] && [ $((nsh + nfull)) = "$ntot" ] && grep -q '^SUITE_BOARD .*shard=1/2 ' <<<"$outC" \
  && ck ok "(c) the --shard 1/2 run stamped shard=1/2 on its $nsh row(s) and the SUITE_BOARD line; the $nfull full-run rows carry none" \
  || ck no "(c) shard rows $nsh, full rows $nfull, total $ntot; board: $(grep '^SUITE_BOARD' <<<"$outC" | cut -c1-120)"
echo "population: $checks arm(s) graded, $fails FAIL"
[ "$fails" = 0 ] && { echo "GATE PASS [harness_red_carries_a_fingerprint_and_a_shard_run_says_so]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [harness_red_carries_a_fingerprint_and_a_shard_run_says_so]: $fails of $checks arms FAIL"; exit 1

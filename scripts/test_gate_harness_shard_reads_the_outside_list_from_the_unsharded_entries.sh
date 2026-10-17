#!/usr/bin/env bash
# test_gate_harness_shard_reads_the_outside_list_from_the_unsharded_entries.sh -- A SHARD GRADES ITS SLICE, BUT THE OUTSIDE LIST IS
# CHECKED AGAINST THE WHOLE SUITE (hq_snobol4 2026-09-24 08:2x; ceo CEO-1233 (d); row instruments-the-harness-shard-filter-cuts-the-
# entry-list-before-the-outside-list-presence-check-so-every-sharded-run-of-a-suite-with-an-outside-list-refuses).
#
# THE DEFECT, MEASURED: on SCRIP 83d50401d / corpus fdc8455da, --shard 1/6 .. 6/6 of the SNOBOL4 rungs REFUSED rc=2 in 6 of 6
# shards. The shard filter (d837851d7) cut the entry list BEFORE the outside-list presence check (c2178f2b6 / 2fae6f711) built its
# present-set from it, so every outside name that fell in another shard read "declares entries that are not in this suite -- a stale
# outside list". All 8 names ARE in the rungs, and test_corpus_snobol4.sh passes --outside with --shard, so SnoRungs' --shard/--combine
# road refused whenever it was used; the monolithic run was unaffected.
#
# THE CURE UNDER TEST: the present-set is the unsharded suite's; the per-shard outside= still counts only the entries THIS shard
# removed, so the shards' fields sum to the monolithic board's exactly as board_combine adds them.
#
# ARMS (hermetic: a four-entry suite cut from the live rungs under mktemp in a tests/snobol4/ALL.sno layout, entries 2 and 3
# declared outside in the SIBLING list, so the list spans both shards of --shard k/2 -- k=1 takes entries 1 and 3, k=2 takes 2 and 4;
# the progress DB redirected by S4E_PROGRESS_DB to a scratch table; a fixture outside the corpus is not a board, CEO-547):
#   (a) --shard 1/2 GRADES (rc <= 1, no refusal): SUITE_BOARD shard=1/2 total=1 shipped=2 outside=1, entry 3 named OUTSIDE
#   (b) --shard 2/2 GRADES the same way: shard=2/2 total=1 shipped=2 outside=1, entry 2 named OUTSIDE
#   (c) the two shards SUM to the monolithic run: total 1+1=2, shipped 2+2=4, outside 1+1=2
#   (d) the staleness check still bites under --shard: a list naming an entry the WHOLE suite lacks refuses rc=2 in both shards,
#       naming that entry and not the in-suite outside names
# FAIL_ONCE=1 blanks shard 1's captured SUITE_BOARD line before arm (a) grades -- what the old order produced, a refusal with no
# board -- to prove the arm trips. The row's fail-once against the old order itself is this gate RED on the cure's parent, quoted in
# the landing's commit message.
# rc 0 = every arm holds; rc 1 = a FAIL named; rc 2 = REFUSED-TO-GRADE (no binary, no rungs to cut the fixture from).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H="$HERE/corpus_suite_harness.py"; RUNGS="${S4E_CORPUS_ROOT:-$HERE/../../corpus}/tests/snobol4"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -f "$H" ] || refuse "no harness at $H"
[ -x "$HERE/../../SCRIP/scrip" ] || refuse "no ./scrip binary beside ../harness/scripts/ -- make first"
"$HERE/util_require_fresh.sh" --gate test_gate_harness_shard_reads_the_outside_list_from_the_unsharded_entries >/dev/null 2>&1 \
  || refuse "this tree's binary is stale or unbuilt -- the harness would refuse every run for that, and arms (a)/(b) would read its refusal as the defect. Run 'make'."
[ -f "$RUNGS/ALL.sno" ] && [ -f "$RUNGS/ALL.ref" ] || refuse "no rungs pair under $RUNGS to cut a fixture from"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_shard_outside.XXXXXX")" || refuse "mktemp failed"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/tests/snobol4"; F="$W/tests/snobol4/ALL.sno"; R="$W/tests/snobol4/ALL.ref"; O="$W/tests/snobol4/ALL.outside.tsv"
head -4 "$RUNGS/ALL.sno" > "$F"; head -4 "$RUNGS/ALL.ref" > "$R"
[ "$(wc -l < "$F")" = 4 ] && [ "$(wc -l < "$R")" = 4 ] || refuse "the rungs' first four lines did not cut cleanly"
nm(){ sed -n "${1}p" "$F" | sed 's/.*;\* //'; }
N2="$(nm 2)"; N3="$(nm 3)"; [ -n "$N2" ] && [ -n "$N3" ] && [ "$N2" != "$N3" ] || refuse "cannot read entries 2 and 3's names from their ';* name' tails"
printf '%s\tORACLE_REFUSES\tfixture: outside, graded by shard 2 of 2\n%s\tORACLE_REFUSES\tfixture: outside, graded by shard 1 of 2\n' "$N2" "$N3" > "$O"
DB="$W/results.tsv"; printf 'ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\n' > "$DB"
echo "    fixture: 4 entries cut from the rungs; outside = $N2 (shard 2 of 2), $N3 (shard 1 of 2)"
fails=0; checks=0; ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: a --shard run checks the outside list against the unsharded suite, and the shards sum to the whole ==="
run(){ S4E_PROGRESS_DB="$DB" timeout -k 5 180 python3 "$H" run "$F" "$R" --modes m3 "$@" 2>&1; }
fld(){ grep -oE " $2=[0-9]+" <<<"$1" | head -1 | cut -d= -f2; }
out1="$(run --shard 1/2)"; rc1=$?; b1="$(grep '^SUITE_BOARD ' <<<"$out1")"
[ -n "${FAIL_ONCE:-}" ] && b1=""
[ "$rc1" -le 1 ] && grep -q ' shard=1/2 ' <<<"$b1" && [ "$(fld "$b1" total)" = 1 ] && [ "$(fld "$b1" shipped)" = 2 ] && [ "$(fld "$b1" outside)" = 1 ] \
  && grep -q "^OUTSIDE_BASELINE $N3 ORACLE_REFUSES: " <<<"$out1" && ! grep -q "^OUTSIDE_BASELINE $N2 " <<<"$out1" \
  && ck ok "(a) --shard 1/2 grades (rc=$rc1): shard=1/2 total=1 shipped=2 outside=1, $N3 named OUTSIDE" \
  || ck no "(a) --shard 1/2: rc=$rc1, board '${b1:-<none>}', last lines: $(tail -2 <<<"$out1" | tr '\n' ' ' | cut -c1-240)"
out2="$(run --shard 2/2)"; rc2=$?; b2="$(grep '^SUITE_BOARD ' <<<"$out2")"
[ "$rc2" -le 1 ] && grep -q ' shard=2/2 ' <<<"$b2" && [ "$(fld "$b2" total)" = 1 ] && [ "$(fld "$b2" shipped)" = 2 ] && [ "$(fld "$b2" outside)" = 1 ] \
  && grep -q "^OUTSIDE_BASELINE $N2 ORACLE_REFUSES: " <<<"$out2" && ! grep -q "^OUTSIDE_BASELINE $N3 " <<<"$out2" \
  && ck ok "(b) --shard 2/2 grades (rc=$rc2): shard=2/2 total=1 shipped=2 outside=1, $N2 named OUTSIDE" \
  || ck no "(b) --shard 2/2: rc=$rc2, board '${b2:-<none>}', last lines: $(tail -2 <<<"$out2" | tr '\n' ' ' | cut -c1-240)"
outM="$(run)"; rcM=$?; bM="$(grep '^SUITE_BOARD ' <<<"$outM")"
[ "$rcM" -le 1 ] || refuse "the monolithic run could not grade the fixture (rc=$rcM): $(tail -3 <<<"$outM")"
ok_sum=1; sums=""
for k in total shipped outside; do
  a="$(fld "$b1" $k)"; b="$(fld "$b2" $k)"; m="$(fld "$bM" $k)"; sums="$sums $k ${a:-?}+${b:-?}=${m:-?}"
  [ -n "$a" ] && [ -n "$b" ] && [ -n "$m" ] && [ $((a + b)) = "$m" ] || ok_sum=0
done
[ "$ok_sum" = 1 ] && [ "$(fld "$bM" outside)" = 2 ] \
  && ck ok "(c) the shards SUM to the monolithic board (shard sum / whole):$sums" \
  || ck no "(c) shard sum / whole:$sums; monolithic board '$bM'"
printf 'no_such_entry_in_this_suite\tORACLE_REFUSES\tfixture: a stale row\n' >> "$O"
outS1="$(run --shard 1/2)"; rcS1=$?; outS2="$(run --shard 2/2)"; rcS2=$?
st(){ grep -o "declares entries that are not in this suite: \[[^]]*\]" <<<"$1" | head -1; }
[ "$rcS1" = 2 ] && [ "$rcS2" = 2 ] && [ "$(st "$outS1")" = "declares entries that are not in this suite: ['no_such_entry_in_this_suite']" ] \
  && [ "$(st "$outS2")" = "$(st "$outS1")" ] \
  && ck ok "(d) a list naming an entry the whole suite lacks still refuses rc=2 in both shards, naming only that entry" \
  || ck no "(d) stale list under --shard: rc=$rcS1/$rcS2, '$(st "$outS1")' / '$(st "$outS2")'"
echo "population: $checks arm(s) graded, $fails FAIL"
[ "$fails" = 0 ] && { echo "GATE PASS [harness_shard_reads_the_outside_list_from_the_unsharded_entries]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [harness_shard_reads_the_outside_list_from_the_unsharded_entries]: $fails of $checks arms FAIL"; exit 1

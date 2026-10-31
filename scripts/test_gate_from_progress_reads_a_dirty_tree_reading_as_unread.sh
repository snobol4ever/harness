#!/usr/bin/env bash
# test_gate_from_progress_reads_a_dirty_tree_reading_as_unread.sh -- A READING ON A DIRTY TREE IS UNREAD FOR ROW ASSEMBLY (ceo CEO-2060, 2026-10-31,
# ruling YES on the coo's finding COO-441 (5): "A reading taken on a dirty tree measures no tree on origin (a number's tree is part of its label), so
# util_score_row.py from-progress reads it as UNREAD for row assembly, even where that lowers a row"). Seats' dev passes write progress rows stamped
# <hash>-dirty; on 10-30 such readings moved ProRosetta to 481/481, SWI and ProPuzzles on cures not on origin.
# THE FIXTURE (a scratch corpus and progress DB; the real table and DB are never read or written): rebus master reb-rungs, entries r1 r2 r3.
#   ARM 1  r1 PASS both modes on a clean tree; r2 PASS m3 clean and PASS m4 ONLY on abc1234-dirty; r3 PASS both modes ONLY on dirty trees:
#          SUITE_ROW prints read=2 unread=1 half_read=1 (r2's m4 and all of r3 unread), never read=3 unread=0 half_read=0, so the row cannot be
#          written until a clean re-grade (from-progress refuses a row with an unread or half-read entry, CEO-1676).
#   ARM 2  SUITE_ROW_DIRTY_UNREAD names r2 and r3.
#   ARM 3  an older CLEAN reading under a newer dirty one stands: r2 m4 FAIL on the clean tree before its dirty PASS -> r2 reads FAIL, 1/3, half_read=0.
#   ARM 4  a clean re-grade after the dirty one counts: r2 m4 PASS on a clean tree, later -> 2/3.
# PROVEN TO FAIL on harness 3157665's util_score_row.py (before the cure): all four arms FAIL -- it reads read=3 unread=0 half_read=0 (pass=3, every
# dirty PASS counted), prints no SUITE_ROW_DIRTY_UNREAD, lets the newer dirty PASS displace the clean FAIL (arm 3: 2/3) and r3's dirty PASSes count (arm 4: 3/3).
# EXIT 0 every arm holds; 1 an arm failed; 2 could not measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SR="${FROM_PROGRESS_SR:-$HERE/util_score_row.py}"
[ -f "$SR" ] || { echo "GATE REFUSE(2): $SR is missing"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/corpus/tests/rebus"
printf 'rank,entry,origin\n1,r1,x\n2,r2,x\n3,r3,x\n' > "$T/corpus/tests/rebus/ALL.csv"
DB="$T/results.tsv"
printf 'ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\tfingerprint\tconfig\n' > "$DB"
row() { printf '2026-10-31T10:00:%02d\t%s\tc0ffee0\tcoo\trungs\trebus-rungs\trebus\t%s\t%s\t%s\t1.0\t\t\trr=1\n' "$1" "$2" "$3" "$4" "$5" >> "$DB"; }
run() { S4E_CORPUS_ROOT="$T/corpus" S4E_PROGRESS_DB="$DB" python3 "$SR" from-progress --suite reb-rungs --dry-run 2>&1; }
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
row 1 abc1234 r1 m3 PASS; row 2 abc1234 r1 m4 PASS; row 3 abc1234 r2 m3 PASS; row 4 abc1234-dirty r2 m4 PASS
row 5 abc1234-dirty r3 m3 PASS; row 6 abc1234-dirty r3 m4 PASS
o1="$(run)"; r1=$?
[ "$r1" = 0 ] || { tail -5 <<<"$o1"; echo "GATE REFUSE(2): from-progress --dry-run did not run (rc $r1)"; exit 2; }
grep -q 'would set reb-rungs -> ' <<<"$o1" || { tail -5 <<<"$o1"; echo "GATE REFUSE(2): from-progress printed no row"; exit 2; }
ck "1 readings on a dirty tree are unread: read=2 unread=1 half_read=1" 'grep -q "^SUITE_ROW suite=reb-rungs pass=[0-9]* total=3 read=2 unread=1 half_read=1 " <<<"$o1"'
ck "2 SUITE_ROW_DIRTY_UNREAD names r2 and r3" 'grep -q "^SUITE_ROW_DIRTY_UNREAD 2: r2 r3 " <<<"$o1"'
row 0 abc1234 r2 m4 FAIL
o3="$(run)"
ck "3 the older clean reading under the dirty one stands: r2 reads FAIL, 1/3, half_read=0" 'grep -q "would set reb-rungs -> 1/3 stamped" <<<"$o3" && grep -q " unread=1 half_read=0 " <<<"$o3"'
row 9 abc1234 r2 m4 PASS
o4="$(run)"
ck "4 a clean re-grade after the dirty reading counts: 2/3" 'grep -q "would set reb-rungs -> 2/3 stamped" <<<"$o4"'
echo "GATE from-progress-dirty-tree-unread: $((n - fails))/$n arms hold (population: 3 entries, 9 readings, 4 of them dirty)"
[ "$fails" = 0 ] || exit 1
exit 0

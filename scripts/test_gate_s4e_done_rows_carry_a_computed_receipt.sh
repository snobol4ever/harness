#!/usr/bin/env bash
# test_gate_s4e_done_rows_carry_a_computed_receipt.sh -- EVERY DONE IS COMPUTED, AND THE CLAIM CARRIES THE COMPUTATION (coo
# 2026-09-16; ceo CEO-790/793; row instruments-a-done-row-with-no-claim-and-no-receipt-was-closed-by-a-path-that-bypassed-
# the-computed-done-name-and-refuse-it).
#
# THE DEFECT: prolog-failed-initialization-goal-exits-1-where-swipl-exits-0 read DONE in QUEUE.tsv with NO claim, NO ledger
# landing and a RED DONE-WHEN on origin -- it flipped FREE -> DONE between the 2026-08-30 and 2026-09-01 queue backups by a path
# that never wrote a claim. `done` computes completion (it says so) but wrote only the word DONE, so a DONE reached any other
# way was indistinguishable, invisible to the census, and silently kept by `sweep`. 17 such rows in QUEUE.tsv on 2026-09-16.
#
# THE CURE UNDER TEST: (1) `done` appends 'RECEIPT done rc=0 tree=<scrip> elapsed=<s> via=computed|override <ts> by <seat>' to
# the claim; (2) util_queue_visibility_census.py class R names every DONE row (QUEUE.tsv) whose claim does not carry DONE;
# (3) `sweep` moves the receipted rows and REFUSES rc=2 naming the rest.
#
# ARMS (hermetic scratch postoffice under mktemp; S4E_POST/S4E_SEAT/S4E_HOME; MODE TRIO):
#   (a) `done` on a live claimed row with a real green DONE-WHEN writes the RECEIPT line (rc=0, tree=, via=computed) then DONE
#   (b) the census names the orphan DONE row (no claim) under R and not the receipted one; rc=1
#   (c) `sweep` moves the receipted row to QUEUE.done.tsv, keeps the orphan, exits 2 naming it
# FAIL_ONCE=1 strips the RECEIPT line from (a)'s claim before its assertion, to prove the arm trips.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="$HERE/s4e_msg.sh"; CENSUS="$HERE/util_queue_visibility_census.py"
ROOT="$(cd "$HERE/../.." && pwd)"
[ -f "$MSG" ] && [ -f "$CENSUS" ] || { echo "⛔ REFUSED-TO-GRADE: $MSG or $CENSUS missing"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSED-TO-GRADE: mktemp failed"; exit 2; }; trap 'rm -rf "$W"' EXIT
PO="$W/po"; ME=hq_T
mkdir -p "$PO/tasks" "$PO/claims" "$PO/released" "$PO/$ME/inbox" "$PO/ceo/inbox"; : > "$PO/BOARD.md"; printf 'TRIO\n' > "$PO/MODE"
printf '# fixture\n1\tfx-live\t%s\tFREE\n1\tfx-receipted\t%s\tDONE\n1\tfx-orphan\tunassigned\tDONE\n' "$ME" "$ME" > "$PO/QUEUE.tsv"; : > "$PO/QUEUE.done.tsv"
for t in fx-live fx-receipted fx-orphan; do printf '# TASK %s\nGOAL: gate fixture.\nDONE-WHEN: grep -q green-body %s/green.txt\nLINKS: none\n## NEXT\n(none)\n## LEDGER\n' "$t" "$W" > "$PO/tasks/$t.task.md"; done
printf 'green-body\n' > "$W/green.txt"
printf '%s\nDONE\nRECEIPT done rc=0 tree=fixture elapsed=0s via=computed 2026-09-16T00:00:00Z by %s\n' "$ME" "$ME" > "$PO/claims/fx-receipted.claim"
run(){ S4E_POST="$PO" S4E_SEAT="$ME" S4E_HOME="$ROOT" S4E_NO_BANNER=1 bash "$MSG" "$@" 2>&1; }
fails=0; checks=0; ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: every DONE is computed and the claim carries the computation (CEO-790/793) ==="
run claim fx-live >/dev/null; out="$(run done fx-live)"; rc=$?
[ -n "${FAIL_ONCE:-}" ] && sed -i '/^RECEIPT /d' "$PO/claims/fx-live.claim"
rl="$(grep '^RECEIPT done rc=0 tree=' "$PO/claims/fx-live.claim" | head -1)"
if [ "$rc" = 0 ] && [ -n "$rl" ] && grep -q 'via=computed' <<<"$rl" && grep -q "by $ME" <<<"$rl" && grep -q '^DONE$' "$PO/claims/fx-live.claim" && grep -qP "\tfx-live\t.*\tDONE" "$PO/QUEUE.tsv"; then
  ck ok "(a) done wrote the RECEIPT line (rc=0, tree=, via=computed, by $ME) and DONE into the claim; the queue column reads DONE"
else ck no "(a) rc=$rc receipt='$rl' -- got: $(tail -2 <<<"$out" | cut -c1-160)"; fi
cout="$(S4E_PO="$PO" S4E_HOME="$ROOT" python3 "$CENSUS" 2>&1)"; crc=$?
rblock="$(sed -n '/^R  DONE row/,/^[A-Z][A-Z0-9! ]* /p' <<<"$cout")"
if [ "$crc" = 1 ] && grep -q 'fx-orphan' <<<"$rblock" && ! grep -q 'fx-receipted' <<<"$rblock" && ! grep -q 'fx-live' <<<"$rblock"; then
  ck ok "(b) the census names fx-orphan under R and neither receipted row; rc=1"
else ck no "(b) census rc=$crc -- R block: $(head -4 <<<"$rblock" | tr '\n' '|' | cut -c1-200)"; fi
sout="$(run sweep)"; src=$?
if [ "$src" = 2 ] && grep -q 'fx-receipted' "$PO/QUEUE.done.tsv" && grep -qP '\tfx-orphan\t' "$PO/QUEUE.tsv" && ! grep -qP '\tfx-receipted\t' "$PO/QUEUE.tsv" && grep -q 'fx-orphan' <<<"$sout" && grep -q 'NO COMPUTED RECEIPT' <<<"$sout"; then
  ck ok "(c) sweep moved the receipted rows, kept fx-orphan, and REFUSED rc=2 naming it"
else ck no "(c) sweep rc=$src -- got: $(grep -E 'sweep|REFUSES|fx-' <<<"$sout" | head -3 | cut -c1-160)"; fi
echo "population: $checks arm(s) graded, $fails FAIL"
[ "$fails" = 0 ] && { echo "GATE PASS [s4e_done_rows_carry_a_computed_receipt]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [s4e_done_rows_carry_a_computed_receipt]: $fails of $checks arms FAIL"; exit 1

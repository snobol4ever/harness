#!/usr/bin/env bash
# test_gate_s4e_claim_refuses_a_topic_with_no_queue_row.sh -- `claim` LOCKS A ROW, SO A TOPIC WITH NO QUEUE.tsv ROW IS REFUSED rc 2
# BEFORE ANY LOCK IS WRITTEN OR ANNOUNCED (coo 2026-10-14). THE DEFECT, MEASURED ON THE LIVE BUS: hq_templates ran `claim
# zzz-nonexistent-row` at 17:09:19Z; the bus wrote postoffice/claims/zzz-nonexistent-row.claim, printed "claimed", and sent a
# WORK STARTED notice to every seat, for a topic with no QUEUE row and no baton -- s4e_set_row_state is a no-op on a rowless
# topic and its rc was swallowed by `|| true`.
# THREE ARMS against a THROWAWAY postoffice under mktemp -- never the live one:
#   (1) ROWLESS-REFUSED  claim of a topic no QUEUE row names: rc 2, the refusal names the topic, NO claim file, NO notice in any inbox
#   (2) REAL-ADMITTED    claim of a FREE fixture row: rc 0, claim file written, column CLAIMED:<seat>, a notice delivered -- the cure
#                        costs no real row, and it proves the notice counter of arm (1) can see a notice at all
#   (3) NO-LEFTOVER      after both, claims/ holds exactly the real row's lock
# FAIL-ONCE: a mutant with the guard line deleted must read arm (1) red.
# EXIT 0 all arms hold and the mutant goes red; 1 otherwise; 2 REFUSED (fixture cannot be built).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="$HERE/s4e_msg.sh"
[ -f "$MSG" ] || { echo "⛔ REFUSED: $MSG missing"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSED: mktemp failed"; exit 2; }
MAINPID=$$; trap '[ "$BASHPID" = "$MAINPID" ] && rm -rf "$W"' EXIT
PO="$W/po"; ME=cto; HQ=ceo; OTHER=cfo
FIX() { env -u S4E_PID_LOCK -u S4E_NO_DISPATCH_PROBE -u S4E_PREMISE_OVERRIDE -u S4E_NO_PREMISE_CHECK \
        S4E_HOME="$W" S4E_POST="$PO" S4E_SEAT="$ME" S4E_NO_BANNER=1 S4E_NO_DISPATCH_PROBE=1 "$@"; }
mk_po() {
  rm -rf "$PO"; mkdir -p "$PO/tasks" "$PO/claims" "$PO/released" "$PO/$ME/inbox" "$PO/$HQ/inbox" "$PO/$OTHER/inbox" || return 2
  : > "$PO/BOARD.md"; : > "$PO/QUEUE.done.tsv"; printf 'QUARTET\n' > "$PO/MODE"; printf '5\n' > "$PO/PROTOCOL-VERSION"
  printf '%s\n' "$HQ" > "$PO/$ME/HQ"
  { printf '# gate fixture queue\n'; printf '2\tt-real\t%s\tFREE\n' "$HQ"; } > "$PO/QUEUE.tsv"
  printf '# TASK t-real\nGOAL: gate fixture.\nDONE-WHEN: test -f "$S4E_HOME/po/NOPE"\nLINKS: none\n## NEXT\ngo\n## LEDGER\n' \
    > "$PO/tasks/t-real.task.md"; }
notices() { find "$PO" -path '*/inbox/*' -type f 2>/dev/null | wc -l; }
col() { grep -P "^[0-9]+\t\Q$1\E\t" "$PO/QUEUE.tsv" 2>/dev/null | head -1 | cut -f4; }
arm() {   # arm <label> <script> -> 0 iff every contract holds on <script>
  local lbl="$1" s="$2" ok=1 out rc n0 n1
  mk_po || { echo "  [$lbl] ⛔ fixture unbuildable"; return 2; }
  n0=$(notices); out="$(FIX bash "$s" claim t-no-such-row 2>&1)"; rc=$?; n1=$(notices)
  if [ "$rc" = 2 ] && grep -q 't-no-such-row' <<<"$out" && [ ! -e "$PO/claims/t-no-such-row.claim" ] && [ "$n1" = "$n0" ]; then
       echo "  [$lbl] ok    (1) ROWLESS-REFUSED: rc 2, the topic named, no lock, no notice"
  else echo "  [$lbl] FAIL  (1) ROWLESS-REFUSED: rc=$rc lock=$([ -e "$PO/claims/t-no-such-row.claim" ] && echo yes || echo no) notices $n0->$n1: $(tail -1 <<<"$out" | cut -c1-140)"; ok=0; fi
  n0=$(notices); out="$(FIX bash "$s" claim t-real 2>&1)"; rc=$?; n1=$(notices)
  if [ "$rc" = 0 ] && [ -f "$PO/claims/t-real.claim" ] && [ "$(col t-real)" = "CLAIMED:$ME" ] && [ "$n1" -gt "$n0" ]; then
       echo "  [$lbl] ok    (2) REAL-ADMITTED: rc 0, locked, CLAIMED:$ME, $((n1-n0)) notice(s) delivered"
  else echo "  [$lbl] FAIL  (2) REAL-ADMITTED: rc=$rc column=$(col t-real) notices $n0->$n1: $(tail -1 <<<"$out" | cut -c1-140)"; ok=0; fi
  local left; left="$(ls "$PO/claims" | tr '\n' ' ')"
  if [ "$left" = "t-real.claim " ]; then echo "  [$lbl] ok    (3) NO-LEFTOVER: claims/ holds only t-real.claim"
  else echo "  [$lbl] FAIL  (3) NO-LEFTOVER: claims/ holds [$left]"; ok=0; fi
  [ "$ok" = 1 ]; }
echo "=== gate: claim refuses a topic with no QUEUE.tsv row (coo 2026-10-14) ==="
arm live "$MSG"; live=$?
[ "$live" = 2 ] && { echo "⛔ REFUSED: the fixture could not be built"; exit 2; }
MUT="$W/s4e_msg.mutant.sh"
grep -v 'no QUEUE.tsv row is named' "$MSG" > "$MUT"
[ "$(wc -l < "$MUT")" -lt "$(wc -l < "$MSG")" ] || { echo "⛔ REFUSED: the guard line is not where the mutant expects it -- the mutation would be a no-op"; exit 2; }
for f in "$HERE"/lib_*.sh; do [ -e "$W/$(basename "$f")" ] || ln -s "$f" "$W/$(basename "$f")"; done
arm mutant "$MUT" > "$W/mut.out" 2>&1; mut=$?
sed 's/^/    /' "$W/mut.out"
grep -q 'FAIL  (1)' "$W/mut.out"; mred=$?
echo "population: 3 arms on the live script, 1 mutant"
if [ "$live" = 0 ] && [ "$mred" = 0 ]; then echo "GATE PASS [s4e_claim_refuses_a_topic_with_no_queue_row]: 3 of 3 arms hold; the mutant without the guard reds arm (1)"; exit 0; fi
[ "$live" = 0 ] || echo "⛔ GATE RED: an arm failed on the live script"
[ "$mred" = 0 ] || echo "⛔ GATE RED: the mutant without the guard did NOT red arm (1) -- the gate cannot see the defect"
exit 1

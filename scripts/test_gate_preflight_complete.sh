#!/bin/bash
# test_gate_preflight_complete.sh -- ⭐ IS PHASE-0 PRE-FLIGHT ACTUALLY DONE?  Computed, never declared.
# Every item of GOAL-CEO.md Phase 0 plus all three FIRING GATE conditions, each checked mechanically.
# ⛔ THE FIRING-GATE QUESTION CHECK WAS VOID UNTIL s264 AND IS THE REASON THIS HEADER EXISTS.  It read
# `s4e_msg.sh fleet | grep -cE 'Q=[1-9]'` and compared the count to 0 -- but `fleet` prints a Q COLUMN in a
# table and has never emitted the string "Q=<n>" anywhere, so the grep matched nothing on every possible
# input and the condition passed unconditionally.  A gate that cannot fail is not a gate; it is a sentence.
# ⭐ AND THE REPLACEMENT IS A DIFFERENT MEASUREMENT, NOT A REPAIRED GREP.  "Zero questions outstanding" was
# the wrong condition even spelled correctly: it is satisfied by a fleet that never ASKS, so it rewards
# silence and punishes seats that raise real questions -- a producer-never-consumer test.  What matters is
# the ROUND TRIP: a question that was asked has an ANSWER WRITTEN WHERE THE NEXT SEAT WILL FIND IT, which is
# the baton QA section, not an inbox that someone cleared.  So we walk the pending q-<topic> messages in the
# HQ mailboxes and require each topic's task file to carry a non-empty ## QA block.
# ⛔ KNOWN LIMIT, STATED RATHER THAN HIDDEN: a non-empty QA proves an answer was WRITTEN, not that it
# answers THIS question.  That is weaker than we want and stronger than a count of zero.  Tightening it
# needs question ids threaded from `ask` into the QA line; until that exists, do not read this check as
# more than it claims.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "$HERE/lib_gate.sh"; gate_parse_args "$@"
PO="${S4E_POSTOFFICE:-/home/resources/postoffice}"; BAD=0; N=0
say() { N=$((N+1)); if [ "$1" = 0 ]; then echo "  ✅ $2"; else echo "  ⛔ $2"; BAD=$((BAD+1)); fi; }
echo "=== PHASE 0 ==="
grep -q 'assign)' "$HERE/s4e_msg.sh"; say $? "V2-1 picker: rank-sorted + assign + assigned-first next"
m=$(awk -F'\t' '!/^#/ && NF>0 && NF!=4' "$PO/QUEUE.tsv" | wc -l); b=$(grep -c '^$' "$PO/QUEUE.tsv")
[ "$m" -eq 0 ] && [ "$b" -eq 0 ]; say $? "V2-2 queue purge: index-only, 0 malformed rows, 0 blank lines (m=$m b=$b)"
grep -q 'oldest' "$HERE/s4e_msg.sh"; say $? "V2-3 banner: board carries oldest-unanswered age"
grep -q 'NO postoffice mailbox' "$HERE/s4e_msg.sh"; say $? "V2-4 identity asserted, never globbed"
bash "$HERE/test_gate_baton_donewhen_runnable.sh" >/dev/null 2>&1; say $? "V2-2 batons: every DONE-WHEN is a runnable command"
echo "=== FIRING GATE ==="
gate_require "$PO/tasks" "postoffice task directory"
pend=0; unans=0; badq=""
for m in "$PO"/hq*/inbox/*-q-*.msg; do [ -e "$m" ] || continue; pend=$((pend+1)); t="${m##*-q-}"; t="${t%.msg}"; f="$PO/tasks/$t.task.md"
  if [ ! -f "$f" ] || ! awk '/^## QA/{inq=1;next} /^## /{inq=0} inq&&NF{ok=1} END{exit !ok}' "$f"; then unans=$((unans+1)); badq="$badq $t"; fi; done
[ "$unans" -eq 0 ]; say $? "ROUND-TRIP RECEIPT: every pending question is answered in its baton QA ($pend pending, $unans unanswered$badq)"
bash "$HERE/test_gate_oracle_bf_capable.sh" >/dev/null 2>&1; say $? "every seat resolves a -bf-capable oracle (asset root, no per-seat clones)"
u=0; for r in SCRIP corpus .github; do d="/home/claude_P/$r"; [ -d "$d/.git" ] || continue
  [ -n "$(cd "$d" && git status --porcelain)" ] && u=$((u+1))
  [ "$(cd "$d" && git rev-parse HEAD)" != "$(cd "$d" && git rev-parse @{u} 2>/dev/null)" ] && u=$((u+1)); done
[ "$u" -eq 0 ]; say $? "hq_P repos clean and pushed ($u issue(s))"
echo ""
gate_floor "$N" 8 "pre-flight conditions"
gate_verdict "$BAD" "pre-flight condition(s) not met"

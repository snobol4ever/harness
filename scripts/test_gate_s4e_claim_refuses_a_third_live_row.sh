#!/usr/bin/env bash
# test_gate_s4e_claim_refuses_a_third_live_row.sh -- GATE (ceo CEO-2078, 2026-10-31): A SEAT HOLDS AT MOST TWO LIVE ROWS, AND THE
# BUS ENFORCES IT. CLAUDE.md SOP 6 said "a seat holds at most two claims" and nothing checked it: at 10:4x today the coo held four
# and hq_templates three, every extra one waiting on another seat and HELD AS A CLAIM instead of parked, so the picker starved the
# rows under them and util_ceo_followups.py flagged them stale for 41 hours. A rule that converts a structural gap into an
# instruction is obeyed for a week and then not (CEO-1002), so the count lives in `claim`.
# WHAT COUNTS: a claim of mine that is HELD and whose queue row is not BLOCKED-ON:/PARKED-AWAITING:/PARKED. WHAT DOES NOT: an
# ASSIGNED-BY claim not yet RUNNING (the ceo's lock, not my hold: the go is never refused) and a parked row (the park IS the remedy).
# ⛔ EVERY ARM IS HERMETIC: a scratch postoffice, its own MODE, queue and batons; no real inbox is touched and nothing is built.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="${SUT:-$HERE/s4e_msg.sh}"
refuse(){ echo "⛔ GATE REFUSES (rc=2): $*"; exit 2; }
[ -f "$SUT" ] || refuse "the bus under test is not at $SUT"
FAIL=0; N=0
arm(){ N=$((N+1)); if [ "$1" = 0 ]; then echo "  ✅ $2"; else echo "  ⛔ $2"; FAIL=$((FAIL+1)); fi; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_claimcap.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/tasks" "$W/claims" "$W/released"
for s in ceo cto cfo coo hq_prolog; do mkdir -p "$W/$s/inbox" "$W/$s/archive"; done
printf 'SEPTET\n# scratch line 2: LANES: prolog=hq_prolog\n' > "$W/MODE"
printf '0\tprolog-first\tcoo\tFREE\n0\tprolog-second\tcoo\tFREE\n0\tprolog-third\tcoo\tFREE\n0\tprolog-assigned-not-started\tcoo\tASSIGNED:coo\n0\tprolog-other-seat-blocker\thq_prolog\tCLAIMED:hq_prolog\n' > "$W/QUEUE.tsv"
for t in prolog-first prolog-second prolog-third prolog-assigned-not-started prolog-other-seat-blocker; do
  printf '# TASK %s\nGOAL: gate fixture.\nDONE-WHEN: true\n## NEXT\nfixture\n## QA\n## LEDGER\n' "$t" > "$W/tasks/$t.task.md"; done
printf 'coo\nASSIGNED-BY ceo 2026-10-31T00:00:00Z\n' > "$W/claims/prolog-assigned-not-started.claim"
printf 'hq_prolog\nRUNNING\n' > "$W/claims/prolog-other-seat-blocker.claim"
B(){ S4E_SEAT=coo S4E_POST="$W" bash "$SUT" "$@" 2>&1; }

echo "--- ARMS 1-2: TWO LIVE ROWS ARE ALLOWED; AN ASSIGNED-BY CLAIM NOT YET RUNNING DOES NOT COUNT ---"
o1="$(B claim prolog-first)"; r1=$?; o2="$(B claim prolog-second)"; r2=$?
[ "$r1" = 0 ] && [ "$r2" = 0 ] && [ "$(head -1 "$W/claims/prolog-second.claim")" = coo ]
arm $? "the first and the second claim succeed with an unstarted assignment also on file (rc $r1, $r2)"

echo "--- ARMS 3-4: THE THIRD IS REFUSED, NOTHING WRITTEN, NOTHING ANNOUNCED ---"
o3="$(B claim prolog-third)"; r3=$?
[ "$r3" = 1 ] && [[ "$o3" == *"REFUSED"* && "$o3" == *"prolog-first"* && "$o3" == *"prolog-second"* && "$o3" == *"BLOCKED-ON"* ]]
arm $? "rc 1, the refusal names both live rows and the park remedy (rc=$r3)"
[ ! -e "$W/claims/prolog-third.claim" ] && [ "$(ls "$W/ceo/inbox"/*claim-notice-prolog-third* 2>/dev/null | wc -l)" = 0 ] && [ "$(awk -F'\t' '$2=="prolog-third"{print $4}' "$W/QUEUE.tsv")" = FREE ]
arm $? "no claim file, no notice, the row still FREE"

echo "--- ARMS 5-7: PARKING THE ROW THAT WAITS ON ANOTHER SEAT FREES THE SLOT -- BY THE HOLDER (claim released) OR AROUND THE CLAIM (state skipped) ---"
o5="$(B park prolog-first BLOCKED-ON:prolog-other-seat-blocker)"; r5=$?
o6="$(B claim prolog-third)"; r6=$?
[ "$r5" = 0 ] && [ "$r6" = 0 ] && [ "$(head -1 "$W/claims/prolog-third.claim")" = coo ] && [[ "$(awk -F'\t' '$2=="prolog-first"{print $4}' "$W/QUEUE.tsv")" == BLOCKED-ON:* ]]
arm $? "the holder's own park BLOCKED-ON releases its hold and the third claim succeeds (park rc=$r5, claim rc=$r6)"
printf '0\tprolog-fourth\tcoo\tFREE\n' >> "$W/QUEUE.tsv"
printf '# TASK prolog-fourth\nGOAL: gate fixture.\nDONE-WHEN: true\n## NEXT\nfixture\n## QA\n## LEDGER\n' > "$W/tasks/prolog-fourth.task.md"
o7="$(B claim prolog-fourth)"; r7=$?
[ "$r7" = 1 ] && [[ "$o7" == *"prolog-second"* && "$o7" == *"prolog-third"* ]]
arm $? "two live again (second, third): a fourth is refused (rc=$r7)"
o8="$(S4E_SEAT=ceo S4E_POST="$W" S4E_PARK_FORCE=1 bash "$SUT" park prolog-second BLOCKED-ON:prolog-other-seat-blocker 2>&1)"; r8=$?
o9="$(B claim prolog-fourth)"; r9=$?
[ "$r8" = 0 ] && [ "$(head -1 "$W/claims/prolog-second.claim" 2>/dev/null)" = coo ] && [ "$r9" = 0 ] && [ "$(head -1 "$W/claims/prolog-fourth.claim")" = coo ]
arm $? "the ceo's park AROUND the claim keeps the claim file, and its BLOCKED-ON state takes it out of the count: the fourth now succeeds (park rc=$r8, claim rc=$r9)"

echo "graded $N arm(s)"
if [ "$FAIL" = 0 ]; then echo "✅ GATE PASS: claim refuses a third live row and the park is the remedy."; exit 0; fi
echo "⛔ GATE FAIL: $FAIL of $N arm(s) red -- an unenforced cap is a cap nobody keeps."; exit 1

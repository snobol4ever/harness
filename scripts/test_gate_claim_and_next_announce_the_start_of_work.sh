#!/usr/bin/env bash
# test_gate_claim_and_next_announce_the_start_of_work.sh -- GATE (coo 2026-09-20, ceo CEO-1002 rank 0, row
# instruments-claim-and-next-announce-the-start-of-work-to-every-standing-seat).
#
# ⛔⭐ THE DEFECT IS IN THE BUS, NOT IN A SEAT. claim and next LOCKED A ROW SILENTLY: the bus had claim, assign, ask
# and send, and not one of them told another seat that work had STARTED -- so the only instrument that ever reported
# a collision was a branch that would not fast-forward. WITNESS, self-reported by hq_snobol4 2026-09-20: they measured
# the no_layout census for an hour, the cto spent their own hour on the same 30 entries and the same cause and landed
# first at SCRIP 83fb80ee7, and hq_snobol4 found out on a failed pull. BOTH SEATS HELD ROWS. The rows did not overlap
# BY NAME and did overlap BY POPULATION -- which a claim on a topic string can never catch.
# ⛔ LON, IN-CHAT TO THE ceo, VERBATIM: "Them not telegramming before starting is YOUR FAULT! You set up the system."
# The ceo's own first draft of the law read TELEGRAM THE LANE WHEN YOU START and they retracted it in the same
# ruling: a rule that converts a structural gap into an instruction is obeyed for a week and then not. So what is
# graded here is MECHANISM -- what the bus does when a seat takes a row -- and never a discipline.
#
# ⛔⭐ THE STOOD-DOWN HALF IS NOT A COURTESY, IT IS THE OTHER DIRECTION OF THE SAME TEST (arm 2). "Announce to every
# standing seat" is only meaningful if a stood-down seat is NOT announced to: a notice in a mailbox nobody is reading
# is the noise that trains seats to stop reading notices, and an implementation that mails every mailbox passes arm 1
# and fails here. The roster comes from s4e_mode_stands, the ONE dispatch authority `next` itself refuses on.
#
# ⛔ EVERY ARM IS HERMETIC: its own scratch postoffice, its own MODE, its own queue and batons. It never reads the live
# MODE, never touches a real inbox, and builds nothing.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="${SUT:-$HERE/s4e_msg.sh}"
refuse(){ echo "⛔ GATE REFUSES (rc=2): $*"; exit 2; }
[ -f "$SUT" ] || refuse "the bus under test is not at $SUT"
FAIL=0; N=0
arm(){ N=$((N+1)); if [ "$1" = 0 ]; then echo "  ✅ $2"; else echo "  ⛔ $2"; FAIL=$((FAIL+1)); fi; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_announce.XXXXXX")" || refuse "mktemp failed"
cleanup(){ chmod -R u+w "$W" 2>/dev/null; rm -rf "$W"; }
trap cleanup EXIT
mkdir -p "$W/tasks" "$W/claims" "$W/released"
# the roster of SEPTET as CEO-1662 redefined it (2026-10-11): hq_snobol4, hq_icon and hq_prolog stand, hq_raku and hq_pascal are stood down
STANDING="ceo cto cfo coo hq_snobol4 hq_icon hq_prolog"
DOWN="hq_raku hq_pascal seat07"
for s in $STANDING $DOWN; do mkdir -p "$W/$s/inbox" "$W/$s/archive"; done
# ⭐ THE FIXTURE BRINGS ITS OWN MODE, and it is SEPTET because that is the mode whose roster splits the HQs -- a
# fixture under a mode that admits everybody could not tell arm 1 from arm 2.
printf 'SEPTET\n# scratch line 2 for a gate fixture: LANES: icon=hq_icon prolog=hq_prolog snobol4=hq_snobol4 pascal=ceo raku=ceo\n' > "$W/MODE"
printf '0\trow-the-coo-takes\tcoo\tFREE\n0\trow-the-cfo-already-holds\tcfo\tCLAIMED:cfo\n0\trow-for-the-picker\tcto\tFREE\n' > "$W/QUEUE.tsv"
for t in row-the-coo-takes row-the-cfo-already-holds row-for-the-picker; do
  printf '# TASK %s\nGOAL: gate fixture.\nDONE-WHEN: true\n## NEXT\nfixture\n## QA\n## LEDGER\n' "$t" > "$W/tasks/$t.task.md"; done
# a LIVE claim held by another seat, so the neighbourhood has something true to print
printf 'cfo\nRUNNING\n' > "$W/claims/row-the-cfo-already-holds.claim"

echo "--- ARMS 1-3: A CLAIM ANNOUNCES ITSELF TO EVERY STANDING SEAT, AND TO NO STOOD-DOWN ONE ---"
out="$(S4E_SEAT=coo S4E_POST="$W" bash "$SUT" claim row-the-coo-takes 2>&1)"; rc=$?
miss=""; for s in $STANDING; do [ "$s" = coo ] && continue
  n=$(ls "$W/$s/inbox"/*claim-notice-row-the-coo-takes* 2>/dev/null | wc -l); [ "$n" = 1 ] || miss="$miss $s($n)"; done
[ "$rc" = 0 ] && [ -z "$miss" ]; arm $? "every OTHER standing seat got exactly one notice (rc=$rc)${miss:+ -- missing:$miss}"
extra=""; for s in $DOWN coo; do
  n=$(ls "$W/$s/inbox"/*claim-notice* 2>/dev/null | wc -l); [ "$n" = 0 ] || extra="$extra $s($n)"; done
[ -z "$extra" ]; arm $? "and NO stood-down seat and not the claimant itself were mailed -- the roster is the mode's${extra:+ -- mailed:$extra}"
body="$(cat "$W/ceo/inbox"/*claim-notice-row-the-coo-takes* 2>/dev/null)"
[[ "$body" == *"WORK STARTED"* && "$body" == *coo* && "$body" == *row-the-coo-takes* ]]
arm $? "the notice NAMES THE SEAT AND THE TOPIC in its body, not only in its filename"

echo "--- ARMS 4-5: THE CALLER READS THE NEIGHBOURHOOD AT THE MOMENT IT TAKES THE ROW ---"
[[ "$out" == *"the neighbourhood"* && "$out" == *"LIVE CLAIM"* && "$out" == *cfo* && "$out" == *row-the-cfo-already-holds* ]]
arm $? "claim prints every OTHER seat's live claim back to the caller, by holder and by row"
[[ "$out" == *"announced to 6 standing seat(s)"* ]]
arm $? "and says how many seats it told, so a delivery that did not happen cannot read as one"

echo "--- ARM 6: next TAKES ITS LOCK THROUGH claim AND MUST NOT SWALLOW THE ANNOUNCEMENT ---"
nout="$(S4E_SEAT=cto S4E_POST="$W" bash "$SUT" next 2>&1)"; nrc=$?
[[ "$nout" == *"the neighbourhood"* ]] && [[ "$nout" == *"LIVE CLAIM"* ]]
arm $? "the served seat sees the neighbourhood too (next rc=$nrc) -- the picker is where a seat is LEAST likely to know what its neighbours are on"
n=$(ls "$W/ceo/inbox"/*claim-notice-row-for-the-picker* 2>/dev/null | wc -l)
[ "$n" = 1 ]; arm $? "and next's own take announced itself exactly once, not twice (the inner claim is the only announcer)"

echo "--- ARM 7: AN ANNOUNCEMENT THAT FAILS NAMES ITSELF AND DOES NOT FAIL THE CLAIM ---"
printf '0\trow-with-a-deaf-neighbour\tcoo\tFREE\n' >> "$W/QUEUE.tsv"
printf '# TASK row-with-a-deaf-neighbour\nGOAL: gate fixture.\nDONE-WHEN: true\n## NEXT\nfixture\n## QA\n## LEDGER\n' > "$W/tasks/row-with-a-deaf-neighbour.task.md"
chmod 000 "$W/hq_icon/inbox"
out2="$(S4E_SEAT=coo S4E_POST="$W" bash "$SUT" claim row-with-a-deaf-neighbour 2>&1)"; rc2=$?
chmod 755 "$W/hq_icon/inbox"
[ "$rc2" = 0 ] && [ "$(head -1 "$W/claims/row-with-a-deaf-neighbour.claim")" = coo ] && [[ "$out2" == *"COULD NOT ANNOUNCE to hq_icon"* ]]
arm $? "an undeliverable notice is NAMED, the claim still stands (rc=$rc2), and the count does not include it"
[[ "$out2" == *"announced to 5 standing seat(s)"* ]]
arm $? "and the number printed is what was DELIVERED -- an instrument that reports success while doing nothing is the recurring failure"

echo "graded $N arm(s)"
if [ "$FAIL" = 0 ]; then echo "✅ GATE PASS: the bus announces the start of work to every standing seat and shows the caller the neighbourhood."; exit 0; fi
echo "⛔ GATE FAIL: $FAIL of $N arm(s) red -- a claim that nobody hears is the collision nobody can prevent."; exit 1

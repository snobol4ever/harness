#!/usr/bin/env bash
# test_gate_claim_and_next_announce_the_start_of_work.sh -- GATE for the claim notice and the picker that takes no lock.
# RE-CUT by the cio 2026-11-07 (job 400, bus-gate-claim-and-next-announce-reads-the-pre-step-21-notice-contract): the lane contract this
# gate graded before (the officer and every standing holder in a lane told WORK STARTED; next re-printed the neighbourhood) is retired.
# The two landed contracts are the law, and this gate grades only them:
#   box-scheduler step 21 (CTO-496): a claim notice goes ONLY to a seat whose LIVE row's TOUCHES: paths meet the claimed row's. A row
#     with no TOUCHES: line tells nobody, and the claim says so. The notice names the overlapping path. The count the claim prints is
#     the count DELIVERED. A notice that cannot be delivered is named, and the claim stands.
#   box-scheduler step 32: next locks nothing and announces no take. It serves; `claim <topic>` is the only writer of a RUNNING claim.
# ⛔ EVERY ARM IS HERMETIC: its own scratch postoffice (S4E_POST), its own MODE, queue, batons and claims. It never reads the live MODE
# or queue, never touches a real inbox, and builds nothing.
# FAIL-ONCE (gates-and-witnesses section 1): a mutant copy of the bus that mails EVERY live holder (the overlap test sed to true) must
# read RED under arm 1. The gate refuses (rc 2) if that sed does not apply to the bus under test.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="${SUT:-$HERE/s4e_msg.sh}"
export S4E_HOME="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
# THE QUEUE IS HERMETIC TOO: next reaches for the queue daemon, and the live one is port 11300. Every bus call here runs on a port with
# NO daemon (a free port, bound and released), so next's reserve refuses on its own socket and never touches the live queue.
S4E_QUEUE_PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')" || S4E_QUEUE_PORT=""
[ -n "$S4E_QUEUE_PORT" ] || { echo "⛔ GATE REFUSES (rc=2): no free port to isolate the queue daemon"; exit 2; }
export S4E_QUEUE_PORT
refuse(){ echo "⛔ GATE REFUSES (rc=2): $*"; exit 2; }
[ -f "$SUT" ] || refuse "the bus under test is not at $SUT"
[ -f "$HERE/lib_release_guard.sh" ] && [ -f "$HERE/lib_donewhen.sh" ] || refuse "the bus sources lib_release_guard.sh and lib_donewhen.sh beside it; the mutant copy cannot run without them"
FAIL=0; N=0
arm(){ N=$((N+1)); if [ "$1" = 0 ]; then echo "  ✅ $2"; else echo "  ⛔ $2"; FAIL=$((FAIL+1)); fi; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_announce.XXXXXX")" || refuse "mktemp failed"
cleanup(){ chmod -R u+w "$W" 2>/dev/null; rm -rf "$W"; }
trap cleanup EXIT
SEATS="cto coo worker_17 worker_18 worker_19 worker_20"
# frow <dir> <topic> <owner> <state> <touches-or-empty>: one QUEUE row and its baton; the TOUCHES: line only when given
frow(){ local D="$1" t="$2" o="$3" st="$4" tc="$5"
  printf '0\t%s\t%s\t%s\n' "$t" "$o" "$st" >> "$D/QUEUE.tsv"
  { printf '# TASK %s\nGOAL: gate fixture.\nDONE-WHEN: true\n' "$t"; [ -n "$tc" ] && printf 'TOUCHES: %s\n' "$tc"; printf '## NEXT\nfixture\n## QA\n## LEDGER\n'; } > "$D/tasks/$t.task.md"; }
# mkfix <dir>: two holders with LIVE rows (worker_18 touches harness/scripts/, worker_20 touches SCRIP/src/lower/) and four FREE rows.
mkfix(){ local D="$1" s
  mkdir -p "$D/tasks" "$D/claims" "$D/released"
  for s in $SEATS; do mkdir -p "$D/$s/inbox" "$D/$s/archive"; done
  printf 'TENET\nROSTER: %s\n' "$SEATS" > "$D/MODE"
  : > "$D/QUEUE.tsv"; : > "$D/CLAIMS.log"
  frow "$D" holder-harness-row worker_18 CLAIMED:worker_18 'harness/scripts/'
  printf 'worker_18\nRUNNING\n' > "$D/claims/holder-harness-row.claim"
  frow "$D" holder-scrip-row worker_20 CLAIMED:worker_20 'SCRIP/src/lower/'
  printf 'worker_20\nRUNNING\n' > "$D/claims/holder-scrip-row.claim"
  frow "$D" row-touching-harness-file worker_19 FREE 'harness/scripts/s4e_msg.sh'
  frow "$D" row-with-no-touches coo FREE ''
  frow "$D" row-into-a-deaf-inbox worker_17 FREE 'harness/scripts/'
  frow "$D" row-for-the-picker cto FREE 'harness/scripts/s4e_msg.sh'
}
# ovn <dir> <seat> <topic>: overlap notices (body OVERLAP BY PATH) delivered to one seat about one claim
ovn(){ local f n=0; for f in "$1/$2/inbox"/*claim-notice-"$3".msg; do [ -f "$f" ] || continue; grep -q 'OVERLAP BY PATH' "$f" && n=$((n+1)); done; echo "$n"; }
# allov <dir> <topic>: the same, summed over every seat's inbox
allov(){ local s tot=0; for s in $SEATS; do tot=$((tot+$(ovn "$1" "$s" "$2"))); done; echo "$tot"; }
# snap <dir>: every file's checksum, so an arm can prove a command wrote nothing the contract covers. The seat's identity lock
# ($PO/<seat>/.pid, flock-held) is the one file every verb writes, claim-free and announce-free, so it is the one file left out.
snap(){ find "$1" -type f ! -name .pid -exec cksum {} + 2>/dev/null | sort; }

mkfix "$W"

echo "--- ARM 1: A CLAIM NOTIFIES ONLY THE HOLDER WHOSE LIVE ROW TOUCHES THE SAME PATH (box-scheduler step 21) ---"
out1="$(S4E_SEAT=worker_19 S4E_POST="$W" bash "$SUT" claim row-touching-harness-file 2>&1 < /dev/null)"; rc1=$?
[ "$rc1" = 0 ] && [ -f "$W/claims/row-touching-harness-file.claim" ] || refuse "the claim verb did not take the fixture row (rc=$rc1): $out1"
[ "$(ovn "$W" worker_18 row-touching-harness-file)" = 1 ] && [ "$(ovn "$W" worker_20 row-touching-harness-file)" = 0 ]
arm $? "the holder whose live row touches harness/scripts/ got exactly one notice; the holder whose row touches SCRIP/src/lower/ got none"
del1="$(allov "$W" row-touching-harness-file)"
[ "$del1" = 1 ]
arm $? "and that is the only overlap notice in any inbox ($del1 delivered): the idle seats and the claimant were not mailed"

echo "--- ARM 2: A ROW WITH NO TOUCHES TELLS NOBODY, AND THE CLAIM SAYS SO ---"
out2="$(S4E_SEAT=coo S4E_POST="$W" bash "$SUT" claim row-with-no-touches 2>&1 < /dev/null)"; rc2=$?
[ "$rc2" = 0 ] && [ "$(allov "$W" row-with-no-touches)" = 0 ] && [[ "$out2" == *"NO TOUCHES ON THE BATON"* ]]
arm $? "a claimed row with no TOUCHES: line mailed nobody, and the claim printed that no overlap could be computed (rc=$rc2)"

echo "--- ARM 3: THE NOTICE NAMES THE CLAIMANT, THE ROW AND THE OVERLAPPING PATH ---"
body="$(cat "$W/worker_18/inbox"/*claim-notice-row-touching-harness-file.msg 2>/dev/null)"
[[ "$body" == *"OVERLAP BY PATH"* && "$body" == *"worker_19"* && "$body" == *"row-touching-harness-file"* && "$body" == *"harness/scripts"* ]]
arm $? "the notice in worker_18's inbox names the claimant, the row and the overlapping path in its body"

echo "--- ARM 4: next SERVES A ROW AND WRITES NOTHING (box-scheduler step 32) ---"
before="$(snap "$W")"
nout="$(S4E_SEAT=cto S4E_POST="$W" bash "$SUT" next 2>&1 < /dev/null)"; nrc=$?
after="$(snap "$W")"
[[ "$nout" == *"take it: s4e_msg.sh claim"* ]] && [ "$before" = "$after" ]
arm $? "next names a FREE row to take (rc=$nrc) and writes nothing the contract covers: no inbox, claim, queue row, baton or CLAIMS.log line"

echo "--- ARM 5: THE COUNT THE CLAIM PRINTS IS THE COUNT DELIVERED ---"
sent1="$(printf '%s\n' "$out1" | grep -o 'notices_sent=[0-9]*' | head -1 | cut -d= -f2)"
[ -n "$sent1" ] && [ "$sent1" = "$del1" ]
arm $? "the claim printed notices_sent=${sent1:-none} and the inboxes hold $del1 overlap notice(s) for it"

echo "--- ARM 6: AN UNDELIVERABLE NOTICE IS NAMED, IS NOT COUNTED, AND THE CLAIM STANDS ---"
rm -rf "$W/worker_18/inbox"
out6="$(S4E_SEAT=worker_17 S4E_POST="$W" bash "$SUT" claim row-into-a-deaf-inbox 2>&1 < /dev/null)"; rc6=$?
sent6="$(printf '%s\n' "$out6" | grep -o 'notices_sent=[0-9]*' | head -1 | cut -d= -f2)"
del6="$(allov "$W" row-into-a-deaf-inbox)"
[ "$rc6" = 0 ] && [ "$(head -1 "$W/claims/row-into-a-deaf-inbox.claim" 2>/dev/null)" = worker_17 ] && [[ "$out6" == *"COULD NOT ANNOUNCE to worker_18"* ]] && [[ "$out6" == *"FAILED"* ]] && [ -n "$sent6" ] && [ "$sent6" = "$del6" ] && [ "$del6" -ge 1 ]
arm $? "worker_18 (no inbox) is named COULD NOT ANNOUNCE, the claim stands (rc=$rc6), and notices_sent=${sent6:-none} equals the $del6 delivered"

echo "--- FAIL-ONCE: A MUTANT THAT MAILS EVERY LIVE HOLDER IS RED UNDER ARM 1 ---"
MUT="$W/mutant"; mkdir -p "$MUT"; cp "$HERE/lib_release_guard.sh" "$HERE/lib_donewhen.sh" "$MUT/"
sed 's/if \[ -s "\$_mine" \] && _ov="\$(s4e_paths_overlap "\$_mine" "\$_theirs")"; then/if _ov=ALL; then/' "$SUT" > "$MUT/s4e_msg.sh"
grep -q 'if _ov=ALL; then' "$MUT/s4e_msg.sh" || refuse "the mutant sed did not apply: the overlap test line in $SUT is not the one this gate mutates"
MF="$W/mfix"; mkfix "$MF"
S4E_SEAT=worker_19 S4E_POST="$MF" bash "$MUT/s4e_msg.sh" claim row-touching-harness-file > /dev/null 2>&1 < /dev/null
[ "$(ovn "$MF" worker_20 row-touching-harness-file)" -ge 1 ]
arm $? "the mutant mailed worker_20, whose row touches SCRIP/src/lower/ and not the claimed path: arm 1 trips on it, so the gate can see the defect it grades"

echo "graded $N arm(s)"
if [ "$FAIL" = 0 ]; then echo "GATE OK [test_gate_claim_and_next_announce_the_start_of_work]: a claim notice reaches exactly the live holders whose TOUCHES paths meet the claimed row's, a row with no TOUCHES tells nobody, the printed count is the delivered count, and next takes no lock."; exit 0; fi
echo "GATE FAIL [test_gate_claim_and_next_announce_the_start_of_work]: $FAIL of $N arm(s) red -- a claim that nobody hears is the collision nobody can prevent; a claim everybody hears is the notice nobody reads."; exit 1

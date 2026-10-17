#!/usr/bin/env bash
# test_gate_s4e_next_honours_owner.sh -- `next` MUST NOT HAND A SEAT A ROW ANOTHER SEAT OWNS.
# Row picker-skips-a-row-owned-by-another-seat-unless-that-seat-picks (ceo ruling 2026-09-03, on hq_B's case).
#
# THE MEASURED DEFECT: `next` served hq_B the rank-0 row port-exit-value-contract-untagged-rax-forges-dt-fail
# whose QUEUE owner column read hq_P. The picker sorted by rank and read only the STATE column, so ownership
# was advisory AT THE MOMENT OF THE PICK and a rank-0 row tagged to a seat in flight went to whoever typed
# `next` first.
# ⛔ WHY SKIP IS THE RIGHT DEFAULT -- THE COST IS ASYMMETRIC: a wrongly-served row puts TWO seats on one piece
# of work, and because a claim HIDES the row from its owner's own picker, the owner is locked out SILENTLY. A
# wrongly-skipped row costs one `claim` typed deliberately.
#
# WHAT IT PROVES, against a THROWAWAY postoffice (S4E_POST) so the live queue is never read or written:
#   (a) a FREE row owned by ANOTHER seat is NOT served, and the skip is REPORTED, not silent -- a skip nobody
#       can see is indistinguishable from the row not existing, which is the failure this picker keeps having.
#   (b) a FREE row owned by the PICKER is served (else the rule would just be "never serve owned rows").
#   (c) a FREE row with owner `unassigned` is still served -- the common case must not regress.
#   (d) rank still wins among servable rows: the owned rank-0 row is skipped and the rank-1 row is served,
#       proving the skip does not simply stop the scan at the first obstacle.
#   (e) `claim` on the other-seat row STILL WORKS -- the ruling constrains the automatic pick, never the
#       deliberate override, and a gate that did not check this could pass against a picker that made the row
#       unreachable entirely.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="${SUT:-$HERE/s4e_msg.sh}"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -f "$SUT" ] || refuse "picker under test not found: $SUT"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_owner.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/tasks" "$W/claims" "$W/released"
# ⛔ Mailbox layout is $PO/<seat>/inbox, and the picker REFUSES an identity with no mailbox rather than
# creating one on the fly (LAW 6: on-the-fly creation is how the phantom claude01/ mailbox was born).
for s in hq_B hq_P; do mkdir -p "$W/$s/inbox" "$W/$s/archive"; done
# ⛔ THE MODE IS PROBED, NOT BELIEVED (COO-80, 2026-09-19, row instrument-the-nineteen-non-gc-blocking-arms).
# This line read `printf 'DUO\n' > "$W/MODE"`. DUO gained a stand-down arm for EVERY HQ on 2026-09-19
# (CEO-907), so the picker refused to dispatch both of this fixture's seats and SEVEN of its nine arms went
# red -- none of them about the owner column, which is this gate's whole subject. The mode string was
# incidental to what is graded here and became load-bearing without anyone choosing it. The rule now lives in
# lib_gate.sh as a sourced authority: candidates are probed against the picker with an empty queue (claiming
# nothing) and the first that admits the seat is used, so a future stand-down moves this fixture to the next
# candidate instead of silently emptying it.
. "$HERE/lib_gate.sh"
command -v gate_pick_dispatchable_mode >/dev/null 2>&1 || refuse "lib_gate.sh carries no gate_pick_dispatchable_mode -- the mode-probe rule is a sourced authority and a gate must never keep a private copy of it"
_FIXTURE_MODE="$(gate_pick_dispatchable_mode "$SUT" "$W" hq_B DECTET NONET FLEET-16)" || refuse "the picker refuses to dispatch hq_B under every candidate mode (DECTET, NONET, FLEET-16), so this fixture cannot put an HQ in front of the owner column at all. That is a finding about the stand-down table, not a reason to lower the bar: add a mode in which an HQ stands, or report that none does."
printf '%s\n' "$_FIXTURE_MODE" > "$W/MODE"
echo "    fixture: MODE = $_FIXTURE_MODE (probed -- the first candidate under which the picker dispatches hq_B)"
mk(){ printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$W/QUEUE.tsv"; printf '# TASK %s\nGOAL: fixture\nDONE-WHEN: true\n## NEXT\nfixture\n## QA\n## LEDGER\n' "$2" > "$W/tasks/$2.task.md"; }
: > "$W/QUEUE.tsv"
mk 0 owned_by_other  hq_P       FREE
mk 1 owned_by_me     hq_B       FREE
mk 2 owned_by_nobody unassigned FREE
run_next(){ S4E_POST="$W" S4E_SEAT="$1" S4E_RELEASE_COOLDOWN=0 bash "$SUT" next 2>&1; }
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: next honours the owner column ==="
out="$(run_next hq_B)"
grep -q 'owned_by_other' <<<"$(grep -E '^(LOCKED|RUNNING|ASSIGNED)' <<<"$out")" && ck no "(a) hq_B was served hq_P's rank-0 row -- the owner column is being ignored" || ck ok "(a) hq_P's rank-0 row was NOT served to hq_B"
grep -qE '^(LOCKED|ASSIGNED->RUNNING).*owned_by_me' <<<"$out" && ck ok "(d) rank still wins among servable rows: hq_B got its own rank-1 row" || ck no "(d) hq_B should have been served owned_by_me (rank 1)"
grep -qi 'skipped .*owned by another seat' <<<"$out" && ck ok "(a) the skip is REPORTED, not silent" || ck no "(a) the skip must say it happened -- a silent skip reads as the row not existing"
grep -q 'owned_by_other' <<<"$out" && ck ok "(a) the report names the skipped row" || ck no "(a) the report must name the topmost skipped row"
rm -f "$W/claims/"*.claim
out="$(run_next hq_P)"
grep -qE '^(LOCKED|ASSIGNED->RUNNING).*owned_by_other' <<<"$out" && ck ok "(b) hq_P IS served its own rank-0 row" || ck no "(b) a row's own owner must still be served it"
rm -f "$W/claims/"*.claim
: > "$W/QUEUE.tsv"; mk 2 owned_by_nobody unassigned FREE
out="$(run_next hq_B)"
grep -qE '^(LOCKED|ASSIGNED->RUNNING).*owned_by_nobody' <<<"$out" && ck ok "(c) an unassigned FREE row is still served (the common case)" || ck no "(c) unassigned rows must still be served"
rm -f "$W/claims/"*.claim
: > "$W/QUEUE.tsv"; mk 0 owned_by_other hq_P FREE
S4E_POST="$W" S4E_SEAT=hq_B bash "$SUT" claim owned_by_other >/dev/null 2>&1
[ -f "$W/claims/owned_by_other.claim" ] && ck ok "(e) explicit claim still works -- the rule constrains the PICK, not the override" || ck no "(e) claim must remain the deliberate override"
rm -f "$W/claims/"*.claim
# ⛔ HQ DISPATCH LIVES IN THE CLAIM FILE -- first line the OWNING SEAT, then `ASSIGNED-BY <seat>`, and no
# RUNNING line yet -- NOT IN THE QUEUE STATE COLUMN -- PASS 1 scans
# claims/, and the column is only the index's echo of it. My first draft of this arm set the column to
# ASSIGNED:hq_B and nothing else, and it failed; the PRE-CURE picker failed it identically, which is what
# proved the arm wrong rather than the change. A control that only ever runs against the cured build cannot
# tell "I broke this" from "this never worked that way".
: > "$W/QUEUE.tsv"; mk 0 owned_by_other hq_P FREE; mk 3 dispatched_to_me unassigned ASSIGNED:hq_B
printf 'hq_B\nASSIGNED-BY ceo\n' > "$W/claims/dispatched_to_me.claim"
out="$(run_next hq_B)"
grep -q 'dispatched_to_me' <<<"$out" && ck ok "(f) HQ DISPATCH still works: an ASSIGNED:hq_B row is served even past a rank-0 row owned by another seat" || ck no "(f) an ASSIGNED:<me> row must still be served -- the owner rule must not break dispatch"
rm -f "$W/claims/"*.claim
# ⛔ (g) PASS 1's TIE-BREAK. Two ASSIGNED rows at the SAME rank whose ALPHABETICAL order inverts their MINT
# order: "aaa_older_row" was minted first, "zzz_newer_row" second. PASS 1 used to sort by rank alone, so the
# stable sort fell back to the claims/*.claim glob order -- alphabetical -- and served aaa. PASS 3 has broken
# ties by mint time (newest first) since its own fix; this asserts PASS 1 now does the same.
# ⭐ The fixture is built so the two orderings DISAGREE. A fixture where alphabetical and mint order happen to
# coincide would pass against either behaviour and prove nothing -- the whole content of this arm is the
# disagreement.
: > "$W/QUEUE.tsv"; mk 2 aaa_older_row unassigned ASSIGNED:hq_B; mk 2 zzz_newer_row unassigned ASSIGNED:hq_B
printf '# TASK aaa_older_row\nLINKS: minted via `mint` by ceo, 2026-09-01T10:00:00Z\nDONE-WHEN: true\n## NEXT\nfixture\n' > "$W/tasks/aaa_older_row.task.md"
printf '# TASK zzz_newer_row\nLINKS: minted via `mint` by ceo, 2026-09-03T10:00:00Z\nDONE-WHEN: true\n## NEXT\nfixture\n' > "$W/tasks/zzz_newer_row.task.md"
for t in aaa_older_row zzz_newer_row; do printf 'hq_B\nASSIGNED-BY ceo\n' > "$W/claims/$t.claim"; done
out="$(run_next hq_B)"
grep -q 'zzz_newer_row' <<<"$out" && ck ok "(g) PASS 1 tie-break is rank THEN mint time: the newer-minted row wins over the alphabetically-first one" || ck no "(g) PASS 1 served the alphabetically-first row -- the tie-break is still glob order, not mint time"
echo "------------------------------------------------------------"
[ "$fails" -ne 0 ] && { echo "⛔ GATE FAIL: $fails of $checks check(s) failed"; exit 1; }
echo "✅ GATE PASS: $checks/$checks checks"; exit 0

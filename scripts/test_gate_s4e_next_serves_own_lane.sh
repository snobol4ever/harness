#!/usr/bin/env bash
# test_gate_s4e_next_serves_own_lane.sh -- `next` MUST SERVE A SEAT ONLY ITS OWN HQ-LANE'S ROWS, FALLING
# THROUGH TO ANOTHER LANE ONLY WHEN ITS OWN LANE HAS NOTHING SERVABLE.
# Row next-serves-a-seat-only-rows-in-its-hqs-lane-and-no-row-carries-a-blank-owner-cell (seat14 found the
# class; ceo ruled it rank 0, 2026-09-03 20:57 CDT).
#
# THE MEASURED DEFECT: seat03 (Icon lane) held a snobol4-* row; seat05 (Prolog lane) held an icon-jcon-*
# row; seat06 (Prolog rungs lane) held a snobol4-gimpel-aisnobol-dotnet row; seat16 (Rebus lane) held an
# icon-strict-rung-suite row. THE ENABLING DEFECT: the picker read only the STATE column (FREE/CLAIMED/...)
# and the owner CELL when filled, never the topic's LANGUAGE, so a lane-blind rank sort served whichever
# seat asked `next` first.
#
# WHAT IT PROVES, against a THROWAWAY postoffice (S4E_POST) so the live queue is never read or written:
#   (a) OWN LANE WINS OVER RANK: a hq_B-lane seat is served its own lane's icon-* row even though a
#       snobol4-* (hq_P-lane) row sits at a LOWER rank -- proving the lane filter, not just presence.
#   (b) THE REASON IS PRINTED: the serve line names "OWN LANE" so a wandering seat (or a correctly-lane-
#       served one) is visible in its own printout, per GOAL's explicit requirement.
#   (c) CROSS-LANE FALLBACK STILL WORKS: when the seat's own lane has nothing servable at all, the
#       snobol4-* row IS served -- "your lane had nothing" is not silent starvation -- and is labelled
#       CROSS-LANE FALLBACK in the printout, not indistinguishable from an own-lane serve.
#   (d) AN EXPLICIT OWNER CELL BEATS THE LANE GUESS: a row whose owner cell already names the picking
#       identity is served even though its topic's language-derived lane would say otherwise.
#   (e) A LANE-UNDETERMINED TOPIC (no recognized language prefix, no owner cell) IS LANE-NEUTRAL: served
#       in the OWN-LANE pass itself, not deferred to fallback -- this is this row's own kind of topic.
#   (f) ceo IS NEVER LANE-RESTRICTED (GOAL's explicit carve-out, same identity-shape reasoning as the
#       MODE guard -- not s4e_is_hq(), which counts ceo as an HQ).
#   (g) AN HQ IDENTITY IS ALSO LANE-RESTRICTED, not just fleet seats (GOAL: "an HQ is restricted to its
#       own lane's rows").
#   (h) A SEAT'S LANE READS FROM ITS OWN POSTOFFICE HQ FILE, and a missing/stale one degrades to
#       LANE-BLIND (today's behaviour) rather than starving the seat entirely.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="${SUT:-$HERE/s4e_msg.sh}"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -f "$SUT" ] || refuse "picker under test not found: $SUT"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_lane.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/tasks" "$W/claims" "$W/released"
for s in ceo hq_C hq_B hq_P hq_T seat07 seat14 seat99_no_hq_file; do mkdir -p "$W/$s/inbox" "$W/$s/archive"; done
rm -f "$W/seat99_no_hq_file/HQ"     # mailbox exists, HQ file deliberately does not -- (h) tests this exact degradation
printf 'hq_B\n' > "$W/seat07/HQ"     # seat07's lane is hq_B for this fixture (icon)
printf 'hq_C\n' > "$W/seat14/HQ"     # seat14's lane is hq_C for this fixture (prolog)
printf 'FLEET-16\n' > "$W/MODE"
mk(){ printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$W/QUEUE.tsv"; printf '# TASK %s\nGOAL: fixture\nDONE-WHEN: true\n## NEXT\nfixture\n## QA\n## LEDGER\n' "$2" > "$W/tasks/$2.task.md"; }
run_next(){ S4E_POST="$W" S4E_SEAT="$1" S4E_RELEASE_COOLDOWN=0 bash "$SUT" next 2>&1; }
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
reset_q(){ : > "$W/QUEUE.tsv"; rm -f "$W/claims/"*.claim 2>/dev/null; }

echo "=== gate: next serves a seat only its own HQ lane, falling through when its lane is empty ==="

# (a)+(b) own-lane wins over rank; reason is printed
reset_q
mk 0 snobol4-lower-rank unassigned FREE
mk 1 icon-own-lane      unassigned FREE
out="$(run_next seat07)"
grep -qE '^LOCKED.*icon-own-lane' <<<"$out" && ck ok "(a) hq_B-lane seat07 served its OWN lane's rank-1 icon row over the rank-0 snobol4 row" \
  || ck no "(a) seat07 should have been served icon-own-lane (own lane), not the lower-rank snobol4 row -- got: $(grep -E '^LOCKED' <<<"$out")"
grep -qi 'own lane' <<<"$out" && ck ok "(b) the serve reason names OWN LANE" || ck no "(b) the serve must say it matched by lane, per GOAL's own printout requirement"

# (c) cross-lane fallback still works, and is labelled
reset_q
mk 0 snobol4-only-row unassigned FREE
out="$(run_next seat07)"
grep -qE '^LOCKED.*snobol4-only-row' <<<"$out" && ck ok "(c) seat07's lane (hq_B) is empty -- served the cross-lane snobol4 row instead of starving" \
  || ck no "(c) an empty own-lane must fall through to cross-lane work, not refuse to serve at all -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"
grep -qi 'cross-lane fallback' <<<"$out" && ck ok "(c) the fallback serve is labelled CROSS-LANE FALLBACK, not silently indistinguishable from an own-lane serve" \
  || ck no "(c) a cross-lane serve must say so in its own printout"

# (d) the OWNER CELL naming the picking identity DIRECTLY (pre-existing mechanism, untouched by this row
#     -- honoured by test_gate_s4e_next_honours_owner.sh already, re-checked here so the two gates cannot
#     silently disagree about it) must still win outright, reported as OWNER CELL not a lane match, even
#     though $ME never appears in s4e_topic_lane's own HQ-name check.
# ⭐ DELIBERATELY NOT TESTED: an owner cell naming a DIFFERENT HQ than the picker (e.g. "hq_B" read while
# picking as seat07, whose lane happens to also be hq_B) is left to the PRE-EXISTING skip -- unconditional,
# regardless of lane, exactly as ceo ruled it (s4e_msg.sh "fine when the owner is idle and wrong when they
# are working it, and the picker cannot tell the difference, so it must not guess"). s4e_topic_lane's own
# "owner cell wins" clause exists for callers OUTSIDE this skip-loop (a future mint/assign gate reading
# "what lane does this topic belong to" independent of who is asking); inside next's own dispatch it is
# consulted only AFTER the pre-existing owned-by-another-identity check already let the row through, i.e.
# for a blank/unassigned cell or one naming the picker itself -- loosening that skip to let same-lane
# identities through automatically would reopen the exact cross-identity race the original ruling closed,
# so this row does not touch it.
reset_q
mk 0 snobol4-tagged-to-me seat07 FREE
out="$(run_next seat07)"
grep -qE '^LOCKED.*snobol4-tagged-to-me' <<<"$out" && ck ok "(d) a row whose owner cell names seat07 directly is served to seat07 despite its snobol4 prefix" \
  || ck no "(d) an owner cell naming the picker directly must win outright"
grep -qi 'owner cell' <<<"$out" && ck ok "(d) the reason names the OWNER CELL match" || ck no "(d) a direct owner-cell match should be distinguishable in the printout from a lane match"

# (e) a lane-undetermined topic is lane-neutral -- served in the OWN-LANE pass, not deferred to fallback
reset_q
mk 0 postoffice-tooling-row unassigned FREE
out="$(run_next seat07)"
grep -qE '^LOCKED.*postoffice-tooling-row' <<<"$out" && ck ok "(e) a topic with no recognized language prefix is served without needing the fallback pass" \
  || ck no "(e) a lane-undetermined topic must be lane-neutral, not treated as belonging to some other lane"
grep -qi 'cross-lane fallback' <<<"$out" && ck no "(e) a lane-neutral topic must NOT be reported as a cross-lane fallback -- it never needed one" || ck ok "(e) not mislabelled as a fallback"

# (f) ceo is never lane-restricted
reset_q
mk 0 icon-row-for-ceo unassigned FREE
out="$(run_next ceo)"
grep -qE '^LOCKED.*icon-row-for-ceo' <<<"$out" && ck ok "(f) ceo is served the topmost row regardless of lane" || ck no "(f) ceo must never be lane-restricted"

# (g) an HQ identity is also lane-restricted, not just fleet seats
reset_q
mk 0 icon-row-low-rank  unassigned FREE
mk 1 prolog-row-own-lane unassigned FREE
out="$(run_next hq_C)"
grep -qE '^LOCKED.*prolog-row-own-lane' <<<"$out" && ck ok "(g) hq_C is served its OWN lane's prolog row over the lower-rank icon row" \
  || ck no "(g) an HQ identity must be lane-restricted too -- got: $(grep -E '^LOCKED' <<<"$out")"

# (h) a missing/stale seat HQ file degrades to lane-blind, not starved
reset_q
mk 0 icon-row-only unassigned FREE
out="$(S4E_POST="$W" S4E_SEAT=seat99_no_hq_file S4E_RELEASE_COOLDOWN=0 bash "$SUT" next 2>&1)"
grep -qE '^LOCKED.*icon-row-only' <<<"$out" && ck ok "(h) a seat with no readable HQ file is lane-blind (served today's way), not starved" \
  || ck no "(h) a missing HQ file must degrade to unrestricted dispatch, never refuse all work"

# ⭐ HALF 2 -- NO BLANK OWNER CELL. (i)+(j) mint; (k)+(l) assign. Same GOAL, same row, the other arm.
echo "=== gate: half 2 -- no blank owner cell ==="
run_mint(){ S4E_POST="$W" S4E_SEAT="$1" bash "$SUT" mint "${@:2}" 2>&1; }
# (i) a language-prefixed topic needs no --owner -- col3 is auto-derived, the common case must not regress
out="$(run_mint hq_C prolog-mint-fixture 2 "fixture goal")"
grep -qP '^2\tprolog-mint-fixture\thq_C\tFREE$' "$W/QUEUE.tsv" && ck ok "(i) mint auto-derives col3=hq_C for a prolog-* topic with no --owner flag" \
  || ck no "(i) a language-prefixed mint must not regress to a blank owner cell -- QUEUE.tsv row: $(grep prolog-mint-fixture "$W/QUEUE.tsv")"
# (j) a topic naming no language is REFUSED without an explicit --owner (this row's own kind of topic)
rc=0; out="$(run_mint hq_B generic-tooling-fixture 2 "fixture goal")" || rc=$?
{ [ "$rc" -ne 0 ] && ! grep -q "generic-tooling-fixture" "$W/QUEUE.tsv"; } && ck ok "(j1) mint REFUSES a lane-undeterminable topic with no --owner (rc=$rc, no row written)" \
  || ck no "(j1) an unclassifiable topic must be refused, not minted with a blank owner cell -- rc=$rc"
run_mint hq_B generic-tooling-fixture 2 --owner hq_B "fixture goal" >/dev/null 2>&1
grep -qP '^2\tgeneric-tooling-fixture\thq_B\tFREE$' "$W/QUEUE.tsv" && ck ok "(j2) --owner hq_B makes the same mint succeed, col3 set explicitly" \
  || ck no "(j2) an explicit --owner must be accepted and written -- QUEUE.tsv row: $(grep generic-tooling-fixture "$W/QUEUE.tsv")"
# (k) assign backfills a BLANK col3 to the assignee's own lane
reset_q
mk 0 topic-blank-owner-for-assign unassigned FREE
S4E_POST="$W" S4E_SEAT=ceo bash "$SUT" assign seat07 topic-blank-owner-for-assign >/dev/null 2>&1
grep -qP '^0\ttopic-blank-owner-for-assign\thq_B\t' "$W/QUEUE.tsv" && ck ok "(k) assign backfills a blank col3 with the assignee's own lane (seat07 -> hq_B)" \
  || ck no "(k) assign must backfill a blank owner cell, not leave the next wanderer's trap set -- QUEUE.tsv row: $(grep topic-blank-owner-for-assign "$W/QUEUE.tsv")"
# (l) assign NEVER overwrites an already-set col3, even one that differs from the assignee's own lane --
# col3 hq_B + a working hq_P-lane seat is a MEANINGFUL umbrella-HQ/working-seat pair, not drift to erase
# (see the "COLUMN 3 IS DELIBERATELY NOT TOUCHED" note at claim's own acquisition site).
reset_q
mk 0 topic-preowned-for-assign hq_P FREE
S4E_POST="$W" S4E_SEAT=ceo bash "$SUT" assign seat07 topic-preowned-for-assign >/dev/null 2>&1
grep -qP '^0\ttopic-preowned-for-assign\thq_P\t' "$W/QUEUE.tsv" && ck ok "(l) assign leaves an already-set col3 (hq_P) untouched even though the assignee's own lane is hq_B" \
  || ck no "(l) assign must never overwrite an existing owner cell -- QUEUE.tsv row: $(grep topic-preowned-for-assign "$W/QUEUE.tsv")"

# (m) A CROSS-LANE RESUME IS ANNOUNCED. ceo's witness, 2026-09-03 22:55 CDT: seat07 held
# raku-roast-100-percent-compile (lane hq_T) while its own lane's rank-0 SC4 snocone census sat FREE. The
# claim carried no ASSIGNED-BY, so no HQ dispatched it across lanes -- and (c)'s own control arm shows PASS 3
# would have skipped that row on its owner cell anyway. It was PASS 2, which resumes an unfinished claim with
# NO lane check at all. ⛔ THE CLAIM WAS IN-LANE WHEN IT WAS TAKEN: seat07's HQ file was rewritten hq_T -> hq_P
# ten minutes earlier, so the LANE MOVED UNDER A HELD CLAIM and nothing ever re-asked the question.
# ⛔ RESUMING IS STILL CORRECT -- an auto-release would strand in-flight work and a cross-lane hold is often
# deliberate. What must never happen again is doing it SILENTLY, indistinguishably from an in-lane serve.
reset_q
mk 0 icon-own-lane-waiting     hq_B FREE
mk 0 snobol4-held-cross-lane   hq_P CLAIMED:seat07
printf 'seat07\n' > "$W/claims/snobol4-held-cross-lane.claim"
out="$(run_next seat07)"
grep -qE '^RESUME .*snobol4-held-cross-lane' <<<"$out" && ck ok "(m1) an in-flight cross-lane claim is STILL RESUMED -- the notice must not strand held work" \
  || ck no "(m1) PASS 2 must keep resuming a held claim; only the silence was the defect -- got: $(grep -E '^RESUME|^LOCKED|QUEUE EMPTY' <<<"$out")"
grep -qi 'cross-lane hold' <<<"$out" && ck ok "(m2) the cross-lane resume SAYS SO -- a serve indistinguishable from an in-lane one is how this went unseen" \
  || ck no "(m2) resuming a row outside the seat's lane must be announced in its own printout"
grep -q 'icon-own-lane-waiting' <<<"$out" && ck ok "(m3) the notice names the own-lane row that was waiting (the ceo read this by hand off two claims)" \
  || ck no "(m3) the notice must name what is waiting in the seat's own lane, or it is a complaint with no next step"
# (m4) A NOTICE THAT CAN BLOCK IS A NOTICE THAT GETS WORKED AROUND -- the serve still succeeds.
rc=0; S4E_POST="$W" S4E_SEAT=seat07 S4E_RELEASE_COOLDOWN=0 bash "$SUT" next >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] && ck ok "(m4) the cross-lane notice does not change the exit status (rc=0) -- it informs, it never refuses" \
  || ck no "(m4) the notice must not turn a successful resume into a failure -- rc=$rc"
# (n) THE CONTROL ARM: the same held claim, in the seat's OWN lane, stays silent. Without this, a notice
# printed unconditionally would pass (m2) while telling every seat its own work is out of lane.
reset_q
mk 0 icon-held-in-lane hq_B CLAIMED:seat07
printf 'seat07\n' > "$W/claims/icon-held-in-lane.claim"
out="$(run_next seat07)"
{ grep -qE '^RESUME .*icon-held-in-lane' <<<"$out" && ! grep -qi 'cross-lane hold' <<<"$out"; } \
  && ck ok "(n) an IN-LANE resume prints no cross-lane notice -- the warning is about the mismatch, not about resuming" \
  || ck no "(n) resuming a row in the seat's own lane must stay silent -- got: $(grep -iE '^RESUME|cross-lane' <<<"$out")"
# (o) A SEAT WITH NO READABLE HQ FILE DEGRADES TO SILENT, same as (h): an undetermined lane is UNDETERMINED,
# never a fifth lane to be warned about. A missing HQ file must not scream on every resume.
reset_q
mk 0 snobol4-held-by-lane-blind hq_P CLAIMED:seat99_no_hq_file
printf 'seat99_no_hq_file\n' > "$W/claims/snobol4-held-by-lane-blind.claim"
out="$(run_next seat99_no_hq_file)"
{ grep -qE '^RESUME .*snobol4-held-by-lane-blind' <<<"$out" && ! grep -qi 'cross-lane hold' <<<"$out"; } \
  && ck ok "(o) a seat whose lane is undeterminable resumes silently -- a stale HQ file degrades, it does not nag" \
  || ck no "(o) an undetermined lane must not produce a cross-lane notice -- got: $(grep -iE '^RESUME|cross-lane' <<<"$out")"

echo "------------------------------------------------------------"
[ "$fails" -ne 0 ] && { echo "⛔ GATE FAIL: $fails of $checks check(s) failed"; exit 1; }
echo "✅ GATE PASS: $checks/$checks checks"; exit 0

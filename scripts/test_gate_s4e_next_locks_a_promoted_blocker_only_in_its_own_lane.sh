#!/usr/bin/env bash
# test_gate_s4e_next_locks_a_promoted_blocker_only_in_its_own_lane.sh — `next`'s DEPENDENCY INVERSION REPORTS ANOTHER
# SEAT'S BLOCKER AND LOCKS NOTHING; THE BLOCKER'S OWNER IS RUNG ONCE; THE OWNER'S OWN `next` STILL TAKES IT
# (row instruments-next-dependency-inversion-serves-an-officer-another-lane-s-row-three-times-in-one-sitting-the-promoted-
# blocker-must-be-in-the-picker-s-own-lane; ceo 2026-09-26 18:5x CDT; CEO-1232: the officers run no board and hold no HQ's row).
#
# MEASURED BY THE CEO, ONE SITTING UNDER TENET: `next` LOCKED the cto's gc-the-key-collision-plant-... for the ceo (a),
# and LOCKED hq_raku's raku-roast-100-percent-compile for the ceo while its line named a different row (b): the walk is
# transitive (bench-rivals-raku-pascal -> raku-frontend-real-world-syntax-gaps -> raku-roast-100-percent-compile) and the
# line printed only the first hop, as "un-DONE, unclaimed and FREE" -- which that hop was not.
# ROOT CAUSE (coo, same evening): the promotion never read the blocker's OWNER CELL, which the ordinary pick has honoured
# since 2026-09-03; the one check standing in for it (CEO-779) bites only a seat owning no language, and TENET gives the
# ceo rebus. Found beside it: the ordinary pick's "owned by your HQ" arm read s4e_hq, and every HQ file names an officer
# under the consolidated modes, so `next` locked ceo rows for the coo and hq_icon and cto rows for hq_raku.
#
# THE FIXTURE is TENET's shape, pinned so a MODE flip cannot move it: rebus=ceo (an officer owning a language -- the case
# that switched CEO-779 off), raku=hq_raku, icon=hq_icon; every HQ file names an officer as the live postoffice's do.
# ARMS (hermetic, its own scratch postoffice under mktemp; the live postoffice is never read or written):
#   (a)  ceo: its row BLOCKED-ON the cto's FREE row -- nothing locked                                        RED on the old picker
#   (a2) the refusal names the blocked row, the blocker and whose row it is                                   RED
#   (a3) the cto is rung exactly once, and the doorbell names both rows                                       RED
#   (a4) a second `next` by the ceo inside the cooldown locks nothing and rings nothing more                  RED
#   (b)  ceo: its row BLOCKED-ON an hq_raku row BLOCKED-ON an hq_raku FREE row -- nothing locked, chain named RED
#   (c)  PASS ARM: the cto's own `next` on (a)'s queue LOCKS its row by dependency inversion
#   (d)  PASS ARM: hq_raku's own `next` on (b)'s queue LOCKS the leaf and its line names the whole chain       RED (first hop only)
#   (e)  hq_icon: its row BLOCKED-ON a ceo-owned FREE row -- nothing locked, the ceo rung once                RED
#   (f)  ordinary pick: coo and hq_icon are not served a ceo-owned FREE row, hq_raku not a cto-owned one      RED
#   (f2) the owned-row skip counts one skipped row once, not once per pass                                   RED ("skipped 2")
#   (g)  hq_icon walking past the ceo's blocked row takes its own row and rings nobody
#   (h)  CONTROL: an HQ's blocker in its own lane is still promoted and locked
#   (i)  CONTROL: an unowned lane-neutral blocker is still promoted for the ceo -- the cut is the owner cell, not a blanket
#   (j)  CONTROL: a numbered seat still takes a row owned by the HQ its lane resolves to (hq_B's 2026-09-04 cure); built only
#        under a MODE that dispatches a numbered seat, else UNBUILDABLE and never counted green
# rc 0 = every graded arm holds; rc 1 = a FAIL named; rc 2 = REFUSED-TO-GRADE (the fixture could not be built).
# SUT=<path> grades another copy of s4e_msg.sh (its lib_*.sh must sit beside it) -- how the RED column above was read.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="${SUT:-$HERE/s4e_msg.sh}"
refuse(){ echo "⛔ REFUSED-TO-GRADE [s4e_next_locks_a_promoted_blocker_only_in_its_own_lane]: $*"; exit 2; }
[ -f "$SUT" ] || refuse "picker under test not found: $SUT"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_promo_own_lane.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/tasks" "$W/claims" "$W/released"
. "$HERE/lib_gate.sh"
command -v gate_stage_picker_lane_table >/dev/null 2>&1 || refuse "lib_gate.sh carries no gate_stage_picker_lane_table -- the staging rule is a sourced authority, never a private copy"
command -v gate_pick_dispatchable_mode >/dev/null 2>&1 || refuse "lib_gate.sh carries no gate_pick_dispatchable_mode"
gate_stage_picker_lane_table "$SUT" "$W/picker_fixture.sh" hq_snobol4 rebus=ceo raku=hq_raku icon=hq_icon
case $? in
  0) : ;;
  3) refuse "could not find s4e_lane_owner_of_language() in $SUT to stage the fixture's table" ;;
  4) refuse "the staged picker does not read back its pinned table (rebus=ceo raku=hq_raku icon=hq_icon)" ;;
  5) refuse "could not stage the lib_*.sh files beside the fixture picker" ;;
  *) refuse "staging the fixture picker from $SUT failed" ;;
esac
P="$W/picker_fixture.sh"
SEATS="ceo coo cto cfo hq_icon hq_raku hq_snobol4 seat07"
for s in $SEATS; do mkdir -p "$W/$s/inbox" "$W/$s/archive"; done
for s in coo cto cfo hq_icon hq_snobol4; do printf 'ceo\n' > "$W/$s/HQ"; done
printf 'cto\n' > "$W/hq_raku/HQ"; printf 'hq_icon\n' > "$W/seat07/HQ"
MODE_ALL="$(gate_pick_dispatchable_mode "$P" "$W" ceo,coo,cto,hq_icon,hq_raku TENET DECTET NONET)" \
  || refuse "no candidate MODE (TENET DECTET NONET) dispatches all of ceo, coo, cto, hq_icon and hq_raku"
echo "    fixture: MODE $MODE_ALL; lanes rebus=ceo raku=hq_raku icon=hq_icon; HQ files name officers (hq_raku -> cto, the rest -> ceo)"
mk(){ printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$W/QUEUE.tsv"
      printf '# TASK %s\nGOAL: fixture\nDONE-WHEN: grep -q fixture-row-is-never-done /dev/null\n## NEXT\nfixture\n## QA\n## LEDGER\n' "$2" > "$W/tasks/$2.task.md"; }
run_next(){ S4E_POST="$W" S4E_SEAT="$1" S4E_RELEASE_COOLDOWN=0 bash "$P" next 2>&1; }
reset_q(){ : > "$W/QUEUE.tsv"; rm -f "$W/claims/"*.claim "$W/released/"* 2>/dev/null; rm -rf "$W/blocker-doorbells"
           for s in $SEATS; do rm -f "$W/$s/inbox/"*.msg 2>/dev/null; done; }
claims(){ (cd "$W/claims" && ls 2>/dev/null | sed 's/\.claim$//' | tr '\n' ' '); }
bells(){ ls "$W/$1/inbox" 2>/dev/null | grep -c -- '-your-row-blocks-rank-'; }
bell_text(){ cat "$W/$1/inbox/"*-your-row-blocks-rank-*.msg 2>/dev/null; }
fails=0; checks=0; unbuilt=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: next locks a promoted blocker only in its own lane; the blocker's owner is rung ==="

# (a)..(a4), (c): the ceo's case (a)
reset_q
mk 0 gc-officer-blocked-row ceo BLOCKED-ON:gc-cto-blocker-row
mk 2 gc-cto-blocker-row cto FREE
out="$(run_next ceo)"
[ -z "$(claims)" ] && ! grep -q '^LOCKED' <<<"$out" \
  && ck ok "(a) ceo: its row BLOCKED-ON the cto's FREE row -- nothing is locked" \
  || ck no "(a) ceo must lock nothing -- claims: [$(claims)] got: $(grep -E '^LOCKED|DEPENDENCY' <<<"$out" | head -2)"
grep 'REFUSED PROMOTION' <<<"$out" | grep 'gc-officer-blocked-row' | grep 'gc-cto-blocker-row' | grep -q "cto's row" \
  && ck ok "(a2) the refusal names the blocked row, the blocker and whose row it is" \
  || ck no "(a2) the refusal must name gc-officer-blocked-row, gc-cto-blocker-row and cto's row -- got: $(grep -E 'REFUSED|LOCKED' <<<"$out" | head -2)"
[ "$(bells cto)" = 1 ] && bell_text cto | grep -q 'gc-officer-blocked-row' && bell_text cto | grep -q 'gc-cto-blocker-row' \
  && ck ok "(a3) the cto is rung exactly once, and the doorbell names both rows" \
  || ck no "(a3) the cto must hold exactly one doorbell naming both rows -- holds $(bells cto)"
out="$(run_next ceo)"
[ -z "$(claims)" ] && [ "$(bells cto)" = 1 ] \
  && ck ok "(a4) a second next by the ceo inside the cooldown locks nothing and rings nothing more" \
  || ck no "(a4) second next: claims [$(claims)], cto doorbells $(bells cto) (want none and 1)"
out="$(run_next cto)"
[ "$(claims)" = "gc-cto-blocker-row " ] && grep -q '^LOCKED gc-cto-blocker-row' <<<"$out" && grep -q 'DEPENDENCY INVERSION' <<<"$out" \
  && ck ok "(c) PASS ARM: the cto's own next LOCKS its row by dependency inversion" \
  || ck no "(c) PASS ARM: the cto must be served gc-cto-blocker-row -- claims [$(claims)] got: $(grep -E '^LOCKED|REFUSED|EMPTY' <<<"$out" | head -2)"

# (b), (d): the ceo's case (b), a transitive chain
reset_q
mk 1 bench-officer-blocked-row ceo BLOCKED-ON:raku-middle-row
mk 1 raku-middle-row hq_raku BLOCKED-ON:raku-leaf-row
mk 1 raku-leaf-row hq_raku FREE
out="$(run_next ceo)"
[ -z "$(claims)" ] && grep 'REFUSED PROMOTION' <<<"$out" | grep 'bench-officer-blocked-row' | grep -q 'raku-middle-row -> raku-leaf-row' \
  && ck ok "(b) ceo: a two-hop chain into hq_raku's rows locks nothing, and the refusal names the whole chain" \
  || ck no "(b) ceo must lock nothing and name raku-middle-row -> raku-leaf-row -- claims [$(claims)] got: $(grep -E '^LOCKED|DEPENDENCY|REFUSED' <<<"$out" | head -2)"
out="$(run_next hq_raku)"
[ "$(claims)" = "raku-leaf-row " ] && grep 'DEPENDENCY INVERSION' <<<"$out" | grep -q 'raku-middle-row -> raku-leaf-row' \
  && ck ok "(d) PASS ARM: hq_raku's own next LOCKS the leaf, and its line names the whole chain" \
  || ck no "(d) PASS ARM: hq_raku must lock raku-leaf-row under a line naming raku-middle-row -> raku-leaf-row -- claims [$(claims)] got: $(grep -E 'DEPENDENCY|^LOCKED' <<<"$out" | head -2)"

# (e): an HQ's own row blocked on an officer's row
reset_q
mk 0 icon-hq-blocked-row hq_icon BLOCKED-ON:fleet-ceo-blocker-row
mk 2 fleet-ceo-blocker-row ceo FREE
out="$(run_next hq_icon)"
[ -z "$(claims)" ] && [ "$(bells ceo)" = 1 ] && grep 'REFUSED PROMOTION' <<<"$out" | grep -q "ceo's row" \
  && ck ok "(e) hq_icon: its row BLOCKED-ON a ceo-owned FREE row locks nothing, and the ceo is rung once" \
  || ck no "(e) hq_icon must lock nothing and ring the ceo once -- claims [$(claims)], ceo doorbells $(bells ceo), got: $(grep -E '^LOCKED|REFUSED' <<<"$out" | head -2)"

# (f), (f2): the ordinary pick and the HQ file
# each seat on a fresh queue: a claim also writes CLAIMED:<seat> into the state column, which would hide the row from the next seat
reset_q; mk 1 fleet-ceo-owned-row ceo FREE
out="$(run_next coo)"; c_coo="$(claims)"
reset_q; mk 1 fleet-ceo-owned-row ceo FREE
out="$(run_next hq_icon)"; c_icon="$(claims)"
reset_q; mk 1 gc-cto-owned-row cto FREE
out="$(run_next hq_raku)"; c_raku="$(claims)"
[ -z "$c_coo$c_icon$c_raku" ] \
  && ck ok "(f) ordinary pick: coo and hq_icon are not served a ceo-owned row, nor hq_raku a cto-owned one (an HQ file names where asks go, not a lane)" \
  || ck no "(f) ordinary pick served another seat's row -- coo [$c_coo] hq_icon [$c_icon] hq_raku [$c_raku]"
# (f2) its own row, owned by an HQ no HQ file names, so the old picker skips it too and the count is what is graded
reset_q; mk 1 snobol4-hq-owned-row hq_snobol4 FREE
out="$(run_next coo)"
[ -z "$(claims)" ] && grep -q 'skipped 1 free row(s) owned by another seat' <<<"$out" \
  && ck ok "(f2) the owned-row skip counts one row once, not once per pass" \
  || ck no "(f2) one hq_snobol4-owned row, skipped by the coo, must read skipped 1 -- claims [$(claims)] got: $(grep 'skipped' <<<"$out" | head -1)"

# (g): a seat walking past someone else's blocked row
reset_q
mk 0 gc-officer-blocked-row ceo BLOCKED-ON:gc-cto-blocker-row
mk 2 gc-cto-blocker-row cto FREE
mk 3 icon-own-row hq_icon FREE
out="$(run_next hq_icon)"
[ "$(claims)" = "icon-own-row " ] && [ "$(bells cto)" = 0 ] \
  && ck ok "(g) hq_icon walking past the ceo's blocked row takes its own row and rings nobody" \
  || ck no "(g) hq_icon must lock icon-own-row only and ring nobody -- claims [$(claims)], cto doorbells $(bells cto)"

# (h), (i): controls
reset_q
mk 0 icon-blocked-row hq_icon BLOCKED-ON:icon-blocker-row
mk 2 icon-blocker-row hq_icon FREE
out="$(run_next hq_icon)"
[ "$(claims)" = "icon-blocker-row " ] && grep -q 'DEPENDENCY INVERSION' <<<"$out" \
  && ck ok "(h) CONTROL: an HQ's blocker in its own lane is still promoted and locked" \
  || ck no "(h) CONTROL broken: hq_icon must be served icon-blocker-row by dependency inversion -- claims [$(claims)]"
reset_q
mk 0 gc-officer-blocked-row ceo BLOCKED-ON:fleet-unowned-blocker
mk 2 fleet-unowned-blocker unassigned FREE
out="$(run_next ceo)"
[ "$(claims)" = "fleet-unowned-blocker " ] && grep -q 'DEPENDENCY INVERSION' <<<"$out" \
  && ck ok "(i) CONTROL: an unowned lane-neutral blocker is still promoted for the ceo" \
  || ck no "(i) CONTROL broken: the ceo must be served fleet-unowned-blocker -- claims [$(claims)]"

# (j): control for the numbered-seat relaxation, under a MODE that dispatches one
if M_SEAT="$(gate_pick_dispatchable_mode "$P" "$W" seat07 FLEET-16 FLEET-12 FLEET-8)"; then
  reset_q
  mk 1 icon-row-owned-by-my-hq hq_icon FREE
  out="$(run_next seat07)"
  [ "$(claims)" = "icon-row-owned-by-my-hq " ] && grep -q 'owned by your HQ' <<<"$out" \
    && ck ok "(j) CONTROL ($M_SEAT): a numbered seat still takes a row owned by the HQ its lane resolves to" \
    || ck no "(j) CONTROL broken ($M_SEAT): seat07 must be served icon-row-owned-by-my-hq -- claims [$(claims)] got: $(grep -E '^LOCKED|EMPTY|skipped' <<<"$out" | head -2)"
  printf '%s\n' "$MODE_ALL" > "$W/MODE"
else unbuilt=$((unbuilt+1)); printf '  ----  (j) [UNBUILDABLE: no candidate MODE dispatches a numbered seat]\n'; fi

echo "population: $checks arm(s) graded, $fails FAIL, $unbuilt unbuildable"
if [ "$fails" -gt 0 ]; then echo "⛔ GATE RED [s4e_next_locks_a_promoted_blocker_only_in_its_own_lane]: $fails of $checks arm(s) FAIL"; exit 1; fi
_note=""; [ "$unbuilt" -gt 0 ] && _note=" ($unbuilt unbuildable, named above, never counted green)"
echo "GATE PASS [s4e_next_locks_a_promoted_blocker_only_in_its_own_lane]: $checks of $checks arm(s) hold$_note"

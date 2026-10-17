#!/usr/bin/env bash
# test_gate_s4e_next_any_lane_fallback_closes_under_tenet.sh -- UNDER TENET `next` NEVER SERVES A LANGUAGE HQ ANOTHER LANE'S ROW, ON THE
# ORDINARY PATH OR BY PROMOTION (ceo CEO-1302 (b), 2026-09-27; coo COO-205).
# The ruling, verbatim: "THE ANY-LANE FALLBACK CLOSES UNDER TENET for every seat, ordinary and promotion paths alike (an HQ runs only its
# own language, CEO-1232, and holds one row); census: all 21 rows owned `unassigned` are DONE, SUPERSEDED or RETIRED -- zero live -- so
# the close strands nothing." Before it, s4e_msg.sh's any-lane pass handed an HQ whose own lane had nothing servable a cross-lane row
# labelled CROSS-LANE FALLBACK, and the dependency-inversion promotion retried a cross-lane blocker in that pass; only a seat owning no
# language was refused (CEO-779).
# THE FIXTURE: a staged picker with its lane table pinned (icon=hq_icon snobol4=hq_snobol4), MODE written per arm.
#   (a)  TENET, hq_icon, the queue holds only a FREE snobol4 row: nothing locked, rc 2, the refusal names the close           RED before
#   (b)  TENET, hq_icon, an icon row beside it: the icon row is served (the close takes nothing from an HQ's own lane)
#   (c)  CONTROL -- the same queue as (a) under a mode that keeps the fallback (DECTET/NONET, whichever dispatches hq_icon): the
#        snobol4 row IS served as CROSS-LANE FALLBACK, so (a) reads the MODE and not a picker that lost its fallback altogether
#   (d)  TENET, hq_icon's own row BLOCKED-ON a FREE snobol4 row: nothing locked, rc 2 (the promotion path)                      RED before
# rc 0 = every graded arm holds; rc 1 = a FAIL named; rc 2 = REFUSED-TO-GRADE (the fixture could not be built).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="${SUT:-$HERE/s4e_msg.sh}"
G=s4e_next_any_lane_fallback_closes_under_tenet
refuse(){ echo "⛔ REFUSED-TO-GRADE [$G]: $*"; exit 2; }
[ -f "$SUT" ] || refuse "picker under test not found: $SUT"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_anylane.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/tasks" "$W/claims" "$W/released"
. "$HERE/lib_gate.sh"
command -v gate_stage_picker_lane_table >/dev/null 2>&1 || refuse "lib_gate.sh carries no gate_stage_picker_lane_table"
command -v gate_pick_dispatchable_mode >/dev/null 2>&1 || refuse "lib_gate.sh carries no gate_pick_dispatchable_mode"
gate_stage_picker_lane_table "$SUT" "$W/picker_fixture.sh" hq_snobol4 icon=hq_icon snobol4=hq_snobol4 || refuse "staging the fixture picker from $SUT failed (rc $?)"
P="$W/picker_fixture.sh"
SEATS="ceo coo hq_icon hq_snobol4"
for s in $SEATS; do mkdir -p "$W/$s/inbox" "$W/$s/archive"; done
for s in coo hq_icon hq_snobol4; do printf 'ceo\n' > "$W/$s/HQ"; done
M_OPEN="$(gate_pick_dispatchable_mode "$P" "$W" hq_icon DECTET NONET)" || refuse "no control MODE (DECTET NONET) dispatches hq_icon"
printf 'TENET\n' > "$W/MODE"
mk(){ printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$W/QUEUE.tsv"
      printf '# TASK %s\nGOAL: fixture\nDONE-WHEN: grep -q fixture-row-is-never-done /dev/null\n## NEXT\nfixture\n## QA\n## LEDGER\n' "$2" > "$W/tasks/$2.task.md"; }
run_next(){ S4E_POST="$W" S4E_SEAT="$1" S4E_RELEASE_COOLDOWN=0 bash "$P" next 2>&1; }
reset_q(){ : > "$W/QUEUE.tsv"; rm -f "$W/claims/"*.claim "$W/released/"* 2>/dev/null; rm -rf "$W/blocker-doorbells"
           for s in $SEATS; do rm -f "$W/$s/inbox/"*.msg 2>/dev/null; done; }
claims(){ (cd "$W/claims" && ls 2>/dev/null | sed 's/\.claim$//' | tr '\n' ' '); }
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: under TENET next never serves a language HQ another lane's row (CEO-1302 (b)); control MODE $M_OPEN keeps the fallback ==="

reset_q; printf 'TENET\n' > "$W/MODE"
mk 0 snobol4-other-lane-row unassigned FREE
out="$(run_next hq_icon)"; rc=$?
{ [ -z "$(claims)" ] && [ "$rc" = 2 ] && grep -q 'CLOSED under TENET' <<<"$out"; } \
  && ck ok "(a) TENET: hq_icon's lane is empty -- nothing locked, rc 2, and the refusal names the closed fallback" \
  || ck no "(a) TENET: hq_icon must lock nothing and refuse rc 2 naming the close -- rc=$rc claims [$(claims)] got: $(grep -E '^LOCKED|REFUSED|EMPTY' <<<"$out" | head -2)"

reset_q; printf 'TENET\n' > "$W/MODE"
mk 0 snobol4-other-lane-row unassigned FREE
mk 1 icon-own-lane-row unassigned FREE
out="$(run_next hq_icon)"; rc=$?
{ [ "$(claims)" = "icon-own-lane-row " ] && [ "$rc" = 0 ]; } \
  && ck ok "(b) TENET: hq_icon is served its own icon row past the rank-0 snobol4 one" \
  || ck no "(b) TENET: hq_icon must lock icon-own-lane-row -- rc=$rc claims [$(claims)] got: $(grep -E '^LOCKED|REFUSED|EMPTY' <<<"$out" | head -2)"

reset_q; printf '%s\n' "$M_OPEN" > "$W/MODE"
mk 0 snobol4-other-lane-row unassigned FREE
out="$(run_next hq_icon)"; rc=$?
{ [ "$(claims)" = "snobol4-other-lane-row " ] && grep -qi 'cross-lane fallback' <<<"$out"; } \
  && ck ok "(c) CONTROL under $M_OPEN: the same queue serves the snobol4 row as CROSS-LANE FALLBACK -- (a) reads the MODE" \
  || ck no "(c) CONTROL under $M_OPEN: hq_icon should have been served the snobol4 row by fallback -- rc=$rc claims [$(claims)] got: $(grep -E '^LOCKED|REFUSED|EMPTY' <<<"$out" | head -2)"

reset_q; printf 'TENET\n' > "$W/MODE"
mk 0 icon-blocked-own-row hq_icon BLOCKED-ON:snobol4-blocker-row
mk 2 snobol4-blocker-row unassigned FREE
out="$(run_next hq_icon)"; rc=$?
{ [ -z "$(claims)" ] && [ "$rc" = 2 ]; } \
  && ck ok "(d) TENET: hq_icon's row BLOCKED-ON a FREE snobol4 row -- the promotion locks nothing, rc 2" \
  || ck no "(d) TENET: the promotion must lock nothing and refuse rc 2 -- rc=$rc claims [$(claims)] got: $(grep -E '^LOCKED|DEPENDENCY|REFUSED|EMPTY' <<<"$out" | head -2)"

echo "population: $checks arm(s) over one staged picker (icon=hq_icon snobol4=hq_snobol4), MODE TENET and the control $M_OPEN"
if [ "$fails" -gt 0 ]; then echo "⛔ GATE RED [$G]: $fails of $checks arm(s) FAIL"; exit 1; fi
echo "GATE PASS [$G]: $checks of $checks arm(s) hold"

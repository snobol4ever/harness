#!/usr/bin/env bash
# test_gate_s4e_next_any_lane_fallback_refuses_a_seat_with_no_language.sh — THE PICKER'S ANY-LANE FALLBACK REFUSES A
# SEAT THAT OWNS NO LANGUAGE (row picker-dependency-inversion-serves-a-blocker-across-lanes-to-a-seat-that-cures-nothing;
# ceo CEO-771/CEO-779; Lon 2026-09-16 11:22 CDT, verbatim to the ceo: "Get the COO helping. The language seats now run
# their own tests and benchmarks."; CEO-781).
#
# MEASURED 2026-09-16 11:00 CDT on the live postoffice: `next` run by the coo -- whose own-lane pass found nothing --
# fell to the any-lane pass and, by DEPENDENCY INVERSION, CLAIMED the cfo's rank-0 blocker
# icon-gc-rung-2-every-live-aggregate-slides-and-hb-pinned-is-deleted to coo (claims/…claim read "coo / RUNNING");
# CEO-771 measured the same path locking a Raku cure row for the ceo. The picker's own comment said a seat with no lane
# "wanders rather than starves" -- true under EXECUTIVE, a defect under DECTET where the coo, ceo and cto cure nothing
# in a language lane (CEO-723, CEO-766, CEO-775).
#
# THE CURE UNDER TEST (s4e_msg.sh): s4e_seat_owns_a_language; s4e_promotion_admissible refuses a promoted blocker in
# ANOTHER owner's lane to a seat that owns no language in EVERY pass; the ordinary any-lane CROSS-LANE FALLBACK skips
# such rows for such a seat; and when that is all that held the seat back, `next` exits 2 (REFUSED), never "QUEUE EMPTY".
#
# ARMS (hermetic, its own scratch postoffice under mktemp; MODE DECTET; lanes read from the picker's own table):
#   (a) coo: the blocked HQ row's FREE blocker (an HQ's) is NOT claimed, the refusal is printed naming both topics, rc=2
#   (b) ceo (no lane at all): the same blocker is NOT claimed
#   (c) CONTROL — the owning HQ: the blocker IS served (LOCKED, claim written) by dependency inversion
#   (d) CONTROL — a language-owning officer (the rebus owner) with its own FREE row: served its own row, never the blocker
#   (e) coo with an instrument row of its own (owner cell coo): served it, rc=0 -- a lane-less seat is not starved of ITS rows
#   (f) coo, ordinary path: a FREE HQ row with no dependency is NOT served on the fallback, rc=2
# rc 0 = every arm holds; rc 1 = a FAIL named; rc 2 = REFUSED-TO-GRADE (fixture could not be built).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="${SUT:-$HERE/s4e_msg.sh}"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -f "$SUT" ] || refuse "picker under test not found: $SUT"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_nolane_fallback.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/tasks" "$W/claims" "$W/released"
# ⛔⭐ THE FIXTURE BRINGS ITS OWN TABLE, BECAUSE ITS SUBJECT IS THE owns-a-language TEST AND NOT THE LIVE
# LANE CUT (COO-80, 2026-09-19, row instrument-the-nineteen-non-gc-blocking-arms; the shape ceo CEO-953
# directed for its sister gate). This gate needs a table carrying BOTH an hq_* lane and an officer lane, so
# that the seats it puts under test -- coo and ceo -- own nothing while a real lane exists beside them to
# prove the refusal is about THEM and not about an empty table. Every mode that gives all seven languages to
# one seat (CEO, TRIO, QUARTET today) leaves no hq_* owner at all, and this gate then REFUSED rc=2 and took
# make test-postoffice down with it -- one of the twenty-three blocking arms of CEO-944. It was right to
# refuse rather than lower its bar; what it lacked was the one piece of scenario it could not write itself.
# The staging rule is a SOURCED AUTHORITY in lib_gate.sh, shared with the sister gate, never a private copy;
# the mechanism under test is the real one in the staged file, and whether the LIVE table is correct is a
# different gate's subject.
_PINNED_HQ_LANG=icon; _PINNED_HQ_OWNER=hq_icon; _PINNED_OFF_LANG=rebus; _PINNED_OFF_OWNER=cfo
. "$HERE/lib_gate.sh"
command -v gate_stage_picker_lane_table >/dev/null 2>&1 || refuse "lib_gate.sh carries no gate_stage_picker_lane_table -- the staging rule is a sourced authority and a gate must never keep a private copy of it"
gate_stage_picker_lane_table "$SUT" "$W/picker_fixture.sh" "$_PINNED_HQ_OWNER" \
    "$_PINNED_HQ_LANG=$_PINNED_HQ_OWNER" "$_PINNED_OFF_LANG=$_PINNED_OFF_OWNER"
case $? in
  0) : ;;
  3) refuse "could not find s4e_lane_owner_of_language() in $SUT to stage the fixture's table -- the picker's table has moved or been renamed, and a lane fixture that cannot install its own table must not grade the live one" ;;
  4) refuse "the staged picker does not read back its pinned table -- the rewrite landed but did not take, and grading would silently be against the live table" ;;
  *) refuse "staging the fixture picker from $SUT failed" ;;
esac
SUT="$W/picker_fixture.sh"
_lane_owner_of(){ bash -c '. /dev/stdin <<<"$(sed -n "/^s4e_lane_languages()/,/^s4e_lane_help()/p" "$1")"; s4e_lane_owner_of_language "$2"' _ "$SUT" "$1" 2>/dev/null; }
_lane_langs="$(bash -c '. /dev/stdin <<<"$(sed -n "/^s4e_lane_languages()/,/^s4e_lane_help()/p" "$1")"; s4e_lane_languages' _ "$SUT" 2>/dev/null)"
[ -n "$_lane_langs" ] || refuse "cannot read the language list out of $SUT"
# an HQ-owned language (hq_*) and an officer-owned one (rebus=cfo today), both read from the table, never assumed
_hq_lang=""; _hq_owner=""; _off_lang=""; _off_owner=""
for _l in $_lane_langs; do
  _o="$(_lane_owner_of "$_l")"
  case "$_o" in hq_*) [ -z "$_hq_lang" ] && { _hq_lang="$_l"; _hq_owner="$_o"; };;
                cfo|cto) [ -z "$_off_lang" ] && { _off_lang="$_l"; _off_owner="$_o"; };; esac
done
[ -n "$_hq_lang" ] || refuse "no language in the picker's table is owned by an hq_* seat; the HQ control arm cannot be built"
for s in ceo coo cto cfo $_hq_owner ${_off_owner:-cfo}; do mkdir -p "$W/$s/inbox" "$W/$s/archive"; done
printf 'DECTET\n# fixture line 2\nLANES: fixture\n' > "$W/MODE"
echo "    fixture: HQ lane = $_hq_owner (owns $_hq_lang); officer lane = ${_off_owner:-none} (owns ${_off_lang:-nothing}); lane-less seats under test = coo, ceo"
mk(){ printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$W/QUEUE.tsv"; printf '# TASK %s\nGOAL: fixture\nDONE-WHEN: true\n## NEXT\nfixture\n## QA\n## LEDGER\n' "$2" > "$W/tasks/$2.task.md"; }
run_next(){ S4E_POST="$W" S4E_SEAT="$1" S4E_RELEASE_COOLDOWN=0 bash "$SUT" next 2>&1; }
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
reset_q(){ : > "$W/QUEUE.tsv"; rm -f "$W/claims/"*.claim "$W/released/"* 2>/dev/null; }
echo "=== gate: next's any-lane fallback refuses a seat that owns no language (CEO-779) ==="
# (a) coo vs a blocked HQ row whose blocker is FREE in the HQ's lane
reset_q
mk 0 ${_hq_lang}-blocked-row "$_hq_owner" BLOCKED-ON:${_hq_lang}-blocker-row
mk 0 ${_hq_lang}-blocker-row "$_hq_owner" FREE
out="$(run_next coo)"; rc=$?
if [ ! -f "$W/claims/${_hq_lang}-blocker-row.claim" ] && [ "$rc" = 2 ]; then ck ok "(a) coo is NOT served the HQ's blocker by dependency inversion, and next exits 2 (REFUSED)"
else ck no "(a) coo must not claim ${_hq_lang}-blocker-row and must exit 2 -- rc=$rc claim=$( [ -f "$W/claims/${_hq_lang}-blocker-row.claim" ] && echo written || echo none ) -- got: $(grep -E '^LOCKED|REFUSED' <<<"$out" | head -3)"; fi
grep -q 'REFUSED PROMOTION' <<<"$out" && grep -q "${_hq_lang}-blocked-row" <<<"$out" && grep -q "${_hq_lang}-blocker-row" <<<"$out" && grep -q 'NO language' <<<"$out" \
  && ck ok "(a2) the refusal is printed, naming the blocked row, the blocker and the reason (no language)" \
  || ck no "(a2) the refusal must name both topics and say the seat holds no language -- got: $out"
# (b) ceo, whose s4e_my_lane is deliberately empty
reset_q
mk 0 ${_hq_lang}-blocked-row "$_hq_owner" BLOCKED-ON:${_hq_lang}-blocker-row
mk 0 ${_hq_lang}-blocker-row "$_hq_owner" FREE
out="$(run_next ceo)"; rc=$?
[ ! -f "$W/claims/${_hq_lang}-blocker-row.claim" ] && ck ok "(b) ceo (no lane at all) is NOT served the HQ's blocker either" \
  || ck no "(b) the ceo must not claim ${_hq_lang}-blocker-row -- got: $(grep -E '^LOCKED' <<<"$out")"
# (c) CONTROL: the owning HQ IS served the blocker by dependency inversion
reset_q
mk 0 ${_hq_lang}-blocked-row "$_hq_owner" BLOCKED-ON:${_hq_lang}-blocker-row
mk 0 ${_hq_lang}-blocker-row "$_hq_owner" FREE
out="$(run_next "$_hq_owner")"; rc=$?
[ -f "$W/claims/${_hq_lang}-blocker-row.claim" ] && grep -q 'DEPENDENCY INVERSION' <<<"$out" && ck ok "(c) CONTROL: the owning HQ $_hq_owner IS served the blocker by dependency inversion (claim written)" \
  || ck no "(c) CONTROL broken: $_hq_owner must be served ${_hq_lang}-blocker-row -- rc=$rc got: $(grep -E '^LOCKED|REFUSED|EMPTY' <<<"$out" | head -3)"
# (d) CONTROL: a language-owning officer with its own FREE row is served its own row, not the HQ's blocker
if [ -n "$_off_owner" ]; then
  reset_q
  mk 0 ${_hq_lang}-blocked-row "$_hq_owner" BLOCKED-ON:${_hq_lang}-blocker-row
  mk 0 ${_hq_lang}-blocker-row "$_hq_owner" FREE
  mk 1 ${_off_lang}-own-row "$_off_owner" FREE
  out="$(run_next "$_off_owner")"; rc=$?
  [ -f "$W/claims/${_off_lang}-own-row.claim" ] && [ ! -f "$W/claims/${_hq_lang}-blocker-row.claim" ] \
    && ck ok "(d) CONTROL: $_off_owner (owns $_off_lang) is served its own row, never the HQ's blocker" \
    || ck no "(d) CONTROL broken for $_off_owner -- rc=$rc got: $(grep -E '^LOCKED|REFUSED|EMPTY' <<<"$out" | head -3)"
else printf '  ----  (d) [UNBUILDABLE: no officer owns a language in the table today]\n'; fi
# (e) coo with an instrument row of its own is served it, rc=0
reset_q
mk 0 ${_hq_lang}-blocked-row "$_hq_owner" BLOCKED-ON:${_hq_lang}-blocker-row
mk 0 ${_hq_lang}-blocker-row "$_hq_owner" FREE
mk 1 postoffice-fixture-instrument-row coo FREE
out="$(run_next coo)"; rc=$?
[ -f "$W/claims/postoffice-fixture-instrument-row.claim" ] && [ ! -f "$W/claims/${_hq_lang}-blocker-row.claim" ] && [ "$rc" = 0 ] \
  && ck ok "(e) coo IS served its own instrument row (owner cell coo), rc=0 -- a lane-less seat is not starved of its rows" \
  || ck no "(e) coo must be served postoffice-fixture-instrument-row and nothing else -- rc=$rc got: $(grep -E '^LOCKED|REFUSED|EMPTY' <<<"$out" | head -3)"
# (f) coo, ordinary path: an UNASSIGNED row whose language prefix maps to an HQ's lane (the wandering case the owner-cell
#     skip does not catch, because there is no owner cell) is NOT served on the fallback, rc=2 with the reason
reset_q
mk 1 ${_hq_lang}-plain-free-row unassigned FREE
out="$(run_next coo)"; rc=$?
[ ! -f "$W/claims/${_hq_lang}-plain-free-row.claim" ] && [ "$rc" = 2 ] && grep -q 'NO language' <<<"$out" \
  && ck ok "(f) coo, ordinary path: an unassigned ${_hq_lang}-prefixed FREE row is NOT served by the cross-lane fallback, rc=2 with the reason" \
  || ck no "(f) coo must not claim ${_hq_lang}-plain-free-row (unassigned, ${_hq_lang}- prefix) and must exit 2 -- rc=$rc got: $(grep -E '^LOCKED|REFUSED|EMPTY' <<<"$out" | head -3)"
# (f2) the same row with the HQ in its owner cell: not claimed either (the owner-cell skip, pre-existing; any non-zero rc)
reset_q
mk 1 ${_hq_lang}-owned-free-row "$_hq_owner" FREE
out="$(run_next coo)"; rc=$?
[ ! -f "$W/claims/${_hq_lang}-owned-free-row.claim" ] && [ "$rc" != 0 ] \
  && ck ok "(f2) coo is not served an HQ-owned FREE row either (owner-cell skip), rc=$rc" \
  || ck no "(f2) coo must not claim ${_hq_lang}-owned-free-row -- rc=$rc got: $(grep -E '^LOCKED' <<<"$out" | head -2)"
echo "population: $checks arm(s) graded, $fails FAIL"
if [ "$fails" -gt 0 ]; then echo "⛔ GATE RED [s4e_next_any_lane_fallback_refuses_a_seat_with_no_language]: $fails of $checks arm(s) FAIL"; exit 1; fi
echo "GATE PASS [s4e_next_any_lane_fallback_refuses_a_seat_with_no_language]: $checks of $checks arm(s) hold"

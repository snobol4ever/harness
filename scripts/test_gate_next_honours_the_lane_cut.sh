#!/usr/bin/env bash
# test_gate_next_honours_the_lane_cut.sh -- THE DEPENDENCY-PROMOTION PATH IN `next` MUST HONOUR THE SAME
# LANE CUT AND MODE LANGUAGE FREEZE THE ORDINARY FREE-ROW PATH ALREADY APPLIES, BEFORE IT EVER CLAIMS A ROW.
# Row next-dependency-promotion-walks-around-the-mode-lane-filter (seat01 measured the class; hq_B minted).
#
# THE MEASURED DEFECT: with MODE reading FLEET-8 ON SNOBOL4 ONLY and seat01's lane being snoflake/aisnobol/
# dotnet, `next` served and CLAIMED icon-ladder-every-feature-in-isolation-with-variations (rank 1, Icon) --
# promoted as the blocker of another rank-1 Icon row. THE ENABLING DEFECT: s4e_servable_blocker (CURE 1,
# picker-dependency-and-boomerang-blindness) only asks "is the blocker in a servable STATE" and, on yes,
# the caller claims and serves it immediately -- neither the lane filter nor any language-freeze check
# (which did not exist at all) ever ran on the PROMOTED row, only on the row it displaced.
#
# WHAT IT PROVES, against a THROWAWAY postoffice (S4E_POST) so the live queue is never read or written:
#   (a) OWN-LANE PASS REFUSES A CROSS-LANE PROMOTION: a blocked own-lane row whose blocker is a DIFFERENT
#       lane's FREE row does NOT get that blocker promoted+served in the own-lane pass -- a genuine
#       own-lane row at a worse rank is served instead, exactly as the ordinary FREE-row path already
#       prefers own-lane over rank.
#   (b) THE REFUSAL IS PRINTED, NEVER SILENT: naming the blocked row, the refused blocker, and the lane
#       mismatch -- per the row's own explicit requirement.
#   (c) CROSS-LANE FALLBACK STILL WORKS FOR PROMOTION: when the seat's own lane truly has nothing else
#       servable, the blocker IS promoted and served cross-lane -- dependency inversion is not removed,
#       only gated, exactly as the row's GOAL insists ("do NOT fix this by removing dependency promotion").
#   (d) THE MODE LANGUAGE FREEZE REFUSES A PROMOTION EVEN WHEN THE LANE MATCHES: a same-lane blocker whose
#       LANGUAGE differs from an active "ON <LANG> ONLY" freeze is refused -- this is the actual shape of
#       the reported incident (owner cell was already correct; nothing but a language-phase rule should
#       have stopped it, and until this fix nothing did).
#   (e) THE FREEZE REFUSAL IS ALSO PRINTED, NEVER SILENT.
#   (f) POSITIVE CONTROL -- NO FREEZE ACTIVE: the identical same-lane, wrong-"language" blocker from (d) IS
#       promotable when MODE carries no "ON ... ONLY" clause -- proves the freeze check does not misfire
#       when it should be a no-op, not just that it fires when it should.
#   (g) POSITIVE CONTROL -- LANGUAGE-NEUTRAL TOPIC: a promotion candidate with no recognized language
#       prefix (tooling/meta, this row's own kind of topic) is unaffected by an active freeze.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="${SUT:-$HERE/s4e_msg.sh}"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -f "$SUT" ] || refuse "picker under test not found: $SUT"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_promo_lane.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/tasks" "$W/claims" "$W/released"
for s in ceo hq_C hq_B hq_P hq_T seat07; do mkdir -p "$W/$s/inbox" "$W/$s/archive"; done

# ⛔⭐⭐ THE FIXTURE BRINGS ITS OWN TWO-LANE TABLE, BECAUSE ITS SUBJECT IS PROMOTION AND FREEZE, NOT THE
# LIVE LANE CUT (COO-80, 2026-09-19, row instrument-the-nineteen-non-gc-blocking-arms; ceo CEO-953 directed
# this shape: "Cure the SCENARIO -- let it build its own two-seat table in its scratch postoffice -- rather
# than the lane table"). THE HISTORY THIS CLOSES: the picker's language->owner table is a baked `case` inside
# s4e_msg.sh, and every mode that gives all seven languages to one seat dissolves this gate's scenario. Under
# MODE CEO it printed three arms UNBUILDABLE; under TRIO and QUARTET (all seven to the ceo) it REFUSED rc=2
# outright and took `make test-postoffice` down with it, which is one of the twenty-three blocking arms that
# left every seat without a landing gate (CEO-944). The gate was correct to refuse rather than lower its bar,
# and correct not to be cured by editing the live lane table -- but a fixture that can only run in modes with
# two or more lanes is a fixture that goes dark exactly when the fleet consolidates.
# ⭐ SO THE SCENARIO IS MADE SELF-SUFFICIENT. Everything else this gate needs it already builds in its own
# throwaway postoffice: the queue, the claims, the seats, and MODE itself via set_mode. The one thing it could
# not build was the table, so it now stages a COPY of the picker under test with a pinned two-lane table and
# runs that. ⛔ THIS IS NOT THE FIXTURE RESTATING ITS SUBJECT'S FACTS -- the failure the header above warns
# about at length. It pins the table it needs to EXERCISE the mechanism, and the mechanism -- the promotion
# path, the lane filter, the language freeze -- is the real one, unmodified, in the same file. WHETHER THE
# LIVE TABLE IS RIGHT IS A DIFFERENT GATE'S JOB: the table is compared to MODE line 2 language by language by
# the gate beside it, which is why that comparison is deliberately NOT restated here.
# ⛔ AND THE STAGING IS PROVEN, NEVER ASSUMED: the rewrite refuses rc=2 if the function it means to replace
# is not found, and refuses again if the staged copy does not read back the pinned owners. A fixture that
# silently failed to install its own table would grade the live one and call the result a promotion defect.
_PINNED_OWN_LANG=icon; _PINNED_OWN_OWNER=hq_icon; _PINNED_CROSS_OWNER=hq_P
. "$HERE/lib_gate.sh"
command -v gate_stage_picker_lane_table >/dev/null 2>&1 || refuse "lib_gate.sh carries no gate_stage_picker_lane_table -- the staging rule is a sourced authority and a gate must never keep a private copy of it"
gate_stage_picker_lane_table "$SUT" "$W/picker_fixture.sh" "$_PINNED_CROSS_OWNER" "$_PINNED_OWN_LANG=$_PINNED_OWN_OWNER"
case $? in
  0) : ;;
  3) refuse "could not find s4e_lane_owner_of_language() in $SUT to stage the fixture's two-lane table -- the picker's table has moved or been renamed, and a lane fixture that cannot install its own table must not grade the live one" ;;
  4) refuse "the staged picker does not read back its pinned two-lane table -- the rewrite landed but did not take, and grading would silently be against the live table" ;;
  *) refuse "staging the fixture picker from $SUT failed" ;;
esac
SUT="$W/picker_fixture.sh"
mkdir -p "$W/$_PINNED_OWN_OWNER/inbox" "$W/$_PINNED_OWN_OWNER/archive" "$W/$_PINNED_CROSS_OWNER/inbox" "$W/$_PINNED_CROSS_OWNER/archive"
# ⛔⭐⭐ THE FIXTURE DERIVES ITS LANGUAGE FROM THE PICKER UNDER TEST, AND NAMES NONE (hq_B 2026-09-13, ceo
# CEO-672). This block used to read `printf 'hq_B\n' > "$W/seat07/HQ"` with the comment "seat07's lane is
# hq_B for this fixture (icon)", and every row below hardcoded `hq_B` as its owner cell -- a FOURTH copy of
# the language->owner table, living inside the very test that grades the picker that owns the table.
# ⭐ WHEN NONET MOVED ICON TO THE CEO, CHECK (a) WENT RED FOR THE WRONG REASON. Promotion had not broken; the
# fixture still believed hq_B owned Icon, so seat07 had no own-lane row and the cross-lane blocker was
# CORRECTLY promoted. A fixture that restates its subject's facts does not fail when the subject is wrong --
# it fails when the subject is RIGHT and has moved, which is the most expensive red there is: it points at
# the cure and calls it the bug. Editing the assertion to match would have buried a real defect.
# ⛔ AND CHASING IT UNCOVERED THE REAL ONE: `s4e_my_lane` recognises only hq_* names, so an executive is not a
# lane at all. Under NONET four of the seven completeness owners ARE executives, so a seat whose HQ is one of
# them resolves to NO lane and goes lane-blind. That is documented, deliberate ("ceo is never restricted") and
# is a separate ruling from this row -- so the fixture must not depend on it either way.
# ⭐ SO IT ASKS FOR WHAT IT ACTUALLY NEEDS: a language whose owner IS lane-determinable, chosen at run time.
# The checks below grade the PROMOTION and FREEZE mechanisms, which is their real subject, and they now
# survive every future lane cut without an edit.
_lane_owner_of(){ bash -c '. /dev/stdin <<<"$(sed -n "/^s4e_lane_languages()/,/^s4e_lane_help()/p" "$1")"; s4e_lane_owner_of_language "$2"' _ "$SUT" "$1" 2>/dev/null; }
_lane_langs="$(bash -c '. /dev/stdin <<<"$(sed -n "/^s4e_lane_languages()/,/^s4e_lane_help()/p" "$1")"; s4e_lane_languages' _ "$SUT" 2>/dev/null)"
[ -n "$_lane_langs" ] || refuse "cannot read the language list out of $SUT -- a lane fixture that cannot see the lane table must not grade it"
# The frozen language in blocks (d)-(g) is SNOBOL4 by name (the freeze string is prose in MODE), so the
# fixture's OWN language must be a different one, or (d) would be testing two mechanisms at once.
_own_lang=""; _own_owner=""
# ⛔ AND ITS OWNER MUST DIFFER FROM SNOBOL4's (ceo CEO-766, 2026-09-16): blocks (a)-(c) grade a CROSS-lane
# promotion, and the cross language is snobol4 BY NAME, so an own language that shares snobol4's owner makes
# the blocker an own-lane row -- the picker promotes it, correctly, and the gate reads 2 of 10 RED on a correct
# picker. Measured the minute the cfo took icon beside snobol4. Skipping same-owner languages keeps a cross
# lane in the fixture whenever one exists; when none exists the one-owner logic below decides.
_sno_owner="$(_lane_owner_of snobol4)"
for _l in $_lane_langs; do
  [ "$_l" = snobol4 ] && continue
  _o="$(_lane_owner_of "$_l")"
  [ -n "$_sno_owner" ] && [ "$_o" = "$_sno_owner" ] && continue
  # ⛔ ceo IS ADMITTED HERE AND THAT IS NOT A CONTRADICTION OF THE LAW ABOVE (ceo CEO-755, MODE CEO). The law
  # restricts the ceo IDENTITY -- ME=ceo is never lane-filtered. This fixture never runs AS the ceo: it runs as
  # a numbered seat whose HQ file names the owner, and a seat reporting to the ceo is lane-determinable exactly
  # as a seat reporting to an HQ is. Refusing ceo here would have made the gate ungradable in the one mode where
  # every language has the same owner -- i.e. it would go dark precisely when the lane cut is simplest to check.
  case "$_o" in hq_*|ceo|cto|cfo|coo) _own_lang="$_l"; _own_owner="$_o"; break;; esac
done
[ -n "$_own_lang" ] || refuse "no language in the picker's table is owned by a lane-determinable seat (hq_*, ceo, cto, cfo or coo), so an own-lane scenario cannot be built. This is a real finding about the lane cut, not a broken fixture -- report it rather than lowering the bar."
# ⛔⭐⭐ HOW MANY LANES DOES THE TABLE ACTUALLY HAVE? (ceo CEO-755, the day MODE went to CEO.) Blocks (a)-(c)
# grade a CROSS-lane promotion, and a cross lane has to EXIST to be graded. Under a single-seat mode the
# table gives all seven languages to one owner, so there is no second lane and the fixture's old cross-lane
# row -- a snobol4 row with an `unassigned` owner cell -- resolved to the SAME lane and was promoted, exactly
# as the picker should. That read as 2 of 10 arms RED: a gate reporting a defect in the thing it grades when
# the real event was its own scenario dissolving. ⛔ AND THE EXPLICIT-OWNER WORKAROUND DOES NOT WORK EITHER,
# which is worth writing down so the next reader does not spend the hour: giving the blocker a hq_B owner cell
# makes (a) and (b) gradable but breaks (c), because an owner-cell skip is not a lane skip -- arm (j) proves
# a row owned by another seat is never auto-served in EITHER pass, so the blocker could not be promoted.
# ⛔ SO THE THREE ARMS ARE UNBUILDABLE, AND THE CHOICE IS STATED RATHER THAN TAKEN SILENTLY: a one-owner table
# under a mode that DECLARES one working seat is the lane cut being dormant, not broken -- those arms are
# printed UNBUILDABLE by name and the population is stated with the verdict. A one-owner table under a
# multi-seat mode is a CONTRADICTION and still refuses rc=2. The difference is whether the law says so.
_n_owners="$(for _l in $_lane_langs; do _lane_owner_of "$_l"; echo; done | sort -u | grep -c .)"
_live_mode="$(head -1 "${S4E_POST_LIVE:-/home/resources/postoffice}/MODE" 2>/dev/null | tr -d '[:space:]')"
_one_lane=0
if [ "${_n_owners:-0}" -le 1 ]; then
  case "$_live_mode" in
    CEO) _one_lane=1 ;;
    *) refuse "the picker's table gives every language to ONE owner ($_own_owner) while MODE line 1 reads '${_live_mode:-unreadable}', which declares more than one working seat. A cross-lane scenario cannot be built and this disagreement is the finding: either the table collapsed or the mode did." ;;
  esac
fi
mkdir -p "$W/$_own_owner/inbox" "$W/$_own_owner/archive"
printf '%s\n' "$_own_owner" > "$W/seat07/HQ"     # seat07's lane is whoever owns $_own_lang TODAY, read from the picker itself
echo "    fixture: own lane = $_own_owner (owns $_own_lang), cross/frozen language = snobol4"
mk(){ printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$W/QUEUE.tsv"; printf '# TASK %s\nGOAL: fixture\nDONE-WHEN: true\n## NEXT\nfixture\n## QA\n## LEDGER\n' "$2" > "$W/tasks/$2.task.md"; }
run_next(){ S4E_POST="$W" S4E_SEAT="$1" S4E_RELEASE_COOLDOWN=0 bash "$SUT" next 2>&1; }
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
reset_q(){ : > "$W/QUEUE.tsv"; rm -f "$W/claims/"*.claim 2>/dev/null; }
set_mode(){ printf '%s\n' "$1" > "$W/MODE"; }

echo "=== gate: next's dependency-promotion path honours the lane cut and the MODE language freeze ==="

# --- (a)+(b)+(c): THE LANE CUT ---------------------------------------------------------------------------
set_mode 'FLEET-16'   # no language freeze active for this block -- isolates the LANE mechanism alone

# (a)+(b): own-lane pass must refuse to promote a cross-lane blocker, and say so; a genuine own-lane
# row at a worse rank is served instead.
unbuilt=0
unbuildable(){ unbuilt=$((unbuilt+1)); printf '  ----  %s  [UNBUILDABLE: %s]\n' "$1" "$2"; }
if [ "$_one_lane" = 1 ]; then
  unbuildable "(a) own-lane pass serves the genuine own-lane fallback row, not the cross-lane promoted blocker" "one lane under MODE CEO"
  unbuildable "(b) the refusal is printed, naming both the blocked row and the refused blocker" "one lane under MODE CEO"
  unbuildable "(c) cross-lane fallback still promotes the blocker when the seat's own lane has nothing else" "one lane under MODE CEO"
else
reset_q
mk 0 ${_own_lang}-blocked-row      "$_own_owner" BLOCKED-ON:snobol4-blocker-row
mk 5 snobol4-blocker-row   unassigned FREE
mk 1 ${_own_lang}-fallback-row     unassigned FREE
out="$(run_next seat07)"
grep -qE "^LOCKED.*${_own_lang}-fallback-row" <<<"$out" && ! grep -qE '^LOCKED.*snobol4-blocker-row' <<<"$out" \
  && ck ok "(a) own-lane pass serves the genuine own-lane fallback row, not the cross-lane promoted blocker" \
  || ck no "(a) a cross-lane blocker must not be promoted while an own-lane row is servable -- got: $(grep -E '^LOCKED' <<<"$out")"
grep -qi 'REFUSED PROMOTION' <<<"$out" && grep -q "${_own_lang}-blocked-row" <<<"$out" && grep -q 'snobol4-blocker-row' <<<"$out" \
  && ck ok "(b) the refusal is printed, naming both the blocked row and the refused blocker" \
  || ck no "(b) a refused promotion must be a visible REFUSAL naming both topics, never a silent skip -- got: $out"

# (c): with NO own-lane fallback available at all, the cross-lane blocker IS still promoted+served --
# dependency inversion keeps working, only gated by lane, not removed.
reset_q
mk 0 ${_own_lang}-blocked-row2     "$_own_owner" BLOCKED-ON:snobol4-blocker-row2
mk 5 snobol4-blocker-row2  unassigned FREE
out="$(run_next seat07)"
grep -qE '^LOCKED.*snobol4-blocker-row2' <<<"$out" \
  && ck ok "(c) cross-lane fallback still promotes the blocker when the seat's own lane has nothing else" \
  || ck no "(c) dependency promotion must still work cross-lane when nothing own-lane is servable -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"
fi

# --- (d)+(e)+(f): THE MODE LANGUAGE FREEZE ---------------------------------------------------------------
# Same lane on both rows this time (deliberately) so a refusal here can ONLY be explained by the freeze,
# never by the lane cut above -- isolates the item-(3) mechanism from item-(2)'s.
set_mode 'FLEET-8
# 2026-09-04 18:23 CDT ceo: MODE FLEET-16 -> FLEET-8 ON SNOBOL4 ONLY, on Lon'"'"'s word'

# (d)+(e): an active SNOBOL4-only freeze refuses a same-lane Icon blocker, and says so; a same-lane
# SNOBOL4-language row at a worse rank is served instead.
reset_q
mk 0 ${_own_lang}-blocked-row3       "$_own_owner" BLOCKED-ON:${_own_lang}-frozen-blocker
mk 5 ${_own_lang}-frozen-blocker     "$_own_owner" FREE
mk 1 snobol4-fallback-row    unassigned FREE
out="$(run_next seat07)"
grep -qE '^LOCKED.*snobol4-fallback-row' <<<"$out" && ! grep -qE "^LOCKED.*${_own_lang}-frozen-blocker" <<<"$out" \
  && ck ok "(d) an active SNOBOL4-only freeze refuses a same-lane blocker of the OTHER language; the SNOBOL4 fallback row is served instead" \
  || ck no "(d) the freeze must refuse promotion by LANGUAGE even when the lane matches -- got: $(grep -E '^LOCKED' <<<"$out")"
grep -qi 'REFUSED PROMOTION' <<<"$out" && grep -qi 'SNOBOL4' <<<"$out" \
  && ck ok "(e) the freeze refusal is printed and names the frozen language" \
  || ck no "(e) a freeze-refused promotion must be a visible, named REFUSAL, never a silent skip -- got: $out"

# (f) POSITIVE CONTROL: identical fixture, no freeze active -- the Icon blocker IS promotable. Proves the
# freeze check is not simply always-refusing (a checker that never fires or always fires both pass silently
# without this control -- the standing lesson to test both arms, not just the reported direction).
set_mode 'FLEET-16'
reset_q
mk 0 ${_own_lang}-blocked-row3       "$_own_owner" BLOCKED-ON:${_own_lang}-frozen-blocker
mk 5 ${_own_lang}-frozen-blocker     "$_own_owner" FREE
mk 1 snobol4-fallback-row    unassigned FREE
out="$(run_next seat07)"
grep -qE "^LOCKED.*${_own_lang}-frozen-blocker" <<<"$out" \
  && ck ok "(f) CONTROL: the same same-lane blocker IS promoted when no MODE freeze is active" \
  || ck no "(f) CONTROL FAILED: with no freeze active, promotion must work exactly as before this row -- got: $(grep -E '^LOCKED' <<<"$out")"

# (g) POSITIVE CONTROL: a language-neutral promotion candidate (no recognized prefix) is never frozen out.
set_mode 'FLEET-8
# 2026-09-04 18:23 CDT ceo: MODE FLEET-16 -> FLEET-8 ON SNOBOL4 ONLY, on Lon'"'"'s word'
reset_q
mk 0 ${_own_lang}-blocked-row4        "$_own_owner" BLOCKED-ON:postoffice-tooling-blocker
mk 5 postoffice-tooling-blocker unassigned FREE
out="$(run_next seat07)"
grep -qE '^LOCKED.*postoffice-tooling-blocker' <<<"$out" \
  && ck ok "(g) CONTROL: a language-neutral blocker is promoted even under an active freeze" \
  || ck no "(g) CONTROL FAILED: a topic with no recognized language prefix must never be frozen out -- got: $(grep -E '^LOCKED' <<<"$out")"

# --- (h)+(i)+(j): A ROW OWNED BY THE SEAT'S OWN HQ IS SERVED -------------------------------------------
# ⛔ seat09's EXACT CASE, 2026-09-04 19:52, when SIX SEATS SAT IDLE at load 0.65 with sixteen up: a seat whose
# HQ file says hq_P, and a FREE rank-1 row whose owner cell says hq_P. Every lane reported "queue empty" while
# QUEUE.tsv held seven such rows per lane, because under THE SNOBOL4 CUT every class row an HQ mints carries its
# own owner cell -- so the owner-cell skip hid the entire body of assigned work in all four lanes at once.
# ⭐ (j) IS THE ARM THAT KEEPS THE CURE HONEST: another HQ's row must STILL be skipped. Serving those would
# dissolve the lane boundary the cut exists to draw, and the fix for wanting one is `claim`, typed on purpose.
set_mode 'FLEET-16'
reset_q
printf 'hq_P\n' > "$W/seat07/HQ"
mk 1 snobol4-row-owned-by-my-own-hq  hq_P FREE
out="$(run_next seat07)"
grep -qE '^LOCKED.*snobol4-row-owned-by-my-own-hq' <<<"$out" \
  && ck ok "(h) a FREE row owned by the seat's OWN HQ is served (seat09's case: six seats idle before this)" \
  || ck no "(h) an own-HQ row must be served, not skipped as if a rival seat held it -- got: $(grep -E '^LOCKED|QUEUE EMPTY' <<<"$out")"
grep -qiE 'owned by your HQ' <<<"$out" \
  && ck ok "(i) and the serve REASON says so, so a reader can tell it from an unowned pick" \
  || ck no "(i) the printout must name why it was served -- got: $out"
reset_q
mk 1 icon-row-owned-by-another-hq  hq_B FREE
out="$(run_next seat07)"
! grep -qE '^LOCKED.*icon-row-owned-by-another-hq' <<<"$out" \
  && ck ok "(j) CONTROL: a row owned by a DIFFERENT HQ is still skipped -- the lane boundary holds" \
  || ck no "(j) CONTROL FAILED: another HQ's row must never be auto-served; that is what `claim` is for"
printf 'hq_B\n' > "$W/seat07/HQ"

echo "------------------------------------------------------------"
[ "$fails" -ne 0 ] && { echo "⛔ GATE FAIL: $fails of $checks check(s) failed ($unbuilt unbuildable in this mode, named above)"; exit 1; }
[ "${unbuilt:-0}" -ne 0 ] && { echo "✅ GATE PASS: $checks graded, 0 red — $unbuilt arm(s) UNBUILDABLE under a one-lane mode and named above, never counted green"; exit 0; }
echo "✅ GATE PASS: $checks/$checks checks"; exit 0

#!/usr/bin/env bash
# test_gate_handoff_status_lane_scoped_debt_and_refusal_never_reads_complete.sh -- OWED .s ARTIFACTS BLOCK ONLY THE SEAT WHOSE LANE
# OWES THEM, WITH THE OWNER NAMED, AND A SUB-CHECK THAT COULD NOT MEASURE MAKES THE HANDOFF VERDICT REFUSE, NEVER COMPLETE (coo
# 2026-09-16; hq_prolog's and hq_snobol4's witnesses; row handoff-status-artifact-check-blocks-every-seat-for-one-lanes-debt-and-
# a-refused-check-still-reads-complete).
#
# ARMS (hermetic: lib_handoff_verdict.sh sourced against a scratch MODE; handoff_status.sh read statically for its routing):
#   (a) lane of an artifact: benchmarks/prolog/x.s -> prolog, demos/snobol4/r/r.s -> snobol4, prolog_bench:x -> prolog, icon_bench:x -> icon, other -> unknown
#   (b) a seat's lanes from LANES:, the lane owner of a language, and an officer with none
#   (c) hq_snobol4 with only prolog debt: INFO naming hq_prolog, rc 0 (not blocked); with a snobol4 artifact: BLOCK, rc 1
#   (d) the coo (no lane) with prolog debt: INFO, rc 0; an artifact of unknown lane BLOCKS everyone, named
#   (e) STATIC: handoff_status.sh routes the stale-binary refusal, the rc=2 refusal, the missing verifier and the SKIP to `unknown`
#       (the composite's CHAT SESSION REFUSES path) and no longer sets `blocked` for another lane's debt
# FAIL_ONCE=1 swaps arm (c)'s blocking artifact into another lane so the expected BLOCK never comes, proving the arm trips.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; LIB="$HERE/lib_handoff_verdict.sh"; HS="$HERE/handoff_status.sh"
[ -f "$LIB" ] && [ -f "$HS" ] || { echo "⛔ REFUSED-TO-GRADE: need $LIB and $HS"; exit 2; }
. "$LIB"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; MODE="$W/MODE"; printf 'DECTET\n# fixture\nLANES: icon=hq_icon prolog=hq_prolog snobol4=hq_snobol4 rebus=cfo\n' > "$MODE"
fails=0; checks=0; ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: lane-scoped artifact debt, and a refused check never reads COMPLETE ==="
l="$(handoff_lane_of_artifact benchmarks/prolog/x.s)/$(handoff_lane_of_artifact demos/snobol4/r/r.s)/$(handoff_lane_of_artifact prolog_bench:x.s)/$(handoff_lane_of_artifact icon_bench:x.icn)/$(handoff_lane_of_artifact weird.s)"
[ "$l" = "prolog/snobol4/prolog/icon/unknown" ] && ck ok "(a) lane of an artifact from its path: $l" || ck no "(a) got $l"
[ "$(handoff_seat_lanes hq_prolog "$MODE")" = prolog ] && [ -z "$(handoff_seat_lanes coo "$MODE")" ] && [ "$(handoff_lane_owner snobol4 "$MODE")" = hq_snobol4 ] && ck ok "(b) hq_prolog's lanes = prolog, the coo's = none, snobol4's owner = hq_snobol4" || ck no "(b) lanes: prolog=[$(handoff_seat_lanes hq_prolog "$MODE")] coo=[$(handoff_seat_lanes coo "$MODE")] owner=[$(handoff_lane_owner snobol4 "$MODE")]"
out="$(handoff_owed_verdict hq_snobol4 $'benchmarks/prolog/a.s\nprolog_bench:b.s' "$MODE")"; rc=$?
[ "$rc" = 0 ] && grep -q '^INFO  lane=prolog owed=2 -- owed by hq_prolog, not by hq_snobol4' <<<"$out" && ! grep -q '^BLOCK' <<<"$out" && ck ok "(c1) hq_snobol4 with only prolog debt: INFO naming hq_prolog as the owner, not blocked" || ck no "(c1) rc=$rc -- $out"
ART='demos/snobol4/roman/roman.s'; [ -n "${FAIL_ONCE:-}" ] && ART='demos/icon/roman/roman.s'
out="$(handoff_owed_verdict hq_snobol4 $'benchmarks/prolog/a.s\n'"$ART" "$MODE")"; rc=$?
[ "$rc" = 1 ] && grep -q '^BLOCK lane=snobol4 owed=1 -- YOUR lane (hq_snobol4)' <<<"$out" && grep -q '^INFO  lane=prolog' <<<"$out" && ck ok "(c2) hq_snobol4 with a snobol4 artifact owed: BLOCK for its own lane, the prolog debt still INFO" || ck no "(c2) rc=$rc -- $out"
out="$(handoff_owed_verdict coo $'benchmarks/prolog/a.s' "$MODE")"; rc=$?
[ "$rc" = 0 ] && grep -q '^INFO  lane=prolog owed=1 -- owed by hq_prolog, not by coo' <<<"$out" && ck ok "(d1) the coo (no lane) with prolog debt: INFO, not blocked" || ck no "(d1) rc=$rc -- $out"
out="$(handoff_owed_verdict coo $'weird.s' "$MODE")"; rc=$?
[ "$rc" = 1 ] && grep -q '^BLOCK lane=unknown' <<<"$out" && ck ok "(d2) an artifact whose lane cannot be read BLOCKS everyone, named" || ck no "(d2) rc=$rc -- $out"
n_unknown="$(grep -c 'unknown=1; unknown_reasons+=(".s artifact drift NOT GRADED' "$HS")"
grep -q 'handoff_owed_verdict "\$_ho_seat"' "$HS" && [ "$n_unknown" -ge 4 ] && ! grep -q 'blocked=1; reasons+=(".s artifacts OWED — regenerate' "$HS" \
  && ck ok "(e) STATIC: handoff_status.sh routes $n_unknown not-measured outcomes to unknown (the REFUSES path) and blocks by lane through handoff_owed_verdict" \
  || ck no "(e) STATIC: unknown routes=$n_unknown; lane verdict wired=$(grep -c 'handoff_owed_verdict' "$HS")"
echo "population: $checks arm(s) graded, $fails FAIL"
[ "$fails" = 0 ] && { echo "GATE PASS [handoff_status_lane_scoped_debt_and_refusal_never_reads_complete]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [handoff_status_lane_scoped_debt_and_refusal_never_reads_complete]: $fails of $checks arms FAIL"; exit 1

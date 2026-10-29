#!/usr/bin/env bash
# test_gate_gc_a_parked_block_walk_is_collector_neutral_over_every_tabled_shape_the_engine_reaches.sh -- THE PARKED SEGMENT BLOCK'S WALK
# (ARCH-PROLOG-WFS-TABLING.md 8.8 (12), 8.10 (5) (7); the cfo's step 6; hq_collector 2026-10-29, CEO-2010).
#
# THE PROPERTY.  A consumer that finds no unreturned answer is suspended as a heap block of type HB_PSEG (a copy of its stack segment, the trail range it
# owns and the rebind vector); the collector walks that block with ONE bias over its bytes and forwards every heap pointer in it, and during a resumed run
# the live walk takes the restored generator record's resumer words (header cell 12).  Green means: every tabled witness prints the SAME answer with a
# collection at every safe point (SCRIP_GC_STRESS=1) and at every third (=3) as it prints with none, in BOTH modes, with SCRIP_GC_CHAIN_CHECK=3 reading
# no mismatch, no frameless frame, no site-less pc and no difference between rt_gc_frames_visit and the collector's own chain, AND the block walk actually
# ran (pseg-walks in the [CHAIN-WALK] SUMMARY line is above zero at stress 1 for every witness that suspends a consumer).  The control is a non-tabled
# witness: it suspends nothing, so its pseg-walks must read exactly 0, which proves the counter can read zero.
#
# THE WITNESSES (gc_witnesses/hb_pl_slg_*): the cfo's five (a negation cycle with and without writes, xw07's negations-once, a left-recursive path, a
# ball thrown out of a resumed continuation) and four of mine: a consumer parked inside a resumed run under ANOTHER generator (a nested park), an
# INDEPENDENT tabled SCC that runs inside a resumed consumer's continuation (a nested resume), a three-table SCC, an independent inner SCC under a
# left-recursive outer table.
#
# WHAT IS NOT HERE, ON PURPOSE (measured with an event log in the park and resume leaves, 2026-10-29, on a binary left untouched while it ran: the
# cfo's five, my four, 400 random tabled programs and 120 layered ones, 7,060 parks and 2,231 resumes in the generated 520 alone).  A CLIPPED RESUME (the
# restore stops at the resumer's rsp because the generator's carve top lies above it) never occurred: the slack rsp_r - X_G read 128 to 23,440 bytes at
# every one of the 2,231 resumes and was never negative, because a leader is the oldest generator of its SCC and so its loop cannot sit below a generator
# of that SCC.  A RE-USED SMALLER BLOCK cannot exist: rt_pl_pseg_park allocates a NEW block at every park and stores it over the status
# term, and a re-parked consumer parks from the same call site at the same carve top, so its segment length is the old one (2,231 re-parks, 0 differ).
# A NESTED RESUME WITH A DIFFERENT INNERMOST GENERATOR is reached by no program the engine answers correctly yet: hb_pl_slg_independent_scc_inside_a_
# resumed_continuation prints [1,2] where swipl and main print [1,2,3,4] with ZERO collections, so it is the cfo's engine; it is in this gate for its
# collector-neutrality, and its answer is graded in the REPORTED arm below, not here.
#
# THE ORACLE ARM IS REPORTED, NOT BLOCKING: the four witnesses of mine carry a .ref cut from swipl 9.0.4; a run that differs prints REPORTED RED and
# counts into oracle_red, and the gate passes anyway unless ORACLE_BLOCKING=1 (the cfo sets it in the landing that makes nested SCCs answer).
#
# THE GATE CAN FAIL (CEO-1680, a proper test, no seam in SCRIP): at SCRIP 7a88f9c9e (the cfo's tip before hq_collector's two fixes) the same runs read
# [CHAIN-VISIT] DIFFER 4 times on the negation-cycle witness and the decker scale witness aborted in gc_visit_pseg; FAIL_ONCE=1 (an INSTRUMENT switch,
# not SCRIP's) corrupts the first stress comparison to prove this script reads red.  Every run is in a throwaway directory, never a seat root.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
G="$(basename "${BASH_SOURCE[0]}" .sh)"
WD="$HERE/gc_witnesses"
SCRIP="$ROOT/scrip"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$G]: no $SCRIP to measure"; exit 2; }
T="$(mktemp -d)" || exit 2; trap 'rm -rf "$T"' EXIT
cd "$T" || exit 2
PARKING="hb_pl_slg_tnot_cycle hb_pl_slg_tnot_cycle_writes hb_pl_slg_negations_once hb_pl_slg_left_recursive_path hb_pl_slg_ball_out_of_a_resumed_continuation hb_pl_slg_consumer_parked_under_another_generator hb_pl_slg_independent_scc_inside_a_resumed_continuation hb_pl_slg_three_table_scc hb_pl_slg_independent_inner_scc_under_a_left_recursive_outer"
CONTROL="hb_pl_a_redo_into_a_later_clause_leaves_no_stale_frame_link"
red=0; oracle_red=0; arms=0; fail_once="${FAIL_ONCE:-0}"
walks_of() { sed -n 's/.*\[CHAIN-WALK\] SUMMARY.*pseg-walks=\([0-9][0-9]*\).*/\1/p' "$1" | tail -1; }
field_of() { sed -n "s/.*\[CHAIN-CHECK\] SUMMARY.* $2=\([0-9][0-9]*\).*/\1/p" "$1" | tail -1; }
vis_of() { sed -n 's/.*\[CHAIN-WALK\] SUMMARY.*visitor: same=[0-9]* differ=\([0-9][0-9]*\) refused=\([0-9][0-9]*\).*/\1 \2/p' "$1" | tail -1; }
build_m4() { "$SCRIP" --compile --out="$T/$1.s" "$WD/$1.pl" < /dev/null > /dev/null 2> "$T/$1.cerr" || return 2; gcc "$T/$1.s" -o "$T/$1.bin" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" 2> "$T/$1.lerr" || return 2; }
run_one() { local mode="$1" stem="$2" tag="$3"; shift 3
    if [ "$mode" = m3 ]; then env "$@" timeout 300 "$SCRIP" "$WD/$stem.pl" < /dev/null > "$T/$stem.$mode.$tag.out" 2> "$T/$stem.$mode.$tag.err"
    else env "$@" timeout 300 "$T/$stem.bin" < /dev/null > "$T/$stem.$mode.$tag.out" 2> "$T/$stem.$mode.$tag.err"; fi; }
for stem in $PARKING $CONTROL; do
    [ -f "$WD/$stem.pl" ] || { echo "⛔ REFUSE(2) [$G]: the witness $stem.pl is absent"; exit 2; }
    build_m4 "$stem" || { echo "⛔ REFUSE(2) [$G]: $stem did not compile and link in mode 4"; sed -n '1,3p' "$T/$stem.cerr" "$T/$stem.lerr"; exit 2; }
    for mode in m3 m4; do
        run_one "$mode" "$stem" plain A=1; rc=$?
        [ "$rc" = 0 ] || { echo "⛔ REFUSE(2) [$G]: $stem $mode plain rc=$rc -- there is no baseline to compare a collection with"; sed -n '1,3p' "$T/$stem.$mode.plain.err"; exit 2; }
        for st in 1 3; do
            run_one "$mode" "$stem" "s$st" SCRIP_GC_STRESS=$st SCRIP_GC_CHAIN_CHECK=3; rc=$?
            arms=$((arms + 1)); base="$T/$stem.$mode.plain.out"
            if [ "$fail_once" = 1 ]; then printf 'FAIL_ONCE\n' >> "$T/$stem.$mode.s$st.out"; fail_once=0; fi
            if [ "$rc" != 0 ]; then echo "⛔ RED [$G]: $stem $mode stress $st rc=$rc"; sed -n '1,3p' "$T/$stem.$mode.s$st.err"; red=$((red + 1)); continue; fi
            if ! cmp -s "$base" "$T/$stem.$mode.s$st.out"; then echo "⛔ RED [$G]: $stem $mode stress $st prints a different answer than with no collection"; red=$((red + 1)); continue; fi
            for f in mismatch nosite frameless; do v="$(field_of "$T/$stem.$mode.s$st.err" $f)"; [ "${v:-x}" = 0 ] || { echo "⛔ RED [$G]: $stem $mode stress $st chain check $f=[${v:-none}]"; red=$((red + 1)); }; done
            read -r dif ref <<< "$(vis_of "$T/$stem.$mode.s$st.err")"; { [ "${dif:-x}" = 0 ] && [ "${ref:-x}" = 0 ]; } || { echo "⛔ RED [$G]: $stem $mode stress $st chain visit differ=[${dif:-none}] refused=[${ref:-none}]"; red=$((red + 1)); }
        done
        w="$(walks_of "$T/$stem.$mode.s1.err")"
        case " $PARKING " in *" $stem "*) { [ "${w:-0}" -gt 0 ] 2>/dev/null; } || { echo "⛔ RED [$G]: $stem $mode stress 1 pseg-walks=[${w:-none}] -- the witness suspends a consumer, so the block walk must have run"; red=$((red + 1)); }; echo "[$G] $stem $mode: answers equal at stress 1 and 3, pseg-walks=$w";; *) [ "${w:-x}" = 0 ] || { echo "⛔ RED [$G]: the control $stem $mode pseg-walks=[${w:-none}], expected exactly 0"; red=$((red + 1)); }; echo "[$G] control $stem $mode: pseg-walks=0";; esac
    done
done
for stem in $PARKING; do
    [ -f "$WD/$stem.ref" ] || continue
    if ! cmp -s "$WD/$stem.ref" "$T/$stem.m3.plain.out"; then oracle_red=$((oracle_red + 1)); echo "REPORTED RED [$G]: $stem prints [$(tr -d '\n' < "$T/$stem.m3.plain.out")] where swipl prints [$(tr -d '\n' < "$WD/$stem.ref")] (no collection involved: the engine's answer)"; fi
done
[ "${ORACLE_BLOCKING:-0}" = 1 ] && red=$((red + oracle_red))
if [ "$red" != 0 ]; then echo "GATE FAIL [$G]: $red arm(s) red of $arms stress arms (oracle_red=$oracle_red)"; exit 1; fi
echo "GATE PASS [$G]: $arms stress arms over $(echo $PARKING | wc -w) tabled witnesses, both modes, answers equal to the no-collection run, chain check clean, the block walk ran (oracle_red=$oracle_red, reported)"
exit 0

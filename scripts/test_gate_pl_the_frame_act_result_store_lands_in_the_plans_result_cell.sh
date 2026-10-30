#!/usr/bin/env bash
# test_gate_pl_the_frame_act_result_store_lands_in_the_plans_result_cell.sh -- ARCH-PROLOG-ACTIVATION-LIFETIME 9.14 (b), the cto 2026-10-29 19:0x: the frame-act
# road's result store after a retained return lands in the call's own result cell, never in the callee's bottom cell at [rsp].
#
# THE SHAPE (the cfo's finding of 2026-10-29, LIFO step 3 item (1)): a staged call that does not take the spine record keeps its resume words in the
# frame (the act word) and stores the callee's result at its spine result cell. A retained callee returns with rsp at the bottom of its live region,
# so a store addressed from rsp wrote the result over the callee's bottom cell -- under the step-3 cells road that cell is a GATE_ARM's arm index, and
# the GATE's beta read arm 1 for arm 0: lifo_catch_retaining_goal printed a4([1]) for swipl's a4([1,1,1]). The cure carves the call's result cell at
# the callee's bottom on a retained return and pops it at beta before resuming the callee, as the spine record does with its 32-byte cell.
#
# THE NEGATIVE CONTROL: the spine record FORCED OFF for every staged call (SCRIP_PL_SPREC_OFF=1, the planner's diagnostic switch) with the cells road on
# (SCRIP_PL_GATE_CELLS=1) puts every retaining call of the witness on the frame-act road. RED BEFORE, measured on the tree with the switch and without
# the store's carve: a4..a8 print [1] in both modes and SCRIP_ZD_RTCHECK=1 traps at the GATE's alpha. GREEN AFTER: the witness equal to its swipl ref in
# mode 3 and mode 4, plain and under SCRIP_ZD_RTCHECK=1; then the SNOBOL4 and Icon smokes, which take the same template.
#
# THE ZSM ARM (SCRIP_ZSM=1 SCRIP_ZSM_ALL=1 SCRIP_ZSM_DECL=1), and what it can and cannot see, measured: the defect overwrote a value at the RIGHT depth,
# so the ZSM reads it nowhere -- [ZSM-DISC] is 0 with the carve and without it, and the declared-against-actual counts only fall without it because
# the wrong road does less work. The arm therefore asserts what the ZSM can say about the road: [ZSM-DISC] 0 in both modes with the spine record forced
# off, and no more [ZSM-DECL-SITE] rows than the spine-record road reads on the same witness (measured 14 against 15 in mode 3, 15 against 15 in
# mode 4). The negative control is the ref comparison and RTCHECK above, which read red before.
#
# Usage: bash ../harness/scripts/test_gate_pl_the_frame_act_result_store_lands_in_the_plans_result_cell.sh   (rc 0 green, 1 red, 2 could not measure)
set -uo pipefail
GATE_NAME=test_gate_pl_the_frame_act_result_store_lands_in_the_plans_result_cell
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
W="$HERE/../../corpus/tests/prolog/lifo/lifo_catch_retaining_goal.pl"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
[ -f "$W" ] && [ -f "${W%.pl}.ref" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: the witness or its swipl ref is missing at $W"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: no gcc -- the mode-4 arm cannot be linked"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp "$W" "$T/w.pl"; cp "${W%.pl}.ref" "$T/w.ref"
FORCE="SCRIP_PL_GATE_CELLS=1 SCRIP_PL_SPREC_OFF=1"
fail=0
arm() {
    local tag=$1 extra=$2
    ( cd "$T" && env $FORCE $extra timeout -k 5 60 "$SCRIP" w.pl < /dev/null > "$tag.m3" 2> /dev/null ); local rc3=$?
    if [ "$rc3" = 0 ] && cmp -s "$T/$tag.m3" "$T/w.ref"; then echo "  ok   ($tag m3) equal to the swipl ref with the spine record forced off"
    else echo "  FAIL ($tag m3) rc=$rc3, first difference:"; diff "$T/w.ref" "$T/$tag.m3" | head -4 | sed 's/^/         /'; fail=1; fi
    if ( cd "$T" && env $FORCE $extra "$SCRIP" --compile --out="$tag.s" w.pl < /dev/null > /dev/null 2>&1 && gcc -m64 -no-pie -o "$tag.bin" "$tag.s" -L"$RT" -lscrip_rt -lm -lpthread -Wl,-rpath,"$RT" 2> /dev/null ); then
        ( cd "$T" && env $FORCE $extra timeout -k 5 60 "./$tag.bin" < /dev/null > "$tag.m4" 2> /dev/null ); local rc4=$?
        if [ "$rc4" = 0 ] && cmp -s "$T/$tag.m4" "$T/w.ref"; then echo "  ok   ($tag m4) the same, from the standalone build"
        else echo "  FAIL ($tag m4) rc=$rc4, first difference:"; diff "$T/w.ref" "$T/$tag.m4" | head -4 | sed 's/^/         /'; fail=1; fi
    else echo "  FAIL ($tag m4) the witness did not compile or link in mode 4"; fail=1; fi
}
arm plain ""
arm rtcheck "SCRIP_ZD_RTCHECK=1"
Z="SCRIP_ZSM=1 SCRIP_ZSM_ALL=1 SCRIP_ZSM_DECL=1"
zsm_read() {
    local tag=$1 m=$2 cfg=$3
    if [ "$m" = m3 ]; then ( cd "$T" && env $cfg $Z timeout -k 5 240 "$SCRIP" w.pl < /dev/null > /dev/null 2> "$tag.$m.zsm" )
    else ( cd "$T" && env $cfg $Z "$SCRIP" --compile --out="$tag.z.s" w.pl < /dev/null > /dev/null 2>&1 && gcc -m64 -no-pie -o "$tag.z.bin" "$tag.z.s" -L"$RT" -lscrip_rt -lm -lpthread -Wl,-rpath,"$RT" 2> /dev/null && env $Z timeout -k 5 240 "./$tag.z.bin" < /dev/null > /dev/null 2> "$tag.$m.zsm" ); fi
}
for m in m3 m4; do
    zsm_read fr "$m" "$FORCE"; zsm_read sp "$m" "SCRIP_PL_GATE_CELLS=1"
    d=$(grep -c 'ZSM-DISC' "$T/fr.$m.zsm" 2> /dev/null); sf=$(grep -c 'ZSM-DECL-SITE' "$T/fr.$m.zsm" 2> /dev/null); ss=$(grep -c 'ZSM-DECL-SITE' "$T/sp.$m.zsm" 2> /dev/null)
    if ! grep -q 'ZSM-DECL-TOTAL' "$T/fr.$m.zsm" 2> /dev/null || ! grep -q 'ZSM-DECL-TOTAL' "$T/sp.$m.zsm" 2> /dev/null; then echo "  FAIL (zsm $m) a ZSM run printed no [ZSM-DECL-TOTAL]: the instrument did not run"; fail=1
    elif [ "$d" = 0 ] && [ "$sf" -le "$ss" ]; then echo "  ok   (zsm $m) [ZSM-DISC] 0; [ZSM-DECL-SITE] $sf with the spine record forced off, $ss with it"
    else echo "  FAIL (zsm $m) [ZSM-DISC] $d; [ZSM-DECL-SITE] $sf with the spine record forced off against $ss with it"; fail=1; fi
done
for l in snobol4 icon; do
    if bash "$HERE/test_smoke_$l.sh" > "$T/smoke_$l.log" 2>&1; then echo "  ok   ($l smoke) green"
    else echo "  FAIL ($l smoke) rc=$?, tail:"; tail -3 "$T/smoke_$l.log" | sed 's/^/         /'; fail=1; fi
done
[ "$fail" = 0 ] && { echo "✅ GATE PASS [$GATE_NAME]: with the spine record forced off, the frame-act road's result store lands in the call's own cell in both modes"; exit 0; }
echo "⛔ GATE RED [$GATE_NAME]"; exit 1

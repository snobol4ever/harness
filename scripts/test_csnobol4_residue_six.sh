#!/usr/bin/env bash
# test_csnobol4_residue_six.sh -- verification for task `csnobol4-residue-six` (s191-era HQ measurement,
# re-classified 2026-09-04 by seat11; FINDING-2026-09-04-seat11-csnobol4-residue-six-reclassified.md).
#
# The original six: collect2 convert intval lexcmp nqueens setexit3. Fresh classification found FOUR now
# GREEN (collect2, intval, lexcmp, setexit3 -- the first was always a misread of a comment line, the other
# three were real defects since fixed as a side effect of unrelated SNOBOL4 work landing from other seats)
# and TWO still genuinely red, each already tracked by its own row: `convert` (table/CONVERT iteration
# order -- folded into icon-arizona-class-table-iteration-order-not-insertion, cross-language) and `nqueens`
# (SIGSEGV -- snobol4-csnobol4-nqueens-sigsegv). This script checks BOTH halves of that claim: the four
# named PASS cleanly, and the two reds are still linked from a real task file (so neither silently falls
# off everyone's radar if this row closes). It does NOT require convert/nqueens to be fixed -- curing them
# is out of this row's scope (class cure is hq_P's, per the sibling suite-census row's own convention).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; SD="$HERE/../../SCRIP"; ROOT="$(cd "$SD/.." && pwd)"
SUITE="$ROOT/corpus/packages/snobol4/csnobol4_suite"
SCRIP="$SD/scrip"; TIMEOUT="${TIMEOUT:-8}"
PO="${S4E_PO:-/home/resources/postoffice}"

[ -d "$SUITE" ] || { echo "⛔ REFUSE(rc=2): suite dir missing: $SUITE"; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2): no scrip binary at $SCRIP — build first (make)"; exit 2; }
"$HERE/util_require_fresh.sh" --gate test_csnobol4_residue_six "$SCRIP" "$SD/out/libscrip_rt.so" || exit 2

GREEN_NAMES="collect2 intval lexcmp setexit3"
RED_LINKED="convert:icon-arizona-class-table-iteration-order-not-insertion nqueens:snobol4-csnobol4-nqueens-sigsegv"

fail=0
for name in $GREEN_NAMES; do
    sno="$SUITE/$name.sno"; ref="$SUITE/$name.ref"
    if [ ! -f "$sno" ] || [ ! -f "$ref" ]; then echo "RESIDUE_SIX: $name MISSING sno/ref"; fail=1; continue; fi
    got="$(SNO_LIB="$SUITE" timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$sno" < /dev/null 2>&1)"; rc=$?
    exp="$(cat "$ref")"
    if [ "$rc" = 0 ] && [ "$got" = "$exp" ]; then
        echo "RESIDUE_SIX: $name PASS (confirms resolved, not a live defect)"
    else
        echo "RESIDUE_SIX: $name FAIL rc=$rc -- REGRESSED since 2026-09-04 reclassification, needs a fresh row"
        fail=1
    fi
done

for pair in $RED_LINKED; do
    name="${pair%%:*}"; topic="${pair#*:}"
    tf="$PO/tasks/$topic.task.md"
    if [ -f "$tf" ] && grep -qi "$name" "$tf"; then
        echo "RESIDUE_SIX: $name RED, linked and tracked at $topic"
    else
        echo "RESIDUE_SIX: $name RED but NOT properly linked (expected $tf to mention '$name')"; fail=1
    fi
done

echo "RESIDUE_SIX_BOARD fail=$fail"
exit "$fail"

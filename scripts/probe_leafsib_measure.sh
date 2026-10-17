#!/usr/bin/env bash
# probe_leafsib_measure.sh - s131 SIBLING WIDENING instrument (GOAL-SNOBOL4-100 R-0 leaf class).
# Runs the leafsib suite in BOTH media against the checked-in .ref oracle output, under BOTH
# killswitch arms.  A sibling is RED iff its stdout differs from its .ref (a SEGV, an abort, a hang
# and a silent wrong answer all count the same - the .ref is the only truth).  No pipelines around
# the compiler: rc is captured directly so a 139 is never laundered into a 0 by `head`.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIBS="${SIBS:-span tab rtab rem arb bal break breakx arb_flat_red arb_flat_grn bal_flat_red bal_flat_grn}"   # the eight one-per-member siblings, plus the s193 PADDED pairs.  ⛔ RE-MEASURED 2026-08-29 (seat08, pristine, both arms): ALL TWELVE ARE NOW INERT AT HEAD -- the s193 claim that the padded pairs still discriminate the arms (arb_flat_red/bal_flat_red diverging to m4 rc=139 under SCRIP_SPAN_FRAME=0) no longer reproduces; both arms measure 12/12 pass both modes. Not root-caused here (out of this row's lane -- corpus format, not frame codegen); see tests/snobol4/probe/leafsib.README.md's 2026-08-29 section and FINDING-2026-08-29-seat08-leafsib-span-frame-arm-fully-inert.md.
# ⭐ RE-POINTED 2026-08-29 (seat08, corpus-crosscheck-probe-total-conversion clause 3): corpus/probe/leafsib/
# is gone -- converted to corpus/tests/snobol4/probe/leafsib.{sno,ref} (corpus-suites-consolidation format,
# byte-equal-validated both directions, both modes, BOTH killswitch arms before the loose files were deleted).
# Same idiom as test_gate_fz_release.sh's re-point: extract every entry via corpus_suite_harness.py (the ONE
# parsing authority) into a scratch dir, then use that exactly as the old loose-file P -- the per-sibling loop
# below, its env-var-arm sensitivity, and its output format are all byte-for-byte unchanged.
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
# ⭐ RE-POINTED 2026-08-30 (seat12, repo-wide dead-suite-path consumer sweep): leafsib.{sno,ref}
# (itself a 2026-08-29 re-point) was absorbed into THE ONE FLAT RUNGS and deleted;
# lib_rungs_extract.sh materializes the "probe_leafsib" family back into leafsib_<sib>.sno/.ref --
# origins strip to exactly that naming, so the SIBS loop below is unchanged.
RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$HERE/lib_rungs_extract.sh"
P="$WORK/leafsib_src"; mkdir -p "$P"
rungs_extract_family probe_leafsib "$P" 2>/dev/null
[ -n "$(ls -A "$P" 2>/dev/null)" ] || { echo "⛔ REFUSED-TO-GRADE no $P (suite missing or extraction failed)"; exit 2; }
cd "$(dirname "$0")/../../SCRIP" || exit 1
case "${SCRIP_SPAN_FRAME-}" in 0) ARM=0;; *) ARM=1;; esac   # ⛔ COMPUTED, NEVER TYPED: this must mirror sn4_span_frame() (emit.cpp) EXACTLY -- `(e && *e == '0') ? 0 : 1`, i.e. UNSET IS ON.  It read `${SCRIP_SPAN_FRAME:-0}` from s131 until s193 and so labelled every default-arm run `=0` after the s188 flip (d3251f23) made unset mean ON: the instrument printed the OFF label over ON-arm numbers for five sessions.
printf '=== leafsib  SCRIP_SPAN_FRAME=%s ===\n' "$ARM"
printf '%-14s | %-22s | %-22s\n' "sib" "m3 (--run BINARY)" "m4 (--compile TEXT)"
printf -- '---------------|------------------------|------------------------\n'
pass3=0; pass4=0; tot=0
for f in $SIBS; do
    src="$P/leafsib_$f.sno"; ref="$P/leafsib_$f.ref"
    [ -f "$src" ] || continue
    tot=$((tot+1))
    timeout -k 5 20 ./scrip --run "$src" < /dev/null > /tmp/ls_m3.out 2>/dev/null; r3=$?
    d3="FAIL"; if [ $r3 -eq 0 ] && cmp -s /tmp/ls_m3.out "$ref"; then d3="pass"; pass3=$((pass3+1)); fi
    rm -f /tmp/ls_bin /tmp/ls.s
    timeout -k 5 90 ./scrip --compile "$src" < /dev/null > /tmp/ls.s 2>/dev/null; rc=$?
    d4="FAIL"; r4="c$rc"
    if [ $rc -eq 0 ] && [ -s /tmp/ls.s ]; then
        if gcc -no-pie -o /tmp/ls_bin /tmp/ls.s out/libscrip_rt.so > /dev/null 2>&1; then
            timeout -k 5 20 /tmp/ls_bin < /dev/null > /tmp/ls_m4.out 2>/dev/null; r4=$?
            if [ "$r4" -eq 0 ] && cmp -s /tmp/ls_m4.out "$ref"; then d4="pass"; pass4=$((pass4+1)); fi
        else r4="gcc"; fi
    fi
    printf '%-14s | rc=%-4s %-14s | rc=%-4s %-14s\n' "$f" "$r3" "$d3" "$r4" "$d4"
done
printf -- '---------------|------------------------|------------------------\n'
printf '%-14s | m3 %d/%d%-17s | m4 %d/%d\n' "TOTAL" "$pass3" "$tot" "" "$pass4" "$tot"

#!/usr/bin/env bash
# test_icn_n2_host_reserved_agrees.sh -- N-2 item 3: THE HOST-RESERVED AGREEMENT invariant (hq_P 2026-08-28).
#
# THE CLAIM UNDER TEST:  icn_gen_host_reserve_offset() answers (off>=0, base>=0) for exactly the host kinds
# icn_gen_host_reserved() says reserve, and REFUSES (-1/-1) for the rest.  icn_gen_host_reserve() is called from
# BOTH non-zframe arms of the three-arm prologue chain -- if (zframe_graph) :2829 (never reserves) / else if
# (icn_genframe2() && flat_gen) :2832 (icon-n2-flat-gen-host-transitive-reserve) / else if (flat_lcl_proc) :2845
# (step 2b) -- so a graph taking the FIRST arm reserves nothing; the other two both do.
#
# ⛔ WHY THIS IS A GATE.  Before the s282 cure the scan was HOST-KIND-BLIND and returned a plausible `off=0 base=128`
# for a flat_gen host that had never carved anything: MEASURED on suspend_nested's inner(), and on a two-caller
# witness the SAME generator answered `off=0 base=128` from its flat_gen host and `off=128 base=240` from its
# flat_lcl_proc host. Zero is the most dangerous answer available -- indistinguishable from a correct first-slot
# answer -- so a step-3 consumer would carve into a region that was never reserved and corrupt the host frame three
# layers from the edit.
# ⛔ AND THE PREDICATE MIRRORS AN else-if CHAIN IN ANOTHER TRANSLATION UNIT WITH NO COMPILER CHECK THAT IT STILL DOES.
# That is precisely what rots silently: add a fourth arm, or move either reserve call, and the predicate is wrong
# with nothing to say so. This gate is that missing check.
#
# ⛔ CONTRACT HISTORY.
#   1. hq_P s282: BOTH host kinds ANSWER (the original, unconditional shape, before the region-resident redesign).
#   2. ceo s283, 2026-08-29: 06d4852f's flat_gen-arm stack reserve is superseded by the region-resident alpha (a
#      flat_gen host carves nothing on the stack under that design, so answering would hand out a base into storage
#      that does not exist) -- contract NARROWED to flat_lcl_proc-only-answers, flat_gen REFUSES, until the
#      transitive reserve lands.
#   3. seat06, 2026-08-29, row icon-n2-flat-gen-host-transitive-reserve: contract RESTORED to BOTH-KINDS-ANSWER --
#      icn_gen_host_reserve() is now recursive (reserve(g) = SUM(align16(ft_callee)+48+reserve(callee))) and a
#      flat_gen host's region IS big enough for its own generator callees, carved by ITS OWN caller under the SAME
#      recursive formula. base is now HOST-KIND-AWARE (icn_gen_host_reserve_offset): RSP-relative for flat_lcl_proc
#      (unchanged), RBP-relative (rbp=H, constant 48 past the host's own header, no pad/L7 depth tracking) for
#      flat_gen. This is state 1's contract again, reached by a different, load-bearing mechanism, not a reversion.
# THREE STATES:  rc=0 invariant holds  |  rc=1 violated  |  rc=2 could not measure (never skip-as-success)
set -u
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd); root=$(cd "$here/../../SCRIP" && pwd); cd "$root" || exit 2
scrip="$root/scrip"
[ -x "$scrip" ] || { echo "⛔ REFUSE: no ./scrip at $scrip -- cannot measure"; exit 2; }
tmp=$(mktemp -d) || exit 2; trap 'rm -rf "$tmp"' EXIT
# ⭐ THE WITNESS SET IS FIXED AND SELF-CONTAINED, and it MUST contain both host kinds: a flat_lcl_proc host (main
# calling a generator) and a flat_gen host (a generator calling a generator).  mixed_caller is the load-bearing one --
# ONE generator reached from BOTH host kinds, which is what proves the answer is keyed on the HOST and not the callee.
printf '%s\n' 'procedure gen()'  '   suspend 1;' 'end' 'procedure main()' '   write(gen());' 'end' > "$tmp/single.icn"
printf '%s\n' 'procedure inner()' '   suspend 1 | 2;' 'end' 'procedure outer()' '   suspend inner();' 'end' 'procedure main()' '   every write(outer());' 'end' > "$tmp/nested.icn"
printf '%s\n' 'procedure leaf()' '   suspend 1 | 2;' 'end' 'procedure mid()' '   suspend leaf();' 'end' 'procedure main()' '   every write(leaf());' '   every write(mid());' 'end' > "$tmp/mixed.icn"
: > "$tmp/all.log"
for w in single nested mixed; do
    SCRIP_ICN_GENFRAME2=1 SEAT01_N2_STEP3_DBG=1 timeout -k 5 30s "$scrip" --compile --out="$tmp/$w.s" "$tmp/$w.icn" </dev/null 2>>"$tmp/all.log" >/dev/null
done
grep -a 'N2-STEP3-DBG' "$tmp/all.log" > "$tmp/dbg.txt" 2>/dev/null
sites=$(wc -l < "$tmp/dbg.txt")
[ "$sites" -gt 0 ] || { echo "⛔ REFUSE: zero generator call sites observed -- the diagnostic did not fire, so nothing was measured (an empty denominator is not a pass)"; exit 2; }
# ⛔ BOTH CLASSES MUST BE PRESENT.  A run that saw only one host kind cannot have exercised both arithmetic paths
# (RSP-relative base vs RBP-relative base) at all, and would pass while one of them was entirely untested.
lclp=$(awk '/host_flat_lcl_proc=1/' "$tmp/dbg.txt" | wc -l)
genh=$(awk '/host_flat_lcl_proc=0/' "$tmp/dbg.txt" | wc -l)
[ "$lclp" -gt 0 ] || { echo "⛔ REFUSE: no flat_lcl_proc host observed -- cannot test the RSP-relative base path"; exit 2; }
[ "$genh" -gt 0 ] || { echo "⛔ REFUSE: no flat_gen host observed -- cannot test the RBP-relative base path, which is this row's whole point"; exit 2; }
bad=0
while read -r line; do
    lcl=$(sed -n 's/.*host_flat_lcl_proc=\([0-9-]*\).*/\1/p' <<<"$line")
    off=$(sed -n 's/.*off=\([0-9-]*\).*/\1/p' <<<"$line")
    bse=$(sed -n 's/.*base=\([0-9-]*\).*/\1/p' <<<"$line")
    # BOTH-KINDS-ANSWER (contract state 3): every registered-generator call site observed here comes from a host that
    # actually reserves (flat_lcl_proc OR flat_gen; a zframe host would never reach this template's N-2 branch at
    # all, so lcl is only ever 0 or 1 in this witness set) -- so every line must answer, never refuse.
    if [ "$off" = -1 ] || [ "$bse" = -1 ]; then echo "⛔ FAIL: host (flat_lcl_proc=$lcl) REFUSED off=$off base=$bse (must answer under BOTH-KINDS-ANSWER): $line"; bad=$((bad+1)); fi
    if [ "$lcl" = 0 ] && [ "$bse" != 48 ]; then echo "⛔ FAIL: flat_gen host answered base=$bse, expected the CONSTANT 48 (rbp+48, past its own header) every time: $line"; bad=$((bad+1)); fi
done < "$tmp/dbg.txt"
echo "=== N-2 HOST-RESERVED AGREEMENT GATE: sites=$sites flat_lcl_proc=$lclp flat_gen=$genh violations=$bad ==="
[ "$bad" -eq 0 ] || { echo "⛔ FAIL: $bad site(s) disagree with icn_gen_host_reserved()"; exit 1; }
echo "✅ PASS: every host (either kind) answers; flat_gen bases are the constant 48"
exit 0

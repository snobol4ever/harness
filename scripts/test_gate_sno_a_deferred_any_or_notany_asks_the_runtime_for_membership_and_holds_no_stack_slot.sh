#!/usr/bin/env bash
# test_gate_sno_a_deferred_any_or_notany_asks_the_runtime_for_membership_and_holds_no_stack_slot.sh
#
# THE DEFECT (row snobol4-mode-4-crashes-on-a-deferred-any-after-a-break-or-span-was-built): mode 4 died of SIGSEGV in
# rt_pat_prim_str_take on a match with a deferred ANY (or NOTANY) argument once the program had built a BREAK or SPAN pattern
# anywhere before it -- X = BREAK('a') then ('abc' ? ANY(*Z)) faulted where mode 3 and sbl -bf answer 'b'.
# THE CAUSE (measured in the m4 emission): the deferred ANY/NOTANY box handed the take its out-pointers at LFDQ/LFD slots it
# does not own -- ANY and NOTANY are not leaf-frame members (zdp_scratch_cell lists SPAN, BREAK, BREAKX, TAB, RTAB, REM) and
# their drive case assigns neither x86_scratch_off nor op_leaf_frame_off, so the address was [rbp + 16] with no BREAK before
# it (a write above the frame base that worked by luck) and [rsp + 520192] after one (a stale offset). Giving them BREAKX's
# 16-byte transient instead was tried and withdrawn: a deferred call that raises (an undefined function) then crashes, exactly
# as a deferred BREAKX does today on the same input (its own row).
# THE CURE: the deferred ANY/NOTANY box holds no stack memory at all. After the prim glue evaluates the argument into
# g_prim_val (a collector root), bb_glue_prim_member computes the subject character (or -1 at the end) and one runtime call,
# rt_pat_prim_member(ch, codes), coerces the value with the box's code pair (raising 43/49 as before) and answers 1 member,
# 0 not, 2 end of subject, -1 raised or failed: ANY succeeds on 1, NOTANY on 0. No raw pointer or length is ever on the stack.
#
# One program, every answer cut from sbl -bf at run time and pinned: a pinned line sbl no longer prints is a REFUSAL, never a
# green.  Both modes.  rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
[ -x "$SBL" ] || refuse "the SNOBOL4 oracle $SBL is absent -- the pinned lines cannot be confirmed"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/m.sno" <<'SNO'
        X = BREAK('a')
        Y = SPAN('a')
        Z = 'b'
        OUTPUT = ('abc' ? ANY(*Z)) ' deferred any'
        OUTPUT = ('abc' ? BREAK(*Z)) ' deferred break'
        OUTPUT = ('abc' ? NOTANY(*'a')) ' deferred notany'
        'abc' ? BREAK('a')
        OUTPUT = ('xbz' ? ANY(*Z) . W) '|' W
        V = 'q'
        OUTPUT = ('abc' ? ANY(*V)) ' no member'                 :S(E)
        OUTPUT = 'any failed'
E       OUTPUT = ('' ? NOTANY(*'a')) ' empty'                   :S(F)
        OUTPUT = 'notany failed at end'
F       'ab' ? ANY(*U())
        OUTPUT = 'after undefined'
END
SNO
printf '%s\n' 'b deferred any' 'a deferred break' 'b deferred notany' 'b|b' 'any failed' 'notany failed at end' 'after undefined' > "$D/m.want"
( cd "$D" && timeout -k 5 10 "$SBL" -bf m.sno < /dev/null 2>/dev/null | grep -v '^$' > m.sbl )
cmp -s "$D/m.want" "$D/m.sbl" || refuse "sbl -bf does not answer m as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/m.sbl")]"
red=0; n=0
( cd "$D" && timeout -k 5 30 "$B/scrip" m.sno < /dev/null > m.m3 2>/dev/null )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile m.sno < /dev/null > m.s 2>/dev/null && gcc -no-pie m.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o m.bin 2>/dev/null \
    && timeout -k 5 30 ./m.bin < /dev/null > m.m4 2>/dev/null )
for m in m3 m4; do
    n=$((n + 1))
    if [ -f "$D/m.$m" ] && cmp -s "$D/m.want" "$D/m.$m"; then echo "  ok   m $m"
    else echo "  FAIL m $m: got [$(tr '\n' '|' 2>/dev/null < "$D/m.$m")] want [$(tr '\n' '|' < "$D/m.want")]"; red=$((red + 1)); fi
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): a deferred ANY or NOTANY asks the runtime for membership and holds no stack slot -- after a BREAK or SPAN, at the end, past an undefined function -- both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1

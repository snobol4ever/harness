#!/usr/bin/env bash
# test_gate_gc_the_scan_enter_poll_never_roots_an_unestablished_subject_base.sh -- THE ONE POLL FORM THE SCAN
# SPINE MUST NOT USE, AND THE PREMISE THAT MAKES IT WRONG, BOTH MEASURED OFF THE EMISSION (cto 2026-09-22,
# MODE DECTET, chunk A sub-batch 4 of the standing chop; CEO-1133 ruling ONE keeps chunk A on rec_sigma).
#
# THE FINDING.  Chunk A's baton names x86_rt_gc_poll_rec_sigma_needle() as the candidate form for the two
# rt_scan_enter sites in bb_gen_scan.cpp, on the reasoning that rt_scan_enter returns ScanSubjRegs {ptr,len}
# in rax:rdx and so mirrors rt_scan_needle, whose site uses exactly that form.  THE RETURN SHAPE MATCHES AND
# THE SITE DOES NOT.  rec_sigma_needle's cell 0 is {DT_S, r15d, r13} -- it roots r13 as a string pointer --
# and rt_scan_enter IS THE CALL THAT ESTABLISHES r13.  At the OUTERMOST scan of a program r13 has never been
# written: the emitted prologue zeroes r14d (and esi) and never touches r13 or r15, so r13 holds whatever the
# C caller of main left in a callee-saved register.  Rooting it hands the collector a word that is not a
# pointer and asks it to forward it.  The value is not garbage in the harmless sense either -- it is a live
# machine word from libc's startup, so it is neither NULL (which a visitor could skip) nor a heap address
# (which would merely be wrong); it is whatever survives, and the failure would be silent, arbitrary, and in
# the outermost scan of every Icon program that scans.
# ⭐ THE CURE IS x86_rt_gc_poll_rec_subject_new(), the one-cell form {DT_S, edx, rax} with keep_rdx: it roots
# the NEW subject that rt_scan_enter just returned -- which is the only live heap pointer at that point, and
# freshly allocated when the argument needed conversion -- and leaves r13 alone.  keep_rdx is a raw save and
# restore, sound HERE because rdx is the subject LENGTH, an integer, and the site consumes it two
# instructions later at `mov r15, rdx`.  The same raw keep over a POINTER comes back stale and roots nothing.
#
# ⛔ WHY A GATE AND NOT A SENTENCE IN THE BATON.  The claim spans two files that no reader opens together --
# the prologue in xa_prologue/bb_glue (where r13 is NOT initialised) and bb_gen_scan.cpp (where a form that
# roots r13 would be legal, compile clean, and pass every arm) -- so RULES.md's INSTRUMENT LAWS require a
# check rather than memory.  It also has a real expiry: if a future landing establishes r13 in the prologue,
# the premise dies and rooting it becomes sound.  ARM (a) grades the PREMISE, so that landing turns this gate
# red and forces the reasoning to be re-read instead of leaving a stale prohibition in force forever.
#
# ⭐ RE-DERIVED 2026-10-15 (hq_icon; the premise died exactly as this paragraph predicted, at SCRIP d76ca4ead, "a mode-4 program starts with the
# empty scan subject"): the mode-4 entry now writes r13 once, lea r13, [rip + .Lscan_nil] (one rodata byte), and zeroes r15d before any scan,
# because tab, move, many and any outside a scan read the registers. At the outermost scan r13 is therefore a VALID string pointer (non-heap,
# like every literal) and the length is 0 -- no longer the C caller's residue -- so a rec_sigma-shaped root there would no longer hand the collector a
# non-pointer. The form is KEPT, for the reason that is still true: rt_scan_enter returns the NEW subject in rax:rdx, the only pointer the site must
# keep, and x86_rt_gc_poll_rec_subject_new() roots exactly it; arm (b) holds the site to that form. Arm (a) now grades the NEW premise (the nil
# subject is established once before the first scan), with its control inside the arm, so a landing that drops the nil subject turns it red and
# re-opens this question for the registers tab and move read.
#
# ⛔ THIS GATE READS THE EMITTED ASM, NOT THE TEMPLATE SOURCE (RULES.md ASM-DIFF-FIRST).  A source-shape check
# on bb_gen_scan.cpp would pass for a form reached through a helper, an alias or a second call site, and the
# census cannot see a FORM at all -- it counts polled against unpolled and reads the same number either way.
S4E_HOME="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIP="$S4E_HOME/SCRIP"
cd "$SCRIP" || { echo "REFUSE(2): no SCRIP tree at $SCRIP"; exit 2; }
[ -x ./scrip ] || { echo "REFUSE(2): ./scrip is not built -- this gate grades emitted asm and cannot invent it"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/g.icn" <<'ICN'
procedure main()
   local s, t, c;
   s := "abc" || "defgh";
   c := 'abc';
   t := (s ? tab(4));
   write(t);
   write((s ? (t ? tab(3))));
   write((s ? many(c)));
end
ICN
./scrip --compile "$W/g.icn" > "$W/g.s" 2>"$W/g.err" || { echo "REFUSE(2): mode 4 emission failed"; sed -n '1,5p' "$W/g.err"; exit 2; }
grep -q 'call *rt_scan_enter' "$W/g.s" || { echo "REFUSE(2): the witness emitted no rt_scan_enter -- this gate would grade an absence"; exit 2; }
fail=0; arms=0
# ---------------------------------------------------------------------------------------------------------
# (a) THE PREMISE, RE-DERIVED AT SCRIP d76ca4ead (2026-10-15): the emitted entry ESTABLISHES the scan registers before any scan runs -- exactly one
# write to r13, lea r13, [rip + .Lscan_nil] (the empty subject, one rodata byte), and xor r15d, r15d -- so at the outermost scan r13 is a valid string
# pointer and the length is 0, no longer the C caller's residue. The control is in the arm: the SAME reader aimed at the emission with that lea deleted
# must report the premise gone, so a pass is a reading and not a reader that cannot fail (CEO-1680: the trip is in the instrument, never in src/).
arms=$((arms+1))
first_enter=$(grep -n 'call *rt_scan_enter' "$W/g.s" | head -1 | cut -d: -f1)
est_nil() {
    local f="$1" fe w l x
    fe=$(grep -n 'call *rt_scan_enter' "$f" | head -1 | cut -d: -f1); [ -n "$fe" ] || return 2
    sed -n "1,${fe}p" "$f" > "$W/pre.s"
    w=$(grep -cE '^[^#]*\b(mov|xor|lea|pop|add|sub|and|or)\b[^;#]*\br13\b *,' "$W/pre.s")
    l=$(grep -cE '^ *lea +r13, \[rip \+ \.Lscan_nil\]' "$W/pre.s")
    x=$(grep -cE '^ *xor +r15d, r15d' "$W/pre.s")
    [ "$w" = 1 ] && [ "$l" = 1 ] && [ "$x" -ge 1 ]
}
grep -vE '^ *lea +r13, \[rip \+ \.Lscan_nil\]' "$W/g.s" > "$W/g_noinit.s"
est_nil "$W/g.s"; held=$?
est_nil "$W/g_noinit.s"; ctl=$?
if [ "$held" = 0 ] && [ "$ctl" != 0 ]; then
    echo "  ok   (a) PREMISE HOLDS (re-derived at d76ca4ead): the $first_enter line(s) before the first rt_scan_enter write r13 once, lea r13, [rip + .Lscan_nil], with r15d zeroed, so at the outermost scan r13 is a valid pointer to the empty subject and not the C caller's residue; CONTROL: with that lea deleted the same reader reports the premise gone"
elif [ "$held" != 0 ]; then
    echo "  FAIL (a) ⛔ THE PREMISE HAS CHANGED AGAIN: the entry no longer establishes the empty scan subject once (lea r13, [rip + .Lscan_nil] and xor r15d, r15d) before the first rt_scan_enter, so at the outermost scan r13 is the C caller's residue and tab, move, many and any outside a scan read it. Restore the nil subject in the mode-4 entry (src/driver/scrip.c), or re-derive this gate's premise -- do not simply relax this arm"
    fail=$((fail+1))
else
    echo "  FAIL (a) ⛔ THE CONTROL DID NOT TRIP: the same reader still reports the nil-subject premise on an emission with the lea deleted, so arm (a)'s pass proves nothing -- its pattern no longer matches the entry's shape"
    fail=$((fail+1))
fi
# ---------------------------------------------------------------------------------------------------------
# (b) THE INVARIANT: no poll that follows rt_scan_enter may write r13 into a poll cell.
arms=$((arms+1))
bad=0; sites=0
while IFS=: read -r ln _; do
    sites=$((sites+1))
    win=$(sed -n "$((ln+1)),$((ln+34))p" "$W/g.s" | sed -n '1,/test *rax, *rax/p')
    printf '%s\n' "$win" | grep -qE 'rt_gc_point_arr_c|rt_gc_poll' || continue
    if printf '%s\n' "$win" | grep -qE 'qword ptr \[rsp \+ [0-9]+\], r13'; then bad=$((bad+1)); fi
done < <(grep -n 'call *rt_scan_enter' "$W/g.s")
if [ "$bad" = 0 ]; then
    echo "  ok   (b) $sites rt_scan_enter site(s) emitted: no poll between the call and its result test writes r13 into a poll cell, so every site roots the NEW subject rt_scan_enter returned and none roots the outer r13 (the form kept after the premise of arm (a) was re-derived)"
else
    echo "  FAIL (b) ⛔ $bad of $sites rt_scan_enter site(s) SPILL r13 INTO A POLL CELL. That form roots the OUTER subject base, which rt_scan_enter is about to replace -- the NEW subject it returned in rax:rdx is the pointer this site must keep, and a rec_sigma-shaped root keeps the old one instead. Use x86_rt_gc_poll_rec_subject_new() ({DT_S, edx, rax} with keep_rdx), never a rec_sigma-shaped form, at a call that ESTABLISHES the subject"
    fail=$((fail+1))
fi
# ---------------------------------------------------------------------------------------------------------
# (c) THE CURE IS PRESENT: the sites are polled at all, so (b) is not passing by absence.
arms=$((arms+1))
polled=0
while IFS=: read -r ln _; do
    win=$(sed -n "$((ln+1)),$((ln+34))p" "$W/g.s" | sed -n '1,/test *rax, *rax/p')
    printf '%s\n' "$win" | grep -qE 'rt_gc_point_arr_c|rt_gc_poll' && polled=$((polled+1))
done < <(grep -n 'call *rt_scan_enter' "$W/g.s")
if [ "$polled" -gt 0 ]; then
    echo "  ok   (c) $polled of $sites emitted rt_scan_enter site(s) carry a poll, so arm (b) graded a form that exists rather than reporting clean over an unpolled site"
else
    echo "  FAIL (c) ⛔ NO emitted rt_scan_enter site carries a poll, so arm (b)'s clean is VACUOUS -- it cannot distinguish the right form from no form at all. An instrument that reports success while doing nothing is the failure the INSTRUMENT LAWS exist to catch"
    fail=$((fail+1))
fi
# ---------------------------------------------------------------------------------------------------------
# (d) ANSWER ARM: the witness still agrees with the icont oracle, at a collection count of zero and under stress.
arms=$((arms+1))
ORACLE="${ICONT:-/home/resources/icon-build/bin/icont}"
if [ -x "$ORACLE" ]; then
    ( cd "$W" && "$ORACLE" -s g.icn -x >ref.txt 2>&1 )
    z=$(SCRIP_HEAP_MB=512 timeout -k 5 60 ./scrip "$W/g.icn" 2>/dev/null)
    t=$(SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=3 timeout -k 5 60 ./scrip "$W/g.icn" 2>/dev/null)
    r=$(cat "$W/ref.txt")
    if [ "$z" = "$r" ] && [ "$t" = "$r" ]; then
        echo "  ok   (d) the witness answers its icont oracle identically at a 512 MB arena (the zero-collection arm, CEO-1137) and at a 64 KB arena under stress 3 with forced relocation"
    else
        echo "  FAIL (d) ⛔ the witness DIFFERS from its icont oracle -- zero-collection arm $([ "$z" = "$r" ] && echo agrees || echo DIFFERS), stress arm $([ "$t" = "$r" ] && echo agrees || echo DIFFERS). CEO-1137: an arm that differs where collections are ZERO is an EMISSION defect and the collector is innocent"
        fail=$((fail+1))
    fi
else
    echo "  ok   (d) SKIPPED: no icont at $ORACLE, so this arm graded nothing and says so rather than passing"
fi
# ---------------------------------------------------------------------------------------------------------
# (e) POSITIVE CONTROL: the SAME detector, aimed at the one site where rooting r13 IS correct, must FIND it.
# Arm (b) reports an absence, and an absence is worth nothing from a reader that cannot report a presence.
# rt_scan_needle is the mirror site -- it takes a needle INSIDE an established scan, so its cell 0 {DT_S,
# r15d, r13} is right there and wrong at rt_scan_enter, which is the whole distinction this gate holds. The
# witness reaches it only with a VARIABLE needle; a literal cset is folded and never calls rt_scan_needle,
# so `c := 'abc'` in the witness is load-bearing and not decoration.
arms=$((arms+1))
nsites=$(grep -c 'call *rt_scan_needle' "$W/g.s")
nfound=0
while IFS=: read -r ln _; do
    win=$(sed -n "$((ln+1)),$((ln+34))p" "$W/g.s")
    printf '%s\n' "$win" | grep -qE 'qword ptr \[rsp \+ [0-9]+\], r13' && nfound=$((nfound+1))
done < <(grep -n 'call *rt_scan_needle' "$W/g.s")
if [ "${nsites:-0}" -gt 0 ] && [ "$nfound" = "$nsites" ]; then
    echo "  ok   (e) POSITIVE CONTROL HOLDS: the same detector finds r13 spilled into a poll cell at $nfound of $nsites rt_scan_needle site(s), where that form is CORRECT -- so arm (b)'s zero is a zero from looking, not from a reader that cannot see"
elif [ "${nsites:-0}" = 0 ]; then
    echo "  FAIL (e) ⛔ THE WITNESS EMITTED NO rt_scan_needle SITE, so this gate has no positive control and arm (b) is an unchecked absence. A literal cset does not reach rt_scan_needle -- restore the VARIABLE needle (c := 'abc'; many(c)) to the witness"
    fail=$((fail+1))
else
    echo "  FAIL (e) ⛔ THE DETECTOR FOUND r13 AT ONLY $nfound OF $nsites rt_scan_needle SITE(S). Either the mirror site stopped rooting the subject base -- which would be a real defect at that site, not here -- or this gate's reader no longer matches the emitted spill shape and arm (b) has been passing blind"
    fail=$((fail+1))
fi
echo "population: $arms arm(s) graded, $fail FAIL; $sites rt_scan_enter site(s) in the emitted witness"
if [ "$fail" = 0 ]; then echo "✅ GATE GREEN [gc_the_scan_enter_poll_never_roots_an_unestablished_subject_base]"; exit 0; fi
echo "⛔ GATE RED [gc_the_scan_enter_poll_never_roots_an_unestablished_subject_base]: $fail of $arms arms FAIL"; exit 1

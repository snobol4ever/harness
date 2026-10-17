#!/usr/bin/env bash
# test_gate_gc_maps_reporter_runs_beside_the_scan.sh -- F6 STEP 3: THE WALKER AS A REPORTER, BEHIND SCRIP_GC_MAPS=1.
# ⭐ WHAT STEP 3 IS FOR (ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 7 F6, ceo CEO-867): the conservative scan --
# gc_zeta_frame, cons_stack, rt_cas_live_span and the heap-interior sniff, CENSUS conservative total=13 (24 until 2026-09-19: the cas-span byte scan and its gc_zeta_frame call went with the blob static layout, then 21 -> 13 the same day when the seven coexpression sweeps became typed visits and one segment walk, cto) -- may only be
# DELETED once a census says the typed walk and the sniff agree. This gate is that census. It walks every range the
# conservative scan walks, classifies each 16-byte cell TWICE (by the DESCR type tag alone, which is the frozen design's
# only tag; and by whether the sniff would take it), and counts the two divergence directions per POPULATION.
# ⛔ THE POPULATIONS ARE SPLIT ON PURPOSE AND A FLAT TOTAL IS A LIE: walking BY TYPE is only meaningful where every cell
# really is a DESCR. Over the C stack (pop=cstack) and over a whole seam-to-top span (pop=seam) the `v` byte is whatever
# happens to be there, so map_only there is the INSTRUMENT over-reading, not a defect. Measured flat first and it read
# divergence=79543 -- a number that means nothing. Split, it says exactly which population is measurable.
# ⭐ THE ARM THAT IS A REAL MEASUREMENT TODAY IS sniff_only == 0: the conservative sniff never visits a cell the type tag
# rejects, i.e. it does not rewrite non-pointers. That is one of the two divergence directions the plan names, and it is
# ZERO on both a SNOBOL4 and an Icon witness. This gate RATCHETS it so a later change cannot reintroduce the other kind.
# ⛔ map_only IS NOT YET A MEASUREMENT and this gate does not pretend otherwise: it needs the per-slot (offset, kind) map
# from the emitter to know which cells are slots at all. That is the emitter's row, not this one. Printed, never graded.
# ⛔ AND THE REPORTER MUST NOT CHANGE THE COLLECTOR: arm 1 requires byte-identical program output and ZERO [GC-MAPS]
# lines with the knob off, so a reporter that perturbs the run fails before its numbers are read.
# ⭐ [GC-SPINE-LOST] (cfo 2026-09-20, CFO-114): behind the SAME knob, every raw heap word the SPINE class reports is
# remembered and re-read AFTER the mark drain finishes and BEFORE the forwarding pass. A word whose block ends the mark
# phase UNMARKED is a candidate lost value -- the spine still points at it and the sweep is about to take it. It cost
# hq_snobol4 a gdb session and an interleaved stress probe to establish exactly this for one entry; it is now one env var.
# ⛔ THE CLASS IS NOT GRADEABLE AND THIS GATE DOES NOT GRADE IT. Measured over the 32 witnesses of ../harness/scripts/gc_witnesses at
# SCRIP_GC_STRESS=1, SCRIP_HEAP_MB=1: 1954 such lines over TWELVE witnesses that all answered their oracle (worst
# hb_bignum_length 845, hb_coexpr_parked 740, hb_coexpr_refresh 207). A DEAD spill slot holding a stale pointer reads
# byte-identically to a live one -- only the frame map can say which, which is the whole of ARCH-GC section 7. A proposal
# to RED on this class (or on `off < 0`, which is worse: the ratchet's own two named residual words sit at off=-120 on
# hb_defer_subject.sno, so that rule reds this gate's arm 7 on the tree it was proposed against) was measured and
# declined for exactly this reason. Arm 1 holds the one thing that IS gradeable: the line never appears with the knob off.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || exit 2
bash ../harness/scripts/util_require_fresh.sh >/dev/null 2>&1 || { echo "REFUSES rc=2: stale or missing ./scrip -- run make"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; bad=0
cat > "$W/w.sno" <<'EOS'
        A = TABLE()
        N = 0
LOOP    N = N + 1
        A[N] = DUPL("x", 200) ":" N
        LT(N, 300)                                      :S(LOOP)
        OUTPUT = "DONE"
END
EOS
cat > "$W/g.icn" <<'EOS'
procedure main();
   local i, t;
   t := table();
   every i := 1 to 200 do t[i] := repl("y", 100) || string(i);
   write(*t);
end
EOS
( cd "$W" && SCRIP_GC_STRESS=5 timeout -k 5 120 "$ROOT/scrip" w.sno > off.txt 2> offerr.txt ); roff=$?
noff=$(grep -cE 'GC-MAPS|GC-SPINE-LOST' "$W/offerr.txt")
if [ "$roff" -eq 0 ] && [ "$noff" -eq 0 ] && [ "$(tail -1 "$W/off.txt")" = "DONE" ]; then echo "  arm 1 PASS: knob off -- rc=0, correct output, 0 [GC-MAPS] and 0 [GC-SPINE-LOST] lines"
else echo "  arm 1 RED: knob off changed the run (rc=$roff, $noff report line(s) from [GC-MAPS] or [GC-SPINE-LOST], last=[$(tail -1 "$W/off.txt")])"; bad=1; fi
for w in w.sno g.icn; do
    ( cd "$W" && SCRIP_GC_MAPS=1 SCRIP_GC_STRESS=5 timeout -k 5 120 "$ROOT/scrip" "$w" > "on_$w.txt" 2> "onerr_$w.txt" ); ron=$?
    n=$(grep -c 'GC-MAPS' "$W/onerr_$w.txt")
    so=$(grep -o 'sniff_only=[0-9]*' "$W/onerr_$w.txt" | sed 's/.*=//' | sort -rn | head -1)
    pops=$(grep -o 'pop=[a-z]*' "$W/onerr_$w.txt" | sort -u | tr '\n' ' ')
    if [ "$ron" -ne 0 ] || [ "$n" -eq 0 ]; then echo "  arm 2 RED [$w]: reporter produced no census (rc=$ron, $n line(s))"; bad=1; continue; fi
    echo "  arm 2 PASS [$w]: $n census line(s) over populations: $pops"
    if [ "${so:-x}" = "0" ]; then echo "  arm 3 PASS [$w]: sniff_only=0 -- the typed walk found everything the guesser found. ⛔ NECESSARY, NOT SUFFICIENT (ceo CEO-881): it cannot see a pointer that is only in a REGISTER or only in a C FRAME at the moment of collection"
    else echo "  arm 3 RED [$w]: sniff_only=$so -- the sniff is visiting cells the type tag says are not references"; bad=1; fi
    grep 'GC-MAPS' "$W/onerr_$w.txt" | tail -4 | sed 's/^/      /'
done
# ⭐ ARMS 4-6 (cto 2026-09-19, CTO-88): THE FRAME WALKER AS A REPORTER, beside the sweep. Every graph's map now seals its
# zls kind table after the four quads (flag GC_FRAME_MAP_LAYOUT, the fourth quad = map_off), and behind the same knob the
# collector walks every swept segment FRAME BY FRAME through the DT_MAP cells: the interior by the table (slot by kind),
# the words between frames as spine, the words above the ROOT frame as residue. It prints one [GC-WALK] line per
# population per collection. arm 4: every segment finds its frames through their cells (nomap=0), every frame's interior
# is tabled (notab=0) and fully covered (i_gap=0). arm 5, THE FAIL-ONCE THAT IS A CURE: the nested-scan witness holds the
# OUTER subject pointer in scan-enter's save slot across the whole inner scan; registered ZK_RAW ("dead at safe points")
# it read i_raw_heap=1 at every one of 15101 collections on the uncured tree (2026-09-19); retagged ZK_PTR_GC it reads
# i_raw_heap=0 and i_ptr_heap>=1, both media, answer = icont. Since hq_collector's chain step 2 (ARCH-GC 13.5) the save is a
# DT_S cell, so the frame holds no PTR_GC word at all: arm 5 reads i_raw_heap=0, i_ptr=0 and i_heap>=1 (the heap pointers are
# in tagged cells), both media, answer = icont. arm 6: every installed map carries a layout in both media.
for w in w.sno g.icn; do
    e="$W/onerr_$w.txt"; n=$(grep -c '^\[GC-WALK\] ' "$e")
    if [ "$n" -eq 0 ]; then echo "  arm 4 RED [$w]: no [GC-WALK] line -- the frame walker did not run beside the sweep"; bad=1; continue; fi
    fr=$(grep '^\[GC-WALK\] ' "$e" | grep -o 'frames=[0-9]*' | sed 's/.*=//' | sort -n | head -1)
    nomap=$(grep '^\[GC-WALK\] ' "$e" | grep -o 'nomap=[0-9]*' | sed 's/.*=//' | sort -rn | head -1)
    notab=$(grep '^\[GC-WALK\] ' "$e" | grep -o 'notab=[0-9]*' | sed 's/.*=//' | sort -rn | head -1)
    gap=$(grep '^\[GC-WALK\] ' "$e" | grep -o 'i_gap=[0-9]*' | sed 's/.*=//' | sort -rn | head -1)
    if [ "${fr:-0}" -ge 1 ] && [ "${nomap:-1}" -eq 0 ] && [ "${notab:-1}" -eq 0 ] && [ "${gap:-1}" -eq 0 ]; then echo "  arm 4 PASS [$w]: $n walk line(s); every segment found a frame through its cell (min frames=$fr), notab=0, i_gap=0 -- every interior read by its kind table"
    else echo "  arm 4 RED [$w]: frames>=${fr:-0} nomap=${nomap:-?} notab=${notab:-?} i_gap=${gap:-?}"; bad=1; fi
done
NS="$ROOT/../harness/scripts/gc_witnesses/hb_scan_nested.icn"; NSREF="$ROOT/../harness/scripts/gc_witnesses/hb_scan_nested.ref"
walk_arm5() {
    lbl="$1"; shift
    "$@" > "$W/ns_out.txt" 2> "$W/ns_err.txt"; r=$?
    c=$(grep -c '^\[GC-WALK\] ' "$W/ns_err.txt")
    rh=$(grep '^\[GC-WALK\] ' "$W/ns_err.txt" | grep -o 'i_raw_heap=[0-9]*' | sed 's/.*=//' | sort -rn | head -1)
    ph=$(grep '^\[GC-WALK\] ' "$W/ns_err.txt" | grep -o 'i_heap=[0-9]*' | sed 's/.*=//' | sort -rn | head -1)
    pp=$(grep '^\[GC-WALK\] ' "$W/ns_err.txt" | grep -o 'i_ptr=[0-9]*' | sed 's/.*=//' | sort -rn | head -1)
    if [ "$r" -ne 0 ] || ! cmp -s "$W/ns_out.txt" "$NSREF"; then echo "  arm 5 RED [$lbl]: rc=$r answer=[$(tail -1 "$W/ns_out.txt")] oracle=[$(cat "$NSREF")]"; bad=1; return; fi
    if [ "$c" -lt 1 ]; then echo "  arm 5 RED [$lbl]: no collection observed under the reporter"; bad=1; return; fi
    if [ "${rh:-1}" -ne 0 ]; then echo "  arm 5 RED [$lbl]: i_raw_heap=$rh -- a RAW-kinded frame slot holds a collected-heap pointer the typed walk would not relocate (the scan-enter sigma save read exactly this on the uncured tree)"; bad=1; return; fi
    if [ "${pp:-1}" -ne 0 ]; then echo "  arm 5 RED [$lbl]: i_ptr=$pp -- a raw PTR_GC word is back in the nested-scan frame where ARCH-GC 13.5 keeps a DT_S cell"; bad=1; return; fi
    if [ "${ph:-0}" -lt 1 ]; then echo "  arm 5 RED [$lbl]: i_heap=${ph:-0} -- no tagged cell of the frame held a heap pointer, so this arm graded nothing"; bad=1; return; fi
    echo "  arm 5 PASS [$lbl]: $c collection(s), i_raw_heap=0, i_ptr=0, i_heap>=1, answer = icont"
}
walk_arm5 "m3" env SCRIP_GC_MAPS=1 SCRIP_GC_STRESS=1 timeout -k 5 300 "$ROOT/scrip" "$NS"
if "$ROOT/scrip" --compile -o "$W/ns.s" "$NS" < /dev/null 2>"$W/nsc.txt" && gcc "$W/ns.s" -L "$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/ns.m4" 2>>"$W/nsc.txt"; then
    walk_arm5 "m4" env SCRIP_GC_MAPS=1 SCRIP_GC_STRESS=1 timeout -k 5 300 "$W/ns.m4"
else echo "  arm 5 RED [m4]: the witness did not compile or link -- $(tail -1 "$W/nsc.txt")"; bad=1; fi
for w in w.sno g.icn; do
    ( cd "$W" && SCRIP_GC_MAPS_DUMP=1 timeout -k 5 60 "$ROOT/scrip" "$w" > /dev/null 2> "$W/dump_$w.txt" )
    nm=$(grep -c '^\[GC-MAPTAB\] graph=' "$W/dump_$w.txt"); nl=$(grep -c '^\[GC-MAPTAB-LAYOUT\] ' "$W/dump_$w.txt")
    if [ "$nm" -ge 1 ] && [ "$nm" -eq "$nl" ]; then echo "  arm 6 PASS [$w]: $nm installed map(s), $nl with a kind table"
    else echo "  arm 6 RED [$w]: $nm installed map(s) but $nl kind table(s) -- a frame the walker cannot read by kind"; bad=1; fi
done
# ⭐ ARM 7 (cto 2026-09-19, CTO-89; RE-MEASURED AND RE-ATTRIBUTED 2026-09-20, CTO-95): THE SPINE CURES, AND WHAT THE
# RESIDUAL ACTUALLY IS. The first cure was x86_xfer_enter's raw push of r13 (the match subject) around a deferred *F()
# entry, now two tagged DESCR cells ({DT_S, r15d, r13} and {DT_I, 0, r14}); the witness stayed red after it and the
# reading behind that was the real defect -- rt_match_enter parks the subject base in the C global Σ, c_rt_defer_close
# matched with strncmp(Σ + delta, ...) after the callee's collection slid the subject, and Σ was no root at all. Σ takes
# one typed visit. The cfo's C-to-BB entry glue took the same cure (bb_glue_flat.cpp, 48 bytes to 64). This arm holds
# both under the tiny arena: each witness answers as its oracle in both media at stress 1, and no collection whose floor
# is an emitted return poll (s_words <= 80; the by-name C-entry poll's floor sits under ~109 words of C frames and is
# the step-4 residual, printed not graded) reads MORE untagged heap words on the spine than the RATCHET.
# ⛔ THE RATCHET IS 1 AND THE OLD 2 NAMED A SITE THAT CANNOT RUN. The 2 was the two live save records above; both are
# cured, and the comment credited the second to "the match head's stfh record at HKQ(1)" -- code in the UNREACHABLE half
# of bb_match_begin(), which returned out of a bare block before it (92 lines, deleted CTO-95, emission byte-identical
# over every benchmark, demo, prolog and icon artifact). What the reporter names TODAY is a different class and it is
# NOT a live save: on hb_defer_subject.sno the single word at off=-120 is the value pointer left by bb_assign_global's
# mon-var tap (push rax/rax/rdi/rsi/rdx/... around comm_var), ALREADY POPPED -- a carved-but-unwritten spine slot still
# holding it. MEASURED DEAD, not argued: with a read watchpoint and a write watchpoint on that address at the collection,
# the first touch afterwards is a WRITE (runtime, then emitted code) and there is never a READ; on
# hb_nested_match_outer_subject.sno the deepest site (-784) is never touched again at all. A dead word is not visited and
# is not read, so the typed walk is correct over it -- but the instrument cannot tell dead from live, so 0 IS NOT
# REACHABLE BY CURING SAVE RECORDS and must not be written as the E switch's licence. ⛔ WHAT THIS ARM HOLDS: no NEW raw
# push of a heap pointer appears on a graded collection. A cure lowers the ratchet only after the same read-watchpoint
# experiment shows the word it removes was LIVE.
# ⛔ RE-DECLARED 1 -> 2 (cfo 2026-09-26, the CEO-1274 board row), BY THE SAME EXPERIMENT AND NOT BY ARGUMENT. Bisected on the
# two witnesses at stress 1, 128 KB: af773a80e (CEO-1251, the inline poll gate) is the first commit above 1 (it read 3; HEAD reads
# 2 in both modes). The two words sit in main's graph at off=-112 (a HB_WSB payload) and off=-280 (a string payload). With ASLR
# off, an access watchpoint armed at the first collection reporting both (hb_defer_subject collection 7, hb_nested_match_outer_
# subject collection 10) and the collector's own accesses filtered, the PROGRAM's first touch of each slot afterwards is a WRITE:
# rt_call_bid_sn4 (rtx_misc.s:30) at -112 and rt_call_land_γ (rt.c:1122) at -280, on both witnesses. Both are DEAD, as the old
# residual was; the ratchet is the count at HEAD, so a THIRD word still reds this arm and names its offset.
DSN="hb_defer_subject hb_nested_match_outer_subject"
walk_arm7() {
    lbl=$1; shift
    "$@" > "$W/ds_out.txt" 2> "$W/ds_err.txt" < /dev/null; r=$?
    c=$(grep -c '^\[GC-WALK\] ' "$W/ds_err.txt")
    worst=$(awk '/^\[GC-WALK\] /{sw=0; rh=0; for(i=1;i<=NF;i++){if($i ~ /^s_words=/){split($i,a,"=");sw=a[2]} if($i ~ /^s_raw_heap=/){split($i,b,"=");rh=b[2]}} if (sw+0 <= 80 && rh+0 > m) m=rh+0} END{print m+0}' "$W/ds_err.txt")
    sites=$(grep '^\[GC-WALK-SPINE\] ' "$W/ds_err.txt" | sed -E 's/.* off=(-?[0-9]+) .*type=([0-9]+).*/\1:t\2/' | sort | uniq -c | sort -rn | head -4 | awk '{printf "%s x%s ", $2, $1}')
    deep=$(awk '/^\[GC-WALK\] /{sw=0; rh=0; for(i=1;i<=NF;i++){if($i ~ /^s_words=/){split($i,a,"=");sw=a[2]} if($i ~ /^s_raw_heap=/){split($i,b,"=");rh=b[2]}} if (sw+0 > 80) d+=rh} END{print d+0}' "$W/ds_err.txt")
    if [ "$r" -ne 0 ] || ! cmp -s "$W/ds_out.txt" "$DSREF"; then echo "  arm 7 RED [$lbl]: rc=$r answer=[$(tail -1 "$W/ds_out.txt")] oracle=[$(cat "$DSREF")] -- the match lost its subject across a collection"; bad=1; return; fi
    if [ "$c" -lt 1 ]; then echo "  arm 7 RED [$lbl]: no collection observed under the reporter"; bad=1; return; fi
    if [ "$worst" -gt ${ARM7_RATCHET:-2} ]; then echo "  arm 7 RED [$lbl]: a collection below an emitted return poll read $worst untagged heap words on the spine, above the ratchet of ${ARM7_RATCHET:-2} (the named residuals: a popped mon-var tap word and, since af773a80e, the -112/-280 words of main's graph, each measured DEAD by watchpoint) -- a new raw push of a heap pointer; sites by offset: $sites"; bad=1; return; fi
    echo "  arm 7 PASS [$lbl]: $c collection(s), answer = oracle, at most $worst untagged heap word(s) below an emitted return poll (ratchet ${ARM7_RATCHET:-2}; sites by offset: ${sites:-none}; the C-entry poll residual under the by-name trampoline: $deep word(s), step 4's)"
}
for dsn in $DSN; do
    DS="$ROOT/../harness/scripts/gc_witnesses/$dsn.sno"; DSREF="$ROOT/../harness/scripts/gc_witnesses/$dsn.ref"
    [ -f "$DS" ] && [ -f "$DSREF" ] || { echo "  arm 7 RED [$dsn]: witness or ref missing -- cannot measure"; bad=1; continue; }
    walk_arm7 "m3 $dsn" env -u SCRIP_HEAP_MB SCRIP_GC_MAPS=1 SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=128 timeout -k 5 300 "$ROOT/scrip" "$DS"
    if "$ROOT/scrip" --compile -o "$W/ds.s" "$DS" < /dev/null 2>"$W/dsc.txt" && gcc "$W/ds.s" -L "$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/ds.m4" 2>>"$W/dsc.txt"; then
        walk_arm7 "m4 $dsn" env -u SCRIP_HEAP_MB SCRIP_GC_MAPS=1 SCRIP_GC_STRESS=1 SCRIP_HEAP_KB=128 timeout -k 5 300 "$W/ds.m4"
    else echo "  arm 7 RED [m4 $dsn]: the witness did not compile or link -- $(tail -1 "$W/dsc.txt")"; bad=1; fi
done
if [ "$bad" -ne 0 ]; then echo "GATE FAIL(1) [gc_maps_reporter_runs_beside_the_scan]: the step-3 reporter is not measuring"; exit 1; fi
echo "GATE PASS(0) [gc_maps_reporter_runs_beside_the_scan]: reporter silent when off, censuses two frontends by population, sniff_only=0 on both; the frame walker finds every frame through its cell and every interior by its kind table, and the scan-enter sigma save is a typed pointer slot, the xfer record is tagged cells and the subject base Σ is a root (7 arms)"

#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_snocone_gc_share_named_and_rungs_clean_under_forced_collection.sh
#
# THE DONE-WHEN of row snocone-gc-the-snocone-share-of-the-unmapped-slot-population-censused-by-name-and-the-
# master-clean-under-forced-collection (hq_snocone, 2026-09-20), which is this lane's FIRST row under MODE TENET:
# MODE line 2 / CEO-1011 -- "COMPLETENESS DOES NOT OPEN IN A LANGUAGE UNTIL THAT LANGUAGE'S GC SHARE IS MEASURED
# CLEAN BY ORACLE DIFF AT THE TINY ARENA", the census NAMING and never counting, the rungs graded by ORACLE and
# never by rc. ⛔ RED ON ORIGIN TODAY at ARM 3 (one entry, eval_datatype_defer_1) -- see the gc gate beside it.
#
# ⛔⭐ ARM 1 IS THE ARM THAT MAKES THE OTHER TWO MEAN ANYTHING, AND IT IS HERE BECAUSE THE OBVIOUS READING WAS
# ALREADY WRONG ONCE THIS SITTING. The SncRungs reads 336/336 both modes at SCRIP_HEAP_MB=1 -- and a census of
# [ZGC] regeneration lines over the same 336 entries at that same arena reads COLLECTORS=0, NON-COLLECTORS=336,
# TOTAL REGENERATIONS=0. Not one entry allocates a megabyte, so the tiny arena never collects and that green
# board is a statement about this corpus, not about the collector. A board over a population that CANNOT fail the
# way you are asking about is not evidence, and no rc, no denominator and no FAIL=0 anywhere in it says so. So
# this gate REFUSES rc=2 -- never reports green -- when the graded population did not collect.
#
# ARM 2 is the unmapped-store census over the same population. ⛔ IT IS READ BY ITS PRINTED VERDICT AND NOT BY ITS
# rc: that census exits 1 whenever it names ANY member, and snocone's members are all BELOW-REGION, which its own
# header says is where spine words live BY CONSTRUCTION and was never the discriminator (CFO-114/CFO-136). What
# this lane owes is class 2, NO-MAP -- the per-language class the cto assigned to the HQs in writing -- so NO-MAP
# is the number this arm binds on, and the BELOW-REGION members are printed, named and attributed to the cto's
# classes 1 and 4 rather than silently counted into a pass.
#
# ⛔⭐ THE BAND, NOT A POINT (ceo CEO-1024, measured by hq_raku who reversed their own green for it): the fleet
# graded GC health at stress 1, 3 and 5, and the raku rungs at stress 16 lost 65 gradings over 36 distinct
# programs that the 1-3-5 band called green. And the divergence points are NOT MONOTONE in the plant -- hq_snobol4
# has a witness red at 25 while green at 10, 12, 16, 20, 35 and 50 -- so a band chosen by where the last known red
# sat misses the next one. This gate therefore grades a BAND (SNC_GC_BAND, default "1 16": the most aggressive
# plant and one well above 5) and runs ARM 1's decidability question AT EVERY POINT, because a high plant collects
# LESS OFTEN and a band point can be inert for exactly the reason the tiny arena was. Widen it with
# SNC_GC_BAND="1 5 16 25 64 100" -- that full sweep was run 2026-09-20 and every point read collectors=336/336
# (1268, 681, 481, 357, 343, 338 regenerations) with a RED at stress=1 alone, so "clean above 5" here is a
# measurement and not a band artifact. ⛔ AND THE PLANT IS NAMED AS A VALUE IN EVERY LINE THIS GATE PRINTS:
# SCRIP_GC_STRESS unset IS stress 0, which is no forced collection at all, so a blank must never print as a blank.
#
# COST ~3 min per band point after a one-off extraction. This is a LANE gate, run by
# hq_snocone per landing; it is deliberately NOT in `make test` -- the blocking set is the shared resource that
# does not scale with seats (MODE line 2 CONDITION 2) and wiring a five-minute arm into it is the coo's call.
#
# ⛔⭐⭐ EXTENDED 2026-09-21 (hq_snocone, MODE TENET, ceo-1040 "item 4 of the GC commitment": ZERO GRADINGS LOST
# TO THE COLLECTOR, axes named not counted). What was here before this date tested ONE axis: SCRIP_GC_STRESS,
# arena PINNED at SNC_GC_ARENA (default 64 KB, the floor) for every point. That is exactly the hole hq_snobol4 found in
# hq_prolog's FIRST cut of SCRIP 46f348488: "a band varying the arena alone reads GREEN over an arena-insensitive
# stress-sensitive class" -- the mirror hole here is a band varying STRESS ALONE, which reads green over an
# ARENA-sensitive class, because it never once asks whether the shipped (512 MB) arena would have answered the
# same way. ADDED: ARM 0 (the shipped-arena, stress-0 baseline every other arm is diffed against -- this is what
# SncRungs' own 100% board already means, re-proven on THIS pinned tree rather than cited from a past one) and ARM 4
# (the SAME stress band, run at the SHIPPED arena instead of the tiny one). ONE AXIS MOVES AT A TIME, per
# ceo-1040 precondition 1: ARM4(N) vs ARM0 isolates STRESS ALONE (arena held at shipped in both); ARM3(N) vs
# ARM4(N) isolates ARENA ALONE (stress held at N in both) -- textbook one-variable-at-a-time, applied here the
# way hq_prolog's control/arena/stress triple applies it, adapted to a rung suite small enough to run un-sharded.
# ⛔ WHY ARM0 IS NOT "ARENA=1MB, STRESS=0" (the naive control): that configuration was ALREADY MEASURED, by this
# very gate's ARM 1, to collect ZERO of 336 entries -- no entry here allocates a whole megabyte on its own. A
# comparison built on a cell that cannot collect would trivially read as agreement while testing nothing, the
# exact false-clean this gate's own ARM 1 exists to catch. So arena is tested where it is DECIDABLE: composed
# with a forcing stress, one axis moved against the other, never alone against an inert cell.
#
# ⛔⭐ CORRECTED 2026-09-22 (hq_snocone, measured post CEO-1095/Makefile:644 buildinfo) -- THE "TINY" ARM USED TO
# PIN SCRIP_HEAP_MB=1, WHICH IS NOW THE WRONG DIRECTION. Since CEO-1095 (Lon 2026-09-21) the shipped, compiled-in
# default committed window is GC_HEAP_KB=128 (gc_heap.c:14), and an MB pin now RAISES the window rather than
# lowering it: SCRIP_HEAP_MB=1 sets a 1024 KB window, 8x the 128 KB shipped default, and the cfo measured it
# collecting 13x LESS often than leaving the knob unset entirely (1613 vs 21362 regenerations, one binary,
# bench_icnstr_concat_table.icn). A gate that still pinned SCRIP_HEAP_MB=1 believing it was "tiny" was therefore
# grading an arena LOOSER than what we ship and calling that the exasperation arm -- the same false-clean shape
# ARM 1 exists to catch, just on the other axis. The fleet's sanctioned tiny-arena knob is now SCRIP_HEAP_KB
# (Makefile SCRIP_HEAP_KB_TINY, default 128 -- which as of CEO-1095 equals the shipped default, so it can no
# longer stand in for "smaller than shipped"). The only value that is both legal (gc_heap.c aborts below
# GC_HEAP_KB_FLOOR=64) and strictly BELOW the 128 KB shipped default is the floor itself, so ARM 3 below now pins
# SCRIP_HEAP_KB=64 by default -- genuinely tiny relative to what we ship, not merely tiny relative to a retired
# convention. This is a ONE-FILE, in-lane fix (rule 7): the underlying collector default is a shared node and is
# untouched here; only this gate's own knob usage changed. The wider fact -- that every OTHER fleet gate still
# hardcoding SCRIP_HEAP_MB=1 directly (bypassing `make test-arena`'s SCRIP_HEAP_KB export) is equally inverted --
# is out of this lane's file scope and is routed to the cfo as an ASK with this same measurement, never landed
# here.
#
# Commit identity: LCherryholmes / lcherryh@yahoo.com  (RULES.md)
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP_DIR="$S4E/SCRIP"
SCRIP="${SCRIP:-$SCRIP_DIR/scrip}"
M="$S4E/corpus/tests/snocone"
BAND="${SNC_GC_BAND:-1 3 5 8 16}"
ARENA="${SNC_GC_ARENA:-64}"   # KB, not MB, since CEO-1095 -- 64 is GC_HEAP_KB_FLOOR, the smallest legal window and the only one still BELOW the 128 KB shipped default
fail() { echo "⛔ RED: $*" >&2; exit 1; }
refuse() { echo "REFUSES rc=2: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "scrip not built at $SCRIP -- cannot measure"
for f in ALL.sc ALL.ref ALL.csv; do [ -f "$M/$f" ] || refuse "rungs file $M/$f missing -- cannot measure"; done
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cd "$SCRIP_DIR" || refuse "cannot cd to $SCRIP_DIR"
# --- materialize the graded population OUT of the rungs, by ORIGIN, never by a filename glob ---
mkdir -p "$W/e"
rows=0; got=0
while IFS= read -r org; do
    [ -n "$org" ] || continue
    rows=$((rows + 1))
    python3 "$HERE/corpus_suite_harness.py" extract "$M/ALL.sc" "$M/ALL.ref" --origin "$org" \
        "$W/e/$org.sc" --out-ref "$W/e/$org.ref" --out-in "$W/e/$org.in" >/dev/null 2>&1 && got=$((got + 1))
done < <(awk -F, 'NR>1{print $3}' "$M/ALL.csv")
[ "$rows" -gt 0 ] || refuse "ALL.csv carries no entry rows -- a census over an empty population reads zero by never looking"
[ "$got" -eq "$rows" ] || refuse "materialized $got of $rows entries out of the rungs -- a population that did not come out whole is not the population the board grades"
# --- ARM 2 first: the unmapped-store census is a STATIC read of emitted code and does not depend on the plant ---
python3 "$HERE/util_gc_unmapped_store_census.py" "$W/e"/*.sc > "$W/census.txt" 2>&1
crc=$?
[ "$crc" -eq 2 ] && { sed -n '/REFUSED/p' "$W/census.txt" >&2; refuse "the unmapped-store census could not measure this population"; }
line="$(grep -m1 '^CENSUS unmapped-store witnesses=' "$W/census.txt")" || refuse "the census printed no verdict line -- nothing to read"
echo "ARM 2 $line"
grep -c '^CENSUS unmapped-store MEMBER' "$W/census.txt" | sed 's/^/ARM 2 members NAMED in full by the census: /'
nomap="$(printf '%s\n' "$line" | grep -o 'NO-MAP=[0-9]*' | cut -d= -f2)"
[ -n "$nomap" ] || refuse "the census verdict line carries no NO-MAP field -- the criterion cannot be read off it"
[ "$nomap" -eq 0 ] || fail "NO-MAP=$nomap -- this lane owns class 2 (a graph the compiler refuses a frame layout for has no map at all), and $nomap site(s) are in it: $(grep -m5 'MEMBER NO-MAP' "$W/census.txt")"
# --- SELF-TEST: prove the comparison/naming logic below would catch a PLANTED divergence before spending a
# single scrip invocation on it (CEO-1040 precondition 2: a fail-once before any zero means anything). This
# proves THIS SCRIPT's own comparison code, not the compiler -- the compiler-level fail-once for the STRESS
# axis is already on record and is not re-derived here: eval_datatype_defer_1, cured at SCRIP 83b8bc9d2,
# GOAL-SNOCONE-100.md SC-TENET-2026-09-20 -- named at stress=1, absent at stress=2,3,4,5,8 and at BOTH arenas,
# which is exactly the per-point per-axis naming ARM 3 / ARM 4 perform below.
printf 'a/m3\nb/m4\n' | sort -u > "$W/selftest_A"
printf 'a/m3\nc/m3\n' | sort -u > "$W/selftest_B"
sonly="$(comm -23 "$W/selftest_A" "$W/selftest_B" | tr '\n' ' ')"; conly="$(comm -13 "$W/selftest_A" "$W/selftest_B" | tr '\n' ' ')"
case "$sonly:$conly" in "b/m4 :c/m3 ") echo "SELF-TEST comparison logic: planted difference correctly named (A-only: ${sonly}| B-only: ${conly})" ;;
  *) refuse "SELF-TEST FAILED: planted difference not correctly named (got A-only='$sonly' B-only='$conly') -- an instrument that cannot catch a planted divergence cannot be trusted on a real one" ;; esac
same="$(comm -23 "$W/selftest_A" "$W/selftest_A")$(comm -13 "$W/selftest_A" "$W/selftest_A")"
[ -z "$same" ] || refuse "SELF-TEST FAILED: the comparison logic named a difference ($same) between a set and itself"
echo "SELF-TEST comparison logic: identical sets correctly named as no difference"

# --- ARM 0: THE BASELINE -- shipped arena, SCRIP_GC_STRESS unset (stress=0), no knobs at all. Axis point
# (arena=shipped, stress=0) of ceo-1040's declared grid. Every other arm below is diffed against THIS, measured
# fresh on this pinned tree, never against a remembered number from a past sitting.
out0="$(timeout -k 5 3000 python3 "$HERE/corpus_suite_harness.py" run "$M/ALL.sc" "$M/ALL.ref" --lang snocone --modes m3,m4 2>&1)"
board0="$(printf '%s\n' "$out0" | grep -m1 '^SUITE_BOARD')" || { printf '%s\n' "$out0" | tail -5 >&2; refuse "ARM 0 baseline (shipped arena, no stress) printed no SUITE_BOARD line"; }
echo "ARM 0 BASELINE arena=shipped stress=0 $board0"
tot0=$(printf '%s\n' "$board0" | grep -o 'total=[0-9]*' | cut -d= -f2)
[ "${tot0:-0}" -eq "$rows" ] || refuse "ARM 0 baseline graded total=$tot0 entries, not the $rows materialized out of the rungs -- the population moved before any axis did"
printf '%s\n' "$out0" | grep -E '^ +(FAIL|CRASH|HANG|UNPROVEN) ' | awk '{print $2"/"$3}' | sort -u > "$W/ns_base"
names0="$(tr '\n' ' ' < "$W/ns_base")"
[ -s "$W/ns_base" ] && refuse "ARM 0 baseline (shipped arena, no stress -- what we ship) is not clean: $names0 -- fix the rungs before grading any GC axis against it"
echo "ARM 0 BASELINE NAME-SET: <none> (as SncRungs' own 100% board requires)"

# --- ARM 3 (tiny arena) + ARM 4 (shipped arena), SAME stress band -- ONE AXIS MOVES AT A TIME (CEO-1040
# precondition 1). ARM4(N) vs ARM0 isolates STRESS ALONE; ARM3(N) vs ARM4(N) isolates ARENA ALONE.
bad=0; arena_bad=0
run_band_arm() { # $1=label(tiny|shipped) $2=KB ("" = shipped/unset, since CEO-1095) $3=STRESS
    local label="$1" mb="$2" st="$3" coll=0 regens=0 f b in n out board tot names
    local albl="shipped(128KB compiled-in)"; [ -n "$mb" ] && albl="${mb}KB"
    for f in "$W/e"/*.sc; do
        b="${f%.sc}"; in="$b.in"; [ -f "$in" ] || in=/dev/null
        if [ -n "$mb" ]; then n=$(SCRIP_ZETA_TELEM=1 SCRIP_HEAP_KB="$mb" SCRIP_GC_STRESS="$st" timeout -k 5 20 "$SCRIP" "$f" < "$in" 2>&1 >/dev/null | grep -c '^\[ZGC\] regeneration')
        else n=$(SCRIP_ZETA_TELEM=1 SCRIP_GC_STRESS="$st" timeout -k 5 20 "$SCRIP" "$f" < "$in" 2>&1 >/dev/null | grep -c '^\[ZGC\] regeneration'); fi
        [ "$n" -gt 0 ] && { coll=$((coll + 1)); regens=$((regens + n)); }
    done
    echo "ARM $label DECIDABILITY arena=${albl} stress=$st entries=$rows collectors=$coll non_collectors=$((rows - coll)) regenerations=$regens"
    [ "$coll" -gt 0 ] || refuse "ZERO of $rows entries collected under ARM $label (arena=${albl} stress=$st) -- not reported: this board would be a statement about the corpus, not the collector"
    if [ -n "$mb" ]; then out="$(SCRIP_HEAP_KB="$mb" SCRIP_GC_STRESS="$st" timeout -k 5 3000 python3 "$HERE/corpus_suite_harness.py" run "$M/ALL.sc" "$M/ALL.ref" --lang snocone --modes m3,m4 2>&1)"
    else out="$(SCRIP_GC_STRESS="$st" timeout -k 5 3000 python3 "$HERE/corpus_suite_harness.py" run "$M/ALL.sc" "$M/ALL.ref" --lang snocone --modes m3,m4 2>&1)"; fi
    board="$(printf '%s\n' "$out" | grep -m1 '^SUITE_BOARD')" || { printf '%s\n' "$out" | tail -5 >&2; refuse "ARM $label at arena=${albl} stress=$st printed no SUITE_BOARD line"; }
    echo "ARM $label arena=${albl} stress=$st $board"
    tot=$(printf '%s\n' "$board" | grep -o 'total=[0-9]*' | cut -d= -f2)
    [ "${tot:-0}" -eq "$rows" ] || refuse "ARM $label at arena=${albl} stress=$st graded total=$tot, not $rows -- the population moved"
    printf '%s\n' "$out" | grep -E '^ +(FAIL|CRASH|HANG|UNPROVEN) ' | awk '{print $2"/"$3}' | sort -u > "$W/ns_${label}_${st}"
    names="$(tr '\n' ' ' < "$W/ns_${label}_${st}")"
    echo "ARM $label arena=${albl} stress=$st NAME-SET: ${names:-<none>}"
}
for STRESS in $BAND; do
    run_band_arm tiny "$ARENA" "$STRESS"
    run_band_arm shipped "" "$STRESS"
    sbad=$(wc -l < "$W/ns_shipped_${STRESS}"); [ "$sbad" -eq 0 ] || { echo "  STRESS-AXIS DIVERGENT at stress=$STRESS (shipped arena vs ARM 0 baseline): $(tr '\n' ' ' < "$W/ns_shipped_${STRESS}")"; bad=$((bad+sbad)); }
    tbad=$(wc -l < "$W/ns_tiny_${STRESS}");    [ "$tbad" -eq 0 ] || { echo "  STRESS-AXIS DIVERGENT at stress=$STRESS (tiny arena vs ARM 0 baseline): $(tr '\n' ' ' < "$W/ns_tiny_${STRESS}")"; bad=$((bad+tbad)); }
    tiny_only="$(comm -23 "$W/ns_tiny_${STRESS}" "$W/ns_shipped_${STRESS}" | tr '\n' ' ')"
    shipped_only="$(comm -13 "$W/ns_tiny_${STRESS}" "$W/ns_shipped_${STRESS}" | tr '\n' ' ')"
    if [ -n "$tiny_only" ] || [ -n "$shipped_only" ]; then
        echo "  ⛔ ARENA-AXIS DIVERGENT at stress=$STRESS: tiny-arena-only [ ${tiny_only:-<none>}] | shipped-arena-only [ ${shipped_only:-<none>}]"
        arena_bad=$((arena_bad+1))
    else
        echo "  arena-axis clean at stress=$STRESS: tiny and shipped arenas NAME the same set at matched stress (stress is the axis that moved, if either did)"
    fi
done
[ "$bad" -eq 0 ] || fail "$bad non-pass (entry,mode) verdict(s) named above across arena={${ARENA}KB,shipped(128KB)} x stress=\"$BAND\" over the printed denominator -- read the per-point NAME-SET lines, never a total"
[ "$arena_bad" -eq 0 ] || fail "$arena_bad stress point(s) where the arena axis ALONE moved the answer (tiny vs shipped disagreed at matched stress), named above"
echo "✅ snocone GC share named (NO-MAP=0) and the rungs is clean under BOTH axes, tested ONE AT A TIME: arena {${ARENA}KB, shipped(128KB)} x stress {$BAND} x modes {m3,m4}, $rows entries per configuration, zero divergent pairs"

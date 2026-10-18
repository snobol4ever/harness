#!/usr/bin/env bash
# test_gate_gc_the_stack_walk_survives_valgrind.sh -- THE MAIN STACK'S TOP IS THE MAPPING HOLDING __libc_stack_end, NOT
# THE MAPPING LABELLED [stack], SO A COLLECTING RUN SURVIVES VALGRIND (cto 2026-09-24; row gc-the-main-stack-top-is-the-
# mapping-holding-libc-stack-end-not-the-stack-label-so-a-collecting-run-survives-valgrind; hq_icon's finding on origin
# e9066fb8d and hq_prolog's on a mode-4 Prolog hello world; law RULES.md FACT RULE THE COLLECTOR GUESSES NOTHING, CEO-812).
#
# MEASURED 2026-09-24 on SCRIP 47fe713dd: a six-line Icon witness that puts 20000 copies of repl("x", 10) on a list and
# writes its size runs clean natively at the shipped 128 KB window and dies rc=139 under valgrind --tool=none in BOTH
# modes, in gc_walk_cell at the read of a cell's type word, reached from gc_walk_range and the stack-segment walk; a
# mode-4 Prolog hello world dies the same way under memcheck at its start-up collection.  THE CAUSE, MEASURED WITH A C
# PROBE: gc_stack_region took the main thread's stack from the line of /proc/self/maps labelled [stack]; under valgrind
# that line is the HOST's stack (0x7ffd...) while the client's frames live in an unlabelled mapping (0x1ffeffe000-
# 0x1fff001000), so the walk from the mutator's floor to that top crossed unmapped ground.  glibc's __libc_stack_end is
# the client's entry rsp in both settings and the mapping CONTAINING it is the real stack in both (natively it IS the
# [stack] line).  THE CURE (gc_heap.c): gc_stack_region finds the mapping containing __libc_stack_end and falls back to
# the label only when no mapping contains it; gc_stack_top and the parked-main segment inherit it.  The plant
# SCRIP_GC_PLANT_STACK_LABEL=1 restores the label-only read and prints its GC-STACKLABEL banner once, so the loss can be
# seen to return.  WHY IT MATTERS: every seat can callgrind a collecting run at the shipped window instead of at an
# arena big enough never to collect, and a valgrind error count on a SCRIP program measures the program, not this walk.
#
# ARMS: (a) THE PROPERTY: the witness answers its iconx-cut ref under valgrind --tool=none at the shipped 128 KB window
# in mode 3 (the compiler runs under valgrind too) and in mode 4; (b) THE PROLOG ARM: hq_prolog's hello world, mode 4,
# under memcheck exits 0 printing hello with no Invalid read (the walker's tag search over never-written stack words
# inside the real mapping still draws "uninitialised value" reports, which are not this defect and are counted, not
# graded); (c) PLANTED: under SCRIP_GC_PLANT_STACK_LABEL=1 the mode-3 arm fails to answer its ref AND the GC-STACKLABEL
# banner is on stderr -- an instrument never seen to fire is not known to look; (d) SOURCE: gc_heap.c consults
# __libc_stack_end.  FAIL_ONCE=1 runs arm (a) under the plant and requires it to red.  No valgrind is a REFUSAL (2).
#
# ⛔ SINCE SCRIP 5ff24e573 (cfo 2026-09-28) THE MAIN SEGMENT HAS A SECOND DEFENSE, AND THE PLANT HAD STOPPED BITING -- the coo's
# tiny-arena pass on 04b933b81 read arm (c) FAIL rc=0 banner=1.  rt_outer_call now records its entry rsp and gc_seg_next bounds
# the main segment at the ROOT frame, so in mode 3 the planted [stack]-label top is never walked: measured on one binary, the
# plain witness under the plant reads its ref with the ceiling on and dies rc=139 with SCRIP_GC_CEILING=0.  The top is STILL
# load-bearing in two places the ceiling does not cover, and each is now an arm: (c) THE PARKED-MAIN SEGMENT, in the SHIPPED
# configuration -- hb_coexpr_genp_scan.icn runs a generator on its own thread while main is parked, and a collection there walks
# main's parked segment from gc_stack_region's top: under the plant it dies rc=139 at every stress point 1..8 (twice each) and
# reads its ref at every point without it (at stress 0 nothing collects while main is parked, so the arm runs at 1); (c2) THE
# FALLBACK when a recorded ceiling does not resolve, measured by switching the ceiling off (SCRIP_GC_CEILING=0) on the plain
# witness.  FAIL_ONCE switches the ceiling off too, since arm (a) is the plain witness.  The masking itself is REPORTED, never
# graded here: test_gate_gc_the_stack_walk_stops_at_the_outermost_emitted_frame.sh grades the ceiling.  In mode 4 the plant never
# applies (no banner: a compiled program runs on a stack it maps itself and adopts its top), so every plant arm is mode 3.
# RE-CUT AGAIN (hq_collector 2026-10-14, CEO-1680, the seams row): the plant SCRIP_GC_PLANT_STACK_LABEL is DELETED from the runtime -- it restored the label-only read so arm (c) could
# watch the loss return, a seam in SCRIP that existed only so a test could trip. Arm (c) and its note are retired; FAIL_ONCE=1 now grades arm (a) against a corrupted ref. The property's own
# commit-before reading stands in the header above: on 47fe713dd both modes died rc=139 under valgrind. Arms (a), (b) and (d) stand.
# RE-CUT at ARCH-GC section 13 STEP B (hq_collector 2026-10-11): the ceiling (rt_gc_emit_ceiling_adopt, SCRIP_GC_CEILING) is gone with the marker scan; the main segment is
# bounded by the program top recorded at entry (rt_program_top_adopt) and the chain ends at the ROOT frame, so the fallback arm (c2) that switched the ceiling off and the
# SCRIP_GC_CEILING=0 half of the FAIL_ONCE plant are deleted. Arms (a), (b), (c) and (d) stand.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
command -v valgrind >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: valgrind is not installed, the property cannot be measured"; exit 2; }
W="$ROOT/../harness/scripts/gc_witnesses/stack_top_under_valgrind"
[ -s "$W.icn" ] && [ -s "$W.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: witness or .ref missing under gc_witnesses"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; plant=""
REF="$W.ref"; if [ "${FAIL_ONCE:-0}" = 1 ]; then { cat "$W.ref"; echo corrupted-by-fail-once; } > "$T/ref.bad"; REF="$T/ref.bad"; fi
LD="-L$ROOT/out -lscrip_rt -lm -Wl,-rpath,$ROOT/out"
vgrun() { local tag="$1"; shift; ( cd "$T" && env -u SCRIP_HEAP_MB $plant SCRIP_HEAP_KB=128 timeout -k 5 600s valgrind --tool=none -q "$@" > "$tag.out" 2> "$tag.err" ); echo $?; }
r3=$(vgrun m3 "$SCRIP" --run "$W.icn")
if [ "$r3" = 0 ] && cmp -s "$T/m3.out" "$REF"; then echo "  arm (a) mode 3 PASS: rc=0, ref matched under valgrind at 128 KB"; else echo "  arm (a) mode 3 FAIL: rc=$r3 $(cmp -s "$T/m3.out" "$W.ref" && echo ref || echo DIFF) -- the stack walk died or misread under valgrind"; RC=1; fi
if "$SCRIP" --compile "$W.icn" > "$T/w.s" 2>/dev/null && gcc -c "$T/w.s" -o "$T/w.o" 2>/dev/null && gcc "$T/w.o" $LD -o "$T/w4" 2>/dev/null; then
  r4=$(vgrun m4 "$T/w4")
  if [ "$r4" = 0 ] && cmp -s "$T/m4.out" "$REF"; then echo "  arm (a) mode 4 PASS: rc=0, ref matched under valgrind at 128 KB"; else echo "  arm (a) mode 4 FAIL: rc=$r4 $(cmp -s "$T/m4.out" "$W.ref" && echo ref || echo DIFF)"; RC=1; fi
else echo "  arm (a) mode 4 FAIL: the witness did not compile and link"; RC=1; fi
printf ':- initialization(main).\nmain :- write(hello), nl, halt.\n' > "$T/hw.pl"
if "$SCRIP" --compile "$T/hw.pl" > "$T/hw.s" 2>/dev/null && gcc -no-pie "$T/hw.s" $LD -o "$T/hw.bin" 2>/dev/null; then
  ( cd "$T" && env -u SCRIP_HEAP_MB $plant SCRIP_HEAP_KB=128 timeout -k 5 600s valgrind -q ./hw.bin > hw.out 2> hw.err ); rp=$?
  inv=$(grep -c 'Invalid read' "$T/hw.err"); uni=$(grep -c 'uninitialised' "$T/hw.err")
  if [ "$rp" = 0 ] && [ "$(cat "$T/hw.out")" = hello ] && [ "$inv" = 0 ]; then echo "  arm (b) PASS: the mode-4 Prolog hello world exits 0 under memcheck, no Invalid read (uninitialised-value reports: $uni, the walker's tag search, counted not graded)"; else echo "  arm (b) FAIL: rc=$rp out='$(head -c 40 "$T/hw.out")' invalid_reads=$inv"; RC=1; fi
else echo "  arm (b) FAIL: the Prolog hello world did not compile and link"; RC=1; fi
if grep -q '__libc_stack_end' "$ROOT/src/runtime/rt/gc_heap.c"; then echo "  arm (d) PASS: gc_heap.c consults __libc_stack_end"; else echo "  arm (d) FAIL: gc_heap.c no longer consults __libc_stack_end"; RC=1; fi
[ $RC = 0 ] && echo "GATE PASS [$G]: the collector's stack walk stays inside the real stack under valgrind in both modes" || echo "GATE FAIL [$G]: $RC arm(s) red"
exit $RC

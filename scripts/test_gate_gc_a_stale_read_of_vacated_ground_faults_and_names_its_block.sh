#!/usr/bin/env bash
# test_gate_gc_a_stale_read_of_vacated_ground_faults_and_names_its_block.sh -- RUNG 1 OF ARCH-GC § 9, MEASURED.
#
# ⛔⭐ THE ROW (Lon 2026-09-21, in-chat to the ceo, verbatim: "Now you must discover a technique to automatically
# flush out the GC ... We want things like our sync-step IPC monitor which is iron-clad and guaranteed to self
# measure and self correct."; ceo CEO-1027, ARCH-GC § 9 RUNG 1).  SCRIP_GC_POISON has filled every vacated tail
# with 0xDB since long before this row, AND THAT MEMORY STAYED MAPPED READABLE AND WRITABLE: a stale pointer read
# returned a plausible 0xDB byte, the program printed a wrong answer and exited 0.  0xDB appeared exactly once in
# the whole tree, at the memset that wrote it -- a tripwire nothing was ever attached to.  The cure is page
# protection, not a byte pattern: the fully vacated pages go PROT_NONE, so the stale read SIGSEGVs AT THE
# INSTRUCTION THAT USED THE STALE POINTER and the handler names the block that used to live there.
#
# ⛔ WHY A PLANTED C FIXTURE AND NOT A .sno WITNESS, WHICH IS THE HALF OF THIS ROW THAT WOULD HAVE ROTTED.  The row
# was minted naming hb_mkexpr_unmapped_spine_store.sno as its acceptance and calling it "already red".  IT IS
# GREEN -- 13 band points x 2 modes, guarded by a BLOCKING arm of make test since 2026-09-20 -- so an acceptance
# that demanded a fault from it demanded that a blocking gate go red (cfo 2026-09-21, measured before a line was
# written).  A trap's acceptance may never be somebody else's open defect: the day they cure it the arm goes DARK
# and reads as a pass.  So the subject is a fixture this gate owns and plants itself, and its control arm proves
# the fixture really is a stale read rather than a program that tests nothing.
#
# THE ARMS.  (b) is the DARK reading the row exists to convert -- same binary, same program, SCRIP_GC_TRAP=0,
# exit 0 with a plausible answer.  (c) and (d) are the conversion: signal death, and a report that names the
# block, its kind, its size, its arena offset and whether it was MOVED or RECLAIMED.  (e) is the property a trap
# breaks if it is wrong: after the collection the allocator must get its ground back, so a HEALTHY mutator that
# climbs back through the quarantine never faults.  (f) is the honest limit stated in ARCH-GC § 9 and held here
# rather than promised: mprotect granularity is a PAGE, the quarantine is page-aligned, and the sub-page tail
# under the live top keeps 0xDB and does not trap.  (g) is a real program still answering its oracle-cut ref.
# FAIL_ONCE=1 runs the trap arms with the trap OFF and requires (c) and (d) to red.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
ROOT="$PWD"; G="gc_a_stale_read_of_vacated_ground_faults_and_names_its_block"
unset SCRIP_HEAP_MB; export SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-128}"
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
refuse() { echo "⛔ GATE REFUSED(2) [$G]: $1"; exit 2; }
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "no out/libscrip_rt.so -- the fixture links the runtime under test and there is nothing to link"
[ -x "$ROOT/scrip" ] || refuse "no scrip binary -- arm (g) grades a real program and would measure nothing"
command -v gcc >/dev/null 2>&1 || refuse "no gcc -- this gate plants its own fixture and cannot build it"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
TRAPENV=""; [ "${FAIL_ONCE:-0}" = 1 ] && TRAPENV="SCRIP_GC_TRAP=0"
echo "ARENA SCRIP_HEAP_KB=$SCRIP_HEAP_KB (the shipped window -- CEO-931/934; the CEO-1146 sweep moved this off MB=1, which named 1024 KB and ran the collector ZERO times on four of six witnesses. The exasperation knob is SCRIP_GC_STRESS, never the arena -- 33rd batch clause 1)"
cat > "$T/plant.c" <<'PLANTC'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
void *rt_gcheap_alloc(uint16_t type, uint64_t payload_bytes);
long rt_gc_collect(void);
int main(int argc, char **argv)
{
    int mode = argc > 1 ? atoi(argv[1]) : 0, i, n = 3000;
    char *stale = (char *)0, *p;
    for (i = 0; i < n; i++) { p = (char *)rt_gcheap_alloc(205, 64); memset(p, 'A' + (i & 15), 64); if (i == n / 2) stale = p; }
    printf("PLANT allocated %d blocks, stale=%p\n", n, (void *)stale); fflush(stdout);
    printf("PLANT collected reclaimed=%ld\n", rt_gc_collect()); fflush(stdout);
    if (mode == 1) { for (i = 0; i < n; i++) { p = (char *)rt_gcheap_alloc(205, 64); memset(p, 'Z', 64); } printf("PLANT re-allocated %d blocks with no fault\n", n); fflush(stdout); return 0; }
    { volatile char c = stale[0]; printf("PLANT stale read returned 0x%02x\n", (unsigned char)c); fflush(stdout); }
    return 0;
}
PLANTC
gcc -O0 -g -w -o "$T/plant" "$T/plant.c" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread 2>"$T/build.err" || { sed 's/^/    /' "$T/build.err"; refuse "the planted fixture did not build against the runtime under test"; }
env SCRIP_GC_TRAP=0 "$T/plant" 0 >"$T/off.out" 2>&1; off_rc=$?
if [ "$off_rc" = 0 ] && grep -q "PLANT stale read returned" "$T/off.out"; then
  ck ok "(b) CONTROL -- with SCRIP_GC_TRAP=0 the same binary reads vacated ground, prints $(grep -o 'returned 0x..' "$T/off.out") and EXITS 0: the DARK answer this row converts, so the arms below grade a real stale read"
else ck FAIL "(b) CONTROL -- the fixture did not produce a silent stale read with the trap off (rc=$off_rc); every arm below would be measuring a broken fixture"; sed 's/^/    /' "$T/off.out"; fi
env $TRAPENV "$T/plant" 0 >"$T/on.out" 2>&1; on_rc=$?
if [ "$on_rc" -ge 128 ]; then ck ok "(c) THE TRAP TRAPS -- the same stale read now dies by signal (rc=$on_rc, SIGSEGV at the instruction that used the pointer) instead of returning a plausible byte"
else ck FAIL "(c) THE TRAP TRAPS -- the stale read did NOT fault (rc=$on_rc): vacated ground is still readable, so a lost root still prints a wrong answer and exits 0"; fi
if grep -q "ZGC-STALE" "$T/on.out" && grep -q "the block that lived here" "$T/on.out" && grep -qE "RECLAIMED|MOVED" "$T/on.out" && grep -q "QUARANTINED PROT_NONE" "$T/on.out"; then
  ck ok "(d) IT NAMES ITS BLOCK -- $(grep -m1 'the block that lived here' "$T/on.out" | sed 's/^\[ZGC-STALE\]  *//')"
else ck FAIL "(d) IT NAMES ITS BLOCK -- the fault carried no [ZGC-STALE] report naming the block, its kind, its size and its fate; an address alone is the finding a seat spends a sitting deriving"; sed 's/^/    /' "$T/on.out"; fi
env "$T/plant" 1 >"$T/back.out" 2>&1; back_rc=$?
if [ "$back_rc" = 0 ] && grep -q "re-allocated" "$T/back.out"; then ck ok "(e) THE GROUND COMES BACK -- a healthy mutator allocating straight back through the quarantine does not fault (rc=0): the trap protects vacated ground and releases it to the allocator page by page"
else ck FAIL "(e) THE GROUND COMES BACK -- re-allocating over vacated ground faulted or refused (rc=$back_rc); a trap that keeps the heap from the allocator is a regression, not an instrument"; sed 's/^/    /' "$T/back.out"; fi
env SCRIP_ZETA_TELEM=1 "$T/plant" 1 >"$T/tel.out" 2>&1
pg=$(getconf PAGESIZE 2>/dev/null || echo 4096)
qline=$(grep -m1 '\[ZGC-TRAP\] quarantine' "$T/tel.out" || true)
qlo=$(printf '%s' "$qline" | sed -n 's/.*quarantine arena+\([0-9-]*\)\.\..*/\1/p'); qhi=$(printf '%s' "$qline" | sed -n 's/.*\.\.arena+\([0-9-]*\) .*/\1/p')
if [ -n "$qline" ] && [ -n "$qlo" ] && [ -n "$qhi" ] && [ $((qlo % pg)) = 0 ] && [ $((qhi % pg)) = 0 ]; then
  ck ok "(f) THE HONEST LIMIT HOLDS -- the quarantine is page-aligned on both bounds (arena+$qlo..arena+$qhi, page $pg): only FULLY vacated pages trap and the sub-page tail under the live top keeps 0xDB, exactly as ARCH-GC § 9 states"
else ck FAIL "(f) THE HONEST LIMIT HOLDS -- no page-aligned [ZGC-TRAP] quarantine line was printed under SCRIP_ZETA_TELEM=1 (got: ${qline:-none}); an unaligned or absent bound means the instrument cannot say what it does and does not cover"; fi
W="$ROOT/../harness/scripts/gc_witnesses/hb_mkexpr_unmapped_spine_store.sno"; R="$ROOT/../harness/scripts/gc_witnesses/hb_mkexpr_unmapped_spine_store.ref"
if [ -f "$W" ] && [ -f "$R" ]; then
  bad=""; for s in 0 1 3 5 16; do a=$(SCRIP_GC_STRESS=$s timeout -k 5 60s "$ROOT/scrip" "$W" </dev/null 2>&1); [ "$a" = "$(cat "$R")" ] || bad="$bad $s"; done
  if [ -z "$bad" ]; then ck ok "(g) NO REGRESSION ON A HEALTHY PROGRAM -- the unmapped-spine-store witness still answers its oracle-cut ref with the trap ON at stress 0 1 3 5 16"
  else ck FAIL "(g) NO REGRESSION ON A HEALTHY PROGRAM -- the witness stopped answering its ref at stress:$bad with the trap on; a trap that reds a green program is a false positive and outranks the conversion it bought"; fi
else ck FAIL "(g) NO REGRESSION ON A HEALTHY PROGRAM -- the witness or its ref is gone, so nothing graded a real program under the trap"; fi
if grep -qE "test_gate_${G}\.sh" "$ROOT/Makefile"; then ck ok "(h) WIRED -- this gate is named in a Makefile recipe, so it is a measuring gate and not one of the ~220 that no arm reaches"
else ck FAIL "(h) WIRED -- this gate is in ../harness/scripts/ but no Makefile recipe names it: an unwired gate is a green nobody ran (the s268 false-green shape)"; fi
echo "population: $checks arm(s) graded, $fails FAIL; fixture: 3000 blocks, one full collection, one stale read"
if [ "$fails" = 0 ]; then echo "GATE PASS [$G]: $checks of $checks arms hold -- vacated ground traps at the instruction and names the block that lived there"; exit 0; fi
echo "GATE FAIL [$G]: $fails of $checks arms red"; exit 1

#!/usr/bin/env bash
# test_gate_gc_a_fault_names_its_block.sh -- RUNG 2 OF ARCH-GC § 9, MEASURED.
#
# ⛔⭐ THE ROW.  Rung 1 (test_gate_gc_a_stale_read_of_vacated_ground_faults_and_names_its_block.sh) turned a silent
# wrong answer into a located crash: the vacated pages go PROT_NONE and the handler names the ADDRESS.  An address
# is not a defect.  Rung 2 is the BLOCK BIRTH LEDGER -- a side table, never a header field, because rt_hblk_t is
# sixteen bytes and CHANGING THE BLOCK LAYOUT CHANGES THE THING BEING TESTED -- so the fault prints the block's
# allocation serial, its type at birth and the site that allocated it.  ARCH-GC § 9's own example is the contract:
# "block #12345, DT_X, allocated by rt_heap_strdup_c from SNO$MKEXPR".
#
# ⛔ WHY THE SUBJECT IS A FIXTURE THIS GATE PLANTS ITSELF.  A trap's acceptance may never be somebody else's open
# defect: the day they cure it the arm goes DARK and reads as a pass (cfo 2026-09-21, the rung-1 finding).  So the
# subject is a fixture whose birth identity this gate knows INDEPENDENTLY of the runtime -- it counts its own
# allocations -- and arm (b) is the whole point: the fixture allocates 3000 blocks, collects them ALL, then
# allocates 3000 more and goes stale on the 1500th of the SECOND batch.  Its birth serial is 4500 while its
# position in the vacated ledger is 1500, so an instrument that reports the ledger index instead of the serial
# CANNOT pass this arm.  That is not hypothetical: the first cut of this cure reported 1500, because phase B
# re-uses phase A's addresses and the ring lookup returned the older birth.  A one-phase fixture would have
# shipped it -- serial and index coincide there.
#
# ⛔ ARM (d) IS THE INSTRUMENT-MUST-CLAIM-THE-EVENT RULE.  A birth ring is finite.  With a ring too small to hold
# the record, the report must SAY the record is gone and must NEVER name a different block -- naming the wrong
# block is worse than naming none, which is the whole class this rung exists to remove.
#
# FAIL_ONCE=1 runs every naming arm with the ledger OFF and requires (b), (c1..c3) and (d) to red; (a) and (e)
# are the arms that describe the ledger-off world, so they stay green by construction and are not fail-once arms.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
ROOT="$PWD"; G="gc_a_fault_names_its_block"
unset SCRIP_HEAP_MB; export SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-128}"
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
refuse() { echo "⛔ GATE REFUSED(2) [$G]: $1"; exit 2; }
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "no out/libscrip_rt.so -- the fixture links the runtime under test and there is nothing to link"
command -v gcc >/dev/null 2>&1 || refuse "no gcc -- this gate plants its own fixture and cannot build it"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ulimit -c 0 2>/dev/null || true
LEDGER=16384; TINY=8; [ "${FAIL_ONCE:-0}" = 1 ] && { LEDGER=0; TINY=0; }
echo "ARENA SCRIP_HEAP_KB=$SCRIP_HEAP_KB (the shipped window -- CEO-931/934; the CEO-1146 sweep moved this off MB=1, which named 1024 KB and ran the collector ZERO times on four of six witnesses. The exasperation knob is SCRIP_GC_STRESS, never the arena -- 33rd batch clause 1)"
echo "birth ring SCRIP_GC_BIRTH_LEDGER=$LEDGER"
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
    for (i = 0; i < n; i++) { p = (char *)rt_gcheap_alloc(205, 64); memset(p, 'A' + (i & 15), 64); }
    printf("PLANT phase A reclaimed=%ld\n", rt_gc_collect()); fflush(stdout);
    for (i = 0; i < n; i++) { p = (char *)rt_gcheap_alloc(205, 64); memset(p, 'B', 64); if (i == n / 2) stale = p; }
    printf("PLANT serial_expected=%d ledger_index_expected=%d\n", n + n / 2, n / 2); fflush(stdout);
    printf("PLANT phase B reclaimed=%ld\n", rt_gc_collect()); fflush(stdout);
    if (mode == 2) { for (i = 0; i < n; i++) { p = (char *)rt_gcheap_alloc(205, 64); memset(p, 'Z', 64); } printf("PLANT re-allocated %d blocks with no fault\n", n); fflush(stdout); return 0; }
    { volatile char c = stale[0]; printf("PLANT stale read returned 0x%02x\n", (unsigned char)c); fflush(stdout); }
    return 0;
}
PLANTC
gcc -O0 -g -rdynamic -o "$T/plant" "$T/plant.c" -L "$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" 2>"$T/cc.err" || { sed -n 1,5p "$T/cc.err"; refuse "the fixture did not build -- this gate measures nothing without it"; }
SCRIP_GC_BIRTH_LEDGER=0 "$T/plant" 0 >"$T/off.out" 2>"$T/off.err"; echo "  (a) ledger off: rc=$?"
grep -q "THE BIRTH LEDGER IS OFF" "$T/off.err" && ck ok "(a) DARK CONTROL: with no birth ledger the fault names an address and says so -- the state this rung converts" || ck FAIL "(a) the ledger-off report does not announce itself; a silent instrument is the defect class this rung removes"
grep -q "ZGC-BIRTH.*block #" "$T/off.err" && ck FAIL "(a) the ledger is OFF and the report named a block anyway" || ck ok "(a) with the ledger off no block is named"
SCRIP_GC_BIRTH_LEDGER=$LEDGER "$T/plant" 0 >"$T/on.out" 2>"$T/on.err"; echo "  (b) ledger on: rc=$?"
want="$(sed -n 's/^PLANT serial_expected=\([0-9]*\) .*/\1/p' "$T/on.out")"
idx="$(sed -n 's/.*ledger_index_expected=\([0-9]*\).*/\1/p' "$T/on.out")"
got="$(sed -n 's/^\[ZGC-BIRTH\]   block #\([0-9]*\),.*/\1/p' "$T/on.err" | head -1)"
[ -n "$want" ] && [ -n "$idx" ] || refuse "the fixture did not report the serial it planted -- nothing to grade against"
if [ "$got" = "$want" ]; then ck ok "(b) THE SERIAL IS THE BIRTH SERIAL: fault names block #$got, the fixture's own count, not the vacated-ledger index #$idx"
elif [ "$got" = "$idx" ]; then ck FAIL "(b) the report named #$got, which is the VACATED-LEDGER INDEX -- the birth serial is #$want; the ring lookup is returning a stale birth at a re-used address"
else ck FAIL "(b) the report named block #${got:-<none>} where the fixture allocated #$want as the stale block"; fi
line="$(grep -m1 '^\[ZGC-BIRTH\]   block #' "$T/on.err")"
case "$line" in *"kind=205"*) k=ok;; *) k=FAIL;; esac
ck "$k" "(c1) the birth line carries the TYPE AT BIRTH (kind=205, the type the fixture asked for)"
case "$line" in *"allocated by ?"*|"") s=FAIL;; *"allocated by "*) s=ok;; *) s=FAIL;; esac
ck "$s" "(c2) the birth line names the ALLOCATING SITE by symbol, not by address alone -- ARCH-GC § 9's 'allocated by <fn> from <caller>'"
case "$line" in *"born at arena+"*) b=ok;; *) b=FAIL;; esac
ck "$b" "(c3) the birth line carries the address the block was BORN at"
SCRIP_GC_BIRTH_LEDGER=$TINY "$T/plant" 0 >"$T/tiny.out" 2>"$T/tiny.err"; echo "  (d) tiny ring: rc=$?"
tgot="$(sed -n 's/^\[ZGC-BIRTH\]   block #\([0-9]*\),.*/\1/p' "$T/tiny.err" | head -1)"
if [ -z "$tgot" ]; then grep -q "does not hold this block" "$T/tiny.err" && ck ok "(d) THE HONEST LIMIT: a ring too small to keep the record says so and names no block" || ck FAIL "(d) the tiny ring named no block and did not say why -- silence is not a limit, it is a dark instrument"
elif [ "$tgot" = "$want" ]; then ck ok "(d) the 8-entry ring still held the record (the fixture's stale block is recent) and named it correctly"
else ck FAIL "(d) an overwritten record was reported as block #$tgot -- naming the WRONG block is worse than naming none"; fi
SCRIP_GC_BIRTH_LEDGER=$LEDGER "$T/plant" 2 >"$T/heal.out" 2>"$T/heal.err"; hrc=$?
{ [ $hrc -eq 0 ] && grep -q "re-allocated" "$T/heal.out"; } && ck ok "(e) THE MUTATOR IS UNHARMED: with the ledger on, a healthy program climbs back through the quarantine and exits 0" || ck FAIL "(e) the birth ledger broke a healthy mutator (rc=$hrc) -- an instrument that changes the program is not measuring it"
echo "[$G] checks=$checks fails=$fails"
[ $fails -eq 0 ] || { echo "⛔ GATE FAIL($fails) [$G]"; exit 1; }
echo "✅ GATE PASS(0) [$G]"

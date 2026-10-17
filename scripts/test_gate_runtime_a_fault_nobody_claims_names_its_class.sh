#!/usr/bin/env bash
# test_gate_runtime_a_fault_nobody_claims_names_its_class.sh -- A SIGSEGV THAT NO SPECIFIC REPORTER CLAIMS STILL PRINTS ONE LINE
# NAMING ITS CLASS, ITS PC AND THE STACK'S ALIGNMENT (row runtime-a-stack-misalignment-sigsegv-cores-with-no-diagnostic-because-the-
# handler-does-not-recognise-it, the cfo, 2026-09-28; the cto's 2026-09-13 measurement on a rebuild of SCRIP 484f2fb2c^, where glibc's
# movaps in snprintf faulted on a frame handed over at 8 mod 16 and the process dumped core with NOT ONE LINE; hq_R's FINDING-2026-09-09
# item 4; hq_V's framing: a silent handler reds only when something else stops compensating).
#
# THE DEFECT, MEASURED 2026-09-28 on SCRIP a3fbbdaba with this gate's own fixture: a misaligned movaps AND a plain null store each
# ended rc 139 with ZERO lines on stderr.  rt_stack_overflow.c's handler did fire, but a #GP arrives as SIGSEGV with si_code SI_KERNEL
# and a null fault address, so the stale-pointer and poison reporters do not claim it, the stack-overflow test fails on the address,
# and the handler re-raised in silence -- and so did every other fault no reporter claims.
# THE CURE (src/runtime/rt/rt_stack_overflow.c, rt_fault_say): on that generic path, before the unchanged re-raise, one line:
#   scrip: fatal signal 11 (SIGSEGV) at pc <module>+0x<off> [(<symbol>+0x<off>)], fault address A, si_code=C, rsp=R (rsp mod 16 = M)
# followed by the class: SI_KERNEL with rsp at 8 mod 16 = a GENERAL-PROTECTION fault from an aligned SSE access on a stack entered
# misaligned; SI_KERNEL otherwise = a non-canonical address or an aligned access to a misaligned operand; SEGV_MAPERR = not mapped;
# SEGV_ACCERR = mapped but protected.  A pc no loaded module holds is named as emitted code in mode 3's slab.  The module offset is
# what addr2line resolves; the exit status stays 139.  No new static.
#
# ARMS (a C fixture linked on libscrip_rt.so, whose constructor installs the handler):
#   1 a movaps on a stack offset by 8: rc 139 and ONE line naming GENERAL-PROTECTION, "rsp mod 16 = 8" and the module offset, which
#     addr2line resolves to the fixture's own misaligned_movaps
#   2 a store through a null pointer: rc 139 and ONE line naming "the address is not mapped" and fault address (nil), its offset
#     resolving to null_store -- the generic path covers every unclaimed fault, not only misalignment
#   3 NO DOUBLE REPORT on the claimed path: bounded recursion past the stack still prints the stack-overflow ERROR 246 and exits 1,
#     and the generic line does not follow it
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
command -v addr2line >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: addr2line is not installed"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
cat > "$T/fx.c" <<'FXC'
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
void *rt_gcheap_alloc(uint16_t type, uint64_t payload_bytes);
__attribute__((noinline)) static void misaligned_movaps(void) { __asm__ volatile("sub $8, %%rsp\n\tmovaps %%xmm0, (%%rsp)\n\tadd $8, %%rsp" ::: "memory"); }
__attribute__((noinline)) static void null_store(volatile int *p) { *p = 1; }
__attribute__((noinline)) static long deep(long n) { volatile char pad[4096]; pad[0] = (char)n; return n ? deep(n + 1) + pad[0] : 0; }
int main(int argc, char **argv)
{
    int mode = argc > 1 ? atoi(argv[1]) : 1;
    (void)rt_gcheap_alloc(205, 16);
    if (mode == 1) misaligned_movaps();
    if (mode == 2) null_store((volatile int *)0);
    if (mode == 3) printf("%ld\n", deep(1));
    printf("FX survived mode %d\n", mode);
    return 0;
}
FXC
gcc -O0 -g -rdynamic -o "$T/fx" "$T/fx.c" -L "$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" 2> "$T/cc.err" || { sed -n 1,5p "$T/cc.err"; echo "⛔ GATE REFUSE(2) [$G]: the fixture did not build"; exit 2; }
run() { ( ulimit -c 0; exec "$T/fx" "$1" > "$T/o$1.txt" 2> "$T/e$1.txt" ) 2> /dev/null; echo $?; }
where() { local off; off=$(grep -oE 'fx\+0x[0-9a-f]+' "$T/e$1.txt" | head -1 | sed 's/^fx+//'); [ -n "$off" ] && addr2line -f -e "$T/fx" "$off" | head -1; }
r=$(run 1); n=$(grep -c '^scrip: fatal signal 11 (SIGSEGV)' "$T/e1.txt"); f=$(where 1)
if [ "$r" = 139 ] && [ "$n" = 1 ] && grep -q 'GENERAL-PROTECTION' "$T/e1.txt" && grep -q 'rsp mod 16 = 8)' "$T/e1.txt" && [ "$f" = misaligned_movaps ]; then echo "  arm 1 PASS: a misaligned movaps prints one line naming a GENERAL-PROTECTION fault at rsp mod 16 = 8, its module offset resolving to $f, and still exits 139"
else echo "  arm 1 FAIL: rc=$r lines=$n resolved=${f:-none} -- $(head -1 "$T/e1.txt" | cut -c1-160)"; RC=1; fi
r=$(run 2); n=$(grep -c '^scrip: fatal signal 11 (SIGSEGV)' "$T/e2.txt"); f=$(where 2)
if [ "$r" = 139 ] && [ "$n" = 1 ] && grep -q 'the address is not mapped' "$T/e2.txt" && grep -q 'fault address (nil)' "$T/e2.txt" && [ "$f" = null_store ]; then echo "  arm 2 PASS: a null store prints one line naming an unmapped address at (nil), its offset resolving to $f -- every unclaimed fault is named, not only misalignment"
else echo "  arm 2 FAIL: rc=$r lines=$n resolved=${f:-none} -- $(head -1 "$T/e2.txt" | cut -c1-160)"; RC=1; fi
r=$(run 3); n=$(grep -c '^scrip: fatal signal' "$T/e3.txt")
if [ "$r" = 1 ] && grep -q 'ERROR 246 -- stack overflow' "$T/e3.txt" && [ "$n" = 0 ]; then echo "  arm 3 PASS: the claimed path is unchanged -- unbounded recursion prints ERROR 246, exits 1, and no generic line follows it"
else echo "  arm 3 FAIL: rc=$r generic_lines=$n -- $(head -2 "$T/e3.txt" | tr '\n' '|' | cut -c1-160)"; RC=1; fi
echo "population: 3 arm(s) graded"
[ $RC -eq 0 ] && echo "GATE PASS [$G]" || echo "GATE FAIL [$G]"
exit $RC

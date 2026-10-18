#!/usr/bin/env bash
# test_gate_gc_the_birth_ledger_names_a_line_not_a_two_thousand_line_symbol.sh
#
# ⛔⭐ WHY THIS EXISTS, AND IT COST A FLEET-WIDE MISREADING BEFORE IT DID (cfo 2026-09-21, MODE TENET).
# The birth ledger stores the allocation site and its caller as RAW RETURN ADDRESSES (gc_vac_t.ra_site /
# .ra_from) and resolved them with dladdr, which returns only dli_sname -- THE ENCLOSING SYMBOL.  For
# try_call_builtin_by_name_bl_s that symbol is 2125 lines long and contains 26 distinct rt_wsb_alloc call
# sites, so "allocated by rt_wsb_alloc from try_call_builtin_by_name_bl_s" is the dispatcher's name, not the
# allocation's -- roughly as discriminating as naming main.  It also printed an ABSOLUTE runtime %p, which is
# meaningless once the process exits and different on every run under ASLR.
#
# ⛔⛔ WHAT THAT COST, MEASURED, NOT HYPOTHESISED.  hq_icon reported two Icon rungs entries crashing
# deterministically at SCRIP_HEAP_MB=1 with "the IDENTICAL birth signature both times: kind=215, allocated by
# rt_wsb_alloc, called from try_call_builtin_by_name_bl_s", and read that as ONE unrooted allocation class with
# two independent reproducers; the ceo routed it on that basis.  With the offset printed and resolved:
#   procedure_coexpr_suspend_replace_3 -> libscrip_rt.so+0x53d86a -> by_name_dispatch.c:6895, Icon repl(s,n), 64 KB
#   procedure_every_scan_replace_16    -> libscrip_rt.so+0x54344a -> by_name_dispatch.c:7350, the line reader, 64 B
# TWO DIFFERENT SITES, 455 LINES AND TWO BUILTINS APART.  The signatures were never identical; the SYMBOL was.
# ⭐ The one-class reading may still be right at the HOLDER, and the sharper instrument says why it is plausible:
# both sites have the SAME SHAPE -- allocate a WSB block, build a string descriptor over it, hand it back
# through *out -- and that shape occurs 48 times in this one dispatcher.  A class of ~48 with two end-to-end
# reproducers is a far more useful object than a class of 2 resting on a symbol name.
#
# ⭐ AND kind=215 NOW CARRIES ITS NAME.  HB_WSB is a #define in gc_heap.h and nothing in the tree resolved it,
# so every instrument printed a bare integer and every reader went to the header and counted (hq_icon: "kind=215
# isn't resolved to a type name anywhere I could find -- that's probably step one for whoever cures it").
# HB_KIND_NAME lives BESIDE the #defines it names, deliberately: a kind added without a name is then visibly
# adjacent to the thing it forgot, and arm 1 reds.  It is a macro and not a table because a function-scope static
# would trip test_gate_no_new_function_scope_static.sh and a file-scope one RULES.md line 231.
#
# ⛔ ARM 1 IS THE ONE THAT FAILS IF THE WORK STOPPED: it reads the kind list out of the HEADER and requires the
# resolver to cover EVERY entry, so a resolver that names the kinds that existed today and nothing later cannot
# pass tomorrow.  FAIL_ONCE=1 plants a phantom kind and must red.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
G="$(basename "${BASH_SOURCE[0]}" .sh)"
S4E="$(cd "$ROOT/.." && pwd)"
H="$ROOT/src/runtime/rt/gc_heap.h"
[ -f "$H" ] || { echo "⛔ REFUSE(2) [$G]: no $H"; exit 2; }
command -v addr2line >/dev/null || { echo "⛔ REFUSE(2) [$G]: addr2line is arm 2's instrument and it is absent"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; examined=0
# ARM 1 -- EVERY KIND IN THE HEADER RESOLVES TO A NAME.
examined=$((examined + 1))
kinds=$(grep -oE '^#define HB_[A-Z0-9_]+' "$H" | awk '{print $2}' | grep -v '^HB_IS_AGG$' | grep -v '^HB_KIND_NAME$')
[ "${FAIL_ONCE:-0}" = 1 ] && kinds="$kinds HB_PHANTOM_PLANTED_BY_FAIL_ONCE"
missing=""; total=0
for k in $kinds; do total=$((total + 1)); grep -q "\"$k\"" "$H" || missing="$missing $k"; done
if [ -z "$missing" ] && [ "$total" -gt 0 ]; then echo "  arm 1 PASS: all $total block kinds in gc_heap.h resolve to a name through HB_KIND_NAME -- an instrument printing kind=215 can print HB_WSB beside it"
else echo "  arm 1 FAIL: $total kind(s) declared, these carry no name:${missing:- none}. A kind added without a name makes every instrument print an integer a reader must look up by hand."; RC=1; fi
# ARM 2 -- THE LEDGER NAMES A RESOLVABLE OFFSET, AND IT RESOLVES TO THE RIGHT FILE.  A symbol alone cannot
# discriminate 26 call sites in one function; module+offset can, and addr2line is the reader.
examined=$((examined + 1))
# THE BIRTH LINE IS MADE BY THIS GATE'S OWN FIXTURE, NEVER BY A SEAM IN SCRIP (hq_collector 2026-10-14, CEO-1680; row
# gc-blocking-gate-birth-ledger-names-a-line-red-no-resolvable-site-ceo-1697).  This arm used to drive an Icon witness under two
# runtime plants (SCRIP_GC_PLANT_STALE_SIGMA=1 left the scan subject unreloaded after a call, SCRIP_GC_PLANT_FLIP=1 poisoned the
# old ground) so a stale read would fault and the ledger would print.  STEP B (SCRIP d51164383) made the subject a typed cell the
# chain over the maps visits and forwards, the planted read no longer reached poisoned ground, no line printed, and the arm read
# red on a CURED collector.  Lon 2026-10-11 (CEO-1680): no broken code planted so a test can trip; a seam stays allowed only inside
# an INSTRUMENT.  So the fault is made by the test's own code: the fixture calls rt_pl_fresh_var_ref (by_name_dispatch.c, a direct
# rt_ws_alloc_descr caller whose name the ledger's allocator walk does not skip; a C road, since the rtx asm leaf rt_str_alloc carves
# no frame and the ledger then names the leaf's caller's caller) 3000 times, keeps the 1500th cell, collects, and reads it -- the
# quarantine faults, the handler prints the birth line, and the site must resolve to by_name_dispatch.c, outside the allocator
# family and outside gc_heap.c.  FAIL_ONCE=1 runs the fixture with the ledger OFF (the instrument's own switch): no line, arm 2 reds.
LEDGER=4096; [ "${FAIL_ONCE:-0}" = 1 ] && LEDGER=0
cat > "$T/fx.c" <<'FIXC'
#include <stdio.h>
#include <stdint.h>
#include "descr.h"
DESCR_t rt_pl_fresh_var_ref(void);
long rt_gc_collect(void);
int main(void) {
    const char *stale = (const char *)0;
    int i;
    for (i = 0; i < 3000; i++) { DESCR_t r = rt_pl_fresh_var_ref(); if (i == 1500) stale = (const char *)r.p; }
    printf("reclaimed=%ld\n", rt_gc_collect()); fflush(stdout);
    { volatile char c = stale[0]; printf("stale read returned 0x%02x\n", (unsigned char)c); }
    return 0;
}
FIXC
if gcc -O0 -g -rdynamic -w -I"$ROOT/src" -I"$ROOT/src/ir" -I"$ROOT/src/runtime/rt" -I"$ROOT/src/runtime/core" -o "$T/fx" "$T/fx.c" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" 2>"$T/fx.cc"; then
  ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=0 SCRIP_GC_BIRTH_LEDGER=$LEDGER timeout -k 5 120s ./fx >"$T/w.out" 2>"$T/w.err" )
  grep -q 'stale read returned' "$T/w.out" && { echo "  arm 2 REFUSE: the fixture's stale read of vacated ground did not fault, so no birth line was made and nothing was graded"; RC=1; }
  line=$(grep -m1 'ZGC-BIRTH.*allocated by' "$T/w.err")
  off=$(printf '%s\n' "$line" | grep -oE 'libscrip_rt\.so\+0x[0-9a-f]+' | tail -1 | sed 's/.*+//')
  nm=$(printf '%s\n' "$line" | grep -oE 'kind=[0-9]+/HB_[A-Z0-9_]+' | head -1)
  src=""; [ -n "${off:-}" ] && src=$(addr2line -e "$ROOT/out/libscrip_rt.so" "$off" 2>/dev/null | head -1)
  if [ -n "${off:-}" ] && [ -n "${nm:-}" ] && printf '%s' "$src" | grep -q 'src/.*\.c:[0-9]' && ! printf '%s' "$src" | grep -q 'gc_heap\.c:[0-9]'; then
    echo "  arm 2 PASS: the ledger printed $nm and a module-relative offset that addr2line resolves to ${src##*/} -- one line of rt_pl_fresh_var_ref's file, not a symbol, with no plant in SCRIP"
  else echo "  arm 2 FAIL: the birth line does not carry a resolvable site OUTSIDE the allocator family -- offset [${off:-none}] kindname [${nm:-none}] resolved [${src:-none}]. A bare symbol cannot discriminate the 26 call sites of one dispatcher, and gc_heap.c names the allocator, not the allocation."; RC=1; fi
else echo "  arm 2 UNPROVEN: the fixture did not build -- $(head -c 200 "$T/fx.cc")"; RC=1; fi
# ARM 3 -- NO ABSOLUTE RUNTIME POINTER IN THE BIRTH LINE.  An absolute address is a fact about ONE RUN under
# ASLR; a module-relative offset is a fact about the BUILD and survives being pasted into a mail or a FINDING.
examined=$((examined + 1))
if [ -s "$T/w.err" ] && grep -q 'ZGC-BIRTH.*allocated by' "$T/w.err"; then
  if grep -m1 'ZGC-BIRTH.*allocated by' "$T/w.err" | grep -qE '\(0x[0-9a-f]{10,}\)'; then echo "  arm 3 FAIL: the birth line still prints a bare absolute runtime address, which differs every run under ASLR and is unresolvable after exit"; RC=1
  else echo "  arm 3 PASS: no bare absolute runtime pointer in the birth line -- what it prints can be pasted into a FINDING and resolved later against the build"; fi
else echo "  arm 3 UNPROVEN: arm 2 produced no birth line to inspect"; fi
if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$G]: the birth ledger names a KIND by name and a SITE by module-relative offset, so an allocation inside a 2125-line dispatcher is attributable to its line (examined $examined arms)"
else echo "GATE FAIL(1) [$G]: the birth ledger cannot attribute an allocation to a line (examined $examined arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC

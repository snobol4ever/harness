#!/usr/bin/env bash
# test_gate_gc_no_collection_inside_a_runtime_call.sh -- THE ALLOCATOR NEVER COLLECTS AND NEITHER DOES A RUNTIME CALL:
# a safe point is taken by EMITTED code at the return of an allocating runtime call, never by C inside the call
# (Lon 2026-09-17, in-chat to the ceo; RULES.md FACT RULE THE COLLECTOR GUESSES NOTHING, CEO-812: "a landing that adds
# ... a collection inside a runtime call is reverted on sight").
#
# MEASURED 2026-09-23 (cto, row gc-a-site-that-refuses-every-poll-form-names-an-unrooted-holder-...): a bare poll after
# the concat call_rt at bb_binop_concat_slot.cpp:84 DIFFed procedure_every_alt_replace_16 at SCRIP_GC_STRESS=1 under
# SCRIP_GC_RELOC=1 in both modes.  The gdb trace (trace2.py: seams, allocations, collections and the variable's block in
# order) read: c_rt_assign_var_body opened with a SHIELDED rt_gc_point_arr(sh, 2, 0) from the original 1ac176625
# regeneration; the tvsubs road (a[2:3] := "XYZ") built the new string with rt_str_alloc, then called rt_assign_var
# RECURSIVELY, whose entry seam collected with the two shielded cells repaired -- and the OUTER body's C local `vc`
# (the VCELL block) was stale across it, so `vc->len = srclen` wrote 0x0000000000000003 into the relocated result string.
# Under ordinary compaction the block usually keeps its address (84.7% of forwardings, CEO-1109), which is why a shielded
# seam inside a runtime call reads green for months: it protects the two cells it was handed and nothing else the C
# frames hold.  The seam is deleted; the emitted poll after rt_assign_var_strict (bb_assign_var.cpp:47) is the safe point.
#
# THIS GATE RATCHETS THE CLASS TO ZERO.  Every caller of a collector entry (rt_gc_point, rt_gc_point_arr, rt_gc_point_arr_c,
# rt_gc_point_arr_probe_c, rt_gc_poll_slow, rt_gc_collect_now) OUTSIDE the collector's own files is counted from source.
# The standing set is DECLARED BY NAME below: ONE function since the by_name_dispatch.c landing of 2026-09-23 removed its 18
# (19 sites: the dop entries, rt_call_arr_impl's conditional seam, the Prolog rt_pl_dop_*_c leaves and the PL_CX_LEAF_HEAD
# macro) -- rt_scan_enter in gen_runtime.c, left for the landing after hq_icon's g_scan_subj_ptr row in the same file.  Each is resolved to its ENCLOSING FUNCTION by the python pass
# below, so a site that moves within a function does not move the list.  A caller not on the list is a regression and
# reds; a declared caller that is gone reds too, so the list moves in the landing that earns it.  FAIL_ONCE=1 plants one.
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
DECLARED="src/runtime/builtins/gen_runtime.c:rt_scan_enter"
ENTRIES='rt_gc_point_arr_probe_c|rt_gc_point_arr_c|rt_gc_point_arr|rt_gc_point|rt_gc_poll_slow|rt_gc_collect_now'
OWN='src/runtime/rt/gc_heap.c|src/runtime/rt/gc_heap.h|src/runtime/rt/rt_asm_helpers.S|src/runtime/rt/rtx/'
RC=0
callers="$(cd "$ROOT" && python3 - "$ENTRIES" "$OWN" <<'PY'
import re, sys, os
entries, own = sys.argv[1], sys.argv[2]
call_rx = re.compile(r'\b(' + entries + r')\s*\(')
own_rx = re.compile(r'^(' + own + ')')
def_rx = re.compile(r'^[A-Za-z_][A-Za-z_0-9 \*]*?[ \*]([A-Za-z_][A-Za-z_0-9]*)\s*\([^;]*$')
out = set()
for root, dirs, files in os.walk('src/runtime'):
    for f in sorted(files):
        if not (f.endswith('.c') or f.endswith('.S')): continue
        path = os.path.join(root, f)
        if own_rx.match(path): continue
        name = '?'
        for ln in open(path, errors='replace'):
            m = def_rx.match(ln)
            if m and not ln.startswith(' ') and 'extern' not in ln.split('(')[0]: name = m.group(1)
            if call_rx.search(ln) and 'extern ' not in ln: out.add(path + ':' + name)
for x in sorted(out): print(x)
PY
)"
[ "${FAIL_ONCE:-0}" = 1 ] && callers="$(printf '%s\n%s\n' "$callers" "src/runtime/planted.c:planted_by_fail_once" | sort -u)"
want="$(printf '%s\n' "$DECLARED" | sed '/^$/d' | sort -u)"
new="$(comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$callers") | tr '\n' ';')"
gone="$(comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$callers") | tr '\n' ';')"
n=$(printf '%s\n' "$callers" | sed '/^$/d' | wc -l)
if [ -n "$new" ]; then echo "  FAIL (a) a runtime function collects INSIDE its own call and is not on the declared standing set: $new -- the safe point belongs to the emitted code at the call's return (CEO-812); delete the seam, never add one"; RC=1
elif [ -n "$gone" ]; then echo "  FAIL (a) a declared seam is gone and the standing set still names it: $gone -- move the list in the landing that earned it"; RC=1
elif [ "$n" -gt 0 ]; then echo "  ok   (a) exactly the declared standing seam(s) remain, $n by name: $(printf '%s' "$callers" | tr '\n' ' ') -- the ratchet drives this to 0 (the ceo's row names them)"
else echo "  ok   (a) ZERO runtime functions collect inside their own call: every safe point is emitted"; fi
if grep -q 'rt_gc_point_arr(sh, 2' "$ROOT/src/runtime/pattern_match.c" 2>/dev/null; then echo "  FAIL (b) the assignment body's entry seam is back (c_rt_assign_var_body) -- the stale-vc scribble this gate names"; RC=1; else echo "  ok   (b) c_rt_assign_var_body carries no entry seam"; fi
echo "population: 2 arm(s) graded, callers=$n declared=$(printf '%s\n' "$want" | sed '/^$/d' | wc -l)"
if [ $RC = 0 ]; then echo "✅ GATE PASS(0) [$G]: no runtime call collects inside itself beyond the declared standing set"; else echo "⛔ GATE FAIL(1) [$G]: a collection inside a runtime call (examined 2 arms)"; fi
exit $RC

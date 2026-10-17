#!/usr/bin/env bash
# test_gate_gc_runtime_compiled_code_bakes_no_arena_address.sh -- CODE COMPILED AT RUN TIME OUTLIVES EVERY COLLECTION, SO
# NOTHING IT BAKES AS AN IMMEDIATE MAY LIVE IN THE COLLECTED HEAP (cto 2026-09-23, CTO-152; law RULES.md FACT RULE THE
# COLLECTOR GUESSES NOTHING, CEO-812: a word the collector never visits is not a root, and an imm64 inside emitted code is
# exactly such a word).
#
# MEASURED 2026-09-23 on arbno_fence_span_branch_1 (the SNOBOL4 rungs, extracted standalone): with the deferred-pattern
# entry polled after dtp_fn_of (bb_match_defer.cpp:115, the last unpolled site of the census) the witness printed FAIL for
# MATCH at SCRIP_GC_STRESS=1/3/5 in every arena and relocation configuration, and gdb disassembly of the function dtp_fn_of
# returned (a runtime-compiled "rtpat" chain in the box pool) showed ONE imm64 inside [g_hp_arena, g_hp_top): an HB_WSC
# block holding "ARB$1", the ARBNO iteration variable's name that dtp_rcp_tree minted with rt_heap_strdup_c and the
# lowerer baked into the compiled code as the operand of a by-name load.  Referenced from nowhere the collector visits,
# the block was reclaimed at the first collection after the compile, and the name read as vacated ground.  Without the poll
# the compiled pattern ran to completion before any collection, which is why the census's last site stayed unpolled.
#
# THE CURE: every sval dtp_rcp_tree hands the runtime compiler (literal copies, the ARB$n and OPQ$n names, the deferred
# variable names) comes from ct_strdup/ct_strndup -- the compile-time arena that owns the parser's own literals for the
# life of the process -- never from rt_str_alloc or rt_heap_strdup_c.  THE INSTRUMENT: bb_compile_pat_tree_sz scans the
# bytes it just emitted for any 8-byte value inside the arena and prints [RTPAT-HEAPIMM] fn= bytes= heapimm= under
# SCRIP_RTPAT_DIAG=1; SCRIP_RTPAT_PLANT_HEAPIMM=1 restores the heap name so the scan can be seen to fire.
#
# ARMS: (a) every compile of the witness reads heapimm=0 (mode 3, where the scan lives); (b) the plant reads heapimm>=1 --
# an instrument never seen to fire is not known to look; (c) THE PROPERTY: the witness answers its oracle-cut ref at
# SCRIP_GC_STRESS=1,3,5 under at the compiled default arena in mode 3 and mode 4, with the entry polled.
# FAIL_ONCE=1 runs arm (a) under the plant and requires it to red.
# ⛔ THE WITNESS IS BUILT AT RUN TIME BY CONSTRUCTION (ceo 2026-09-28, SCRIP 0d9ae641f): it used to reach the run-time compiler
# only because $'W' was outside the pattern pre-compile; once $'name' lowered as the variable, the whole match compiled ahead of
# time and arms (a) and (b) read 0 compiles (CEO-554: a gate anchored on a found witness dies the day the witness is cured). The
# ARBNO now goes through a TABLE element -- the value road, with $'W' a variant reference -- so it is built and compiled at run time.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- the ref is cut from the oracle at run time, never typed"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
cat > "$T/w.sno" <<'SNO'
        $'W' = FENCE(SPAN(' ') | '')
        S = '1,2,3'
        R = TABLE()
        R[1] = ARBNO($'W' ',' ANY('123'))
        S POS(0) ANY('123') R[1] RPOS(0)                          :S(OK)F(BAD)
OK      OUTPUT = 'MATCH'                                          :(NEXT)
BAD     OUTPUT = 'FAIL'
NEXT    T = 'a b  c'
        T POS(0) ARBNO(ANY('abc') SPAN(' ')) ANY('abc') RPOS(0)  :S(OK2)F(BAD2)
OK2     OUTPUT = 'MATCH2'                                         :(END)
BAD2    OUTPUT = 'FAIL2'
END
SNO
( cd "$T" && timeout -k 5 20s "$SBL" -bf w.sno </dev/null ) > "$T/w.ref" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the oracle refused its own witness"; exit 2; }
[ -s "$T/w.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced an EMPTY ref"; exit 2; }
plant_a=""; [ "${FAIL_ONCE:-0}" = 1 ] && plant_a="SCRIP_RTPAT_PLANT_HEAPIMM=1"
( cd "$T" && env -u SCRIP_HEAP_MB $plant_a SCRIP_RTPAT_DIAG=1 timeout -k 5 60s "$SCRIP" w.sno </dev/null > a.out 2> a.err ); n=$(grep -c 'RTPAT-HEAPIMM' "$T/a.err" || true); bad=$(grep -oE 'heapimm=[0-9]+' "$T/a.err" | grep -vc 'heapimm=0$' || true)
if [ "$n" -ge 1 ] && [ "$bad" = 0 ]; then echo "  ok   (a) $n runtime compile(s), every one heapimm=0 -- no arena address is baked into code that outlives the collection"
else echo "  FAIL (a) $n runtime compile(s), $bad with a heap immediate: $(grep -oE 'heapimm=[0-9]+' "$T/a.err" | sort | uniq -c | tr '\n' ' ') -- a runtime-compiled pattern bakes an arena address"; RC=1; fi
( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_RTPAT_PLANT_HEAPIMM=1 SCRIP_RTPAT_DIAG=1 timeout -k 5 60s "$SCRIP" w.sno </dev/null > p.out 2> p.err ); pn=$(grep -oE 'heapimm=[0-9]+' "$T/p.err" | grep -vc 'heapimm=0$' || true)
if [ "$pn" -ge 1 ]; then echo "  ok   (b) PLANTED: SCRIP_RTPAT_PLANT_HEAPIMM=1 puts the ARB\$n name back in the heap and the scan reads it ($pn compile(s) with heapimm>0) -- the instrument is seen to fire"
else echo "  FAIL (b) the plant did not fire -- the heap-immediate scan reports nothing under SCRIP_RTPAT_PLANT_HEAPIMM=1, so arm (a) is not known to look"; RC=1; fi
band=""; pbad=0
for st in 1 3 5; do ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_GC_STRESS=$st timeout -k 5 60s "$SCRIP" w.sno </dev/null > m3_$st.out 2> m3_$st.err ); if cmp -s "$T/m3_$st.out" "$T/w.ref"; then band="$band m3@$st:ok"; else band="$band m3@$st:DIFF"; pbad=$((pbad+1)); fi; done
if ( cd "$T" && "$SCRIP" --compile w.sno -o w.s </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic w.s -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o w4 2>/dev/null ); then
  for st in 1 3 5; do ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_GC_STRESS=$st timeout -k 5 60s ./w4 </dev/null > m4_$st.out 2> m4_$st.err ); if cmp -s "$T/m4_$st.out" "$T/w.ref"; then band="$band m4@$st:ok"; else band="$band m4@$st:DIFF"; pbad=$((pbad+1)); fi; done
else echo "  FAIL (c) the mode-4 witness did not build"; RC=1; fi
if [ "$pbad" = 0 ]; then echo "  ok   (c) THE PROPERTY: the witness answers its oracle-cut ref at stress 1/3/5 under forced relocation with the deferred entry polled --$band"
else echo "  FAIL (c) a runtime-compiled pattern lost its data across a collection --$band"; RC=1; fi
census=$(grep -c 'x86_rt_gc_poll' "$ROOT/src/templates/bb/bb_match_defer.cpp" || true)
if grep -A2 'call", "dtp_fn_of"' "$ROOT/src/templates/bb/bb_match_defer.cpp" | grep -q 'x86_rt_gc_poll'; then echo "  ok   (d) the deferred-pattern entry is polled after dtp_fn_of (bb_match_defer.cpp), the census's last site"; else echo "  FAIL (d) the poll after dtp_fn_of is gone -- the census's last unpolled site is back"; RC=1; fi
echo "population: 4 arm(s) graded, compiles=$n"
if [ $RC = 0 ]; then echo "✅ GATE PASS(0) [$G]: runtime-compiled code bakes no arena address, the scan is seen to fire, and the deferred entry survives forced relocation polled"; else echo "⛔ GATE FAIL(1) [$G]: a runtime-compiled pattern bakes or loses heap data (examined 4 arms)"; fi
exit $RC

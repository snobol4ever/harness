#!/usr/bin/env bash
# test_gate_gc_the_allocating_set_is_a_generated_table_gated_against_the_call_graph.sh
# ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 6.5d (cto, 2026-09-18; row
# gc-the-emitter-emits-the-poll-not-the-template, rung 1; the ceo's CEO-898 proposal).
#
# WHAT THIS GATE HOLDS. The poll is placed by hand, one judgement per call site, and that method has cost four
# broken batches. The cure is for THE EMITTER to emit it, because the emitter already routes every named runtime
# call through one function (x86_rtcc_call) whose first act is a symbol-keyed table lookup (x86_rtcc_clob).
# The one thing the emitter cannot do today is know WHICH callees allocate: that set is derived from the built
# libscrip_rt.so, and the emitter is compiled INTO that .so. So the set becomes a CHECKED-IN GENERATED TABLE,
# and this gate refuses a table that disagrees with the binary's own call graph.
#
# ⛔ WHY THE RETURN CLASS IS IN THE TABLE AND NOT INFERRED LATER. The poll's SHAPE depends on it: a VOID return
# needs the bare poll; a DESCR_t return may be spilled as a descriptor cell into the swept range and relocated
# (6.5b); anything else -- a long, an int, a pointer, a 16-byte struct that is NOT a DESCR -- must go BELOW the
# poll's floor, because gc_zeta_frame visits any word inside a heap block RAW and rewrites it when the block
# slides (6.5c). Getting that wrong in the DESCR direction is silent corruption, which is why arm 2's planted
# violation is exactly a class widened from OTHER to DESCR.
#
# ⛔⭐ AND THE FINDING THIS ROW TURNED UP ON ITS FIRST GENERATION, WHICH ARM 4 NOW HOLDS SO IT CANNOT COME BACK.
# The derivation recorded `call` edges only. The hand-written asm allocators in src/runtime/rtx/rtx_alloc.s --
# rt_str_alloc and rt_agg_alloc -- reach the carve by a TAIL JUMP and never execute `call rt_gcheap_alloc`, so
# they AND everything that reaches the heap only through them read NON-ALLOCATING: 99 functions, the SNOBOL4
# string builtins among them (DUPL_fn, REVERS_fn, SUBSTR_fn, TRIM_fn, BCHAR_fn, _CHAR_, _COLLECT_, _ITEM_).
# Downstream that put 27 emitter call sites OUTSIDE THE DENOMINATOR ENTIRELY -- neither polled nor counted
# unpolled -- in the very number the GC emergency is steered by: allocating_call_sites 210 -> 237, unpolled
# 97 -> 123. A tail jump IS an edge for the question this census asks, because control reaches the target, the
# target may allocate, and it returns past us to OUR caller with the caller's frame live.
#
# ⛔ AND THE QUESTION THIS GATE ASKS ABOUT ITSELF, carried from CTO-78 where a gate was found grading a class its
# population did not contain: DOES THIS INSTRUMENT'S POPULATION CONTAIN AN INSTANCE OF WHAT IT GRADES? Arm 3 reds
# unless every return class the table distinguishes actually occurs in it. A table that were all one class would
# make the column vacuous while reading green.
#
# ⭐ RUNG 1 LANDS THE TABLE AND ITS GATE, NOT YET A CONSUMER. The emitter reads it in rung 2 (the regime switch
# and the poll shapes) and rung 3 flips one family through the hook with NO template edit. Stated so the absent
# consumer is a declared rung and not an oversight; the freshness arm is what keeps the table from rotting until
# then.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
GEN="$HERE/util_gen_gc_allocating_table.py"; [ -f "$GEN" ] || { echo "⛔ GATE REFUSE(2) [$G]: $GEN absent"; exit 2; }
TAB="$ROOT/src/templates/x86/gc_allocating_table.inc"
SO="$ROOT/out/libscrip_rt.so"; [ -f "$SO" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime binary at $SO -- build first"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0

echo "  HOLDS: the allocating set the emitter will consult is a GENERATED table, derived from the runtime binary's own call graph and its own DWARF, and it is refused the moment it disagrees with that binary -- the emitter cannot derive it at its own compile time, so the alternative to a gated table is a hand list, which is the one thing THE COLLECTOR GUESSES NOTHING forbids."

python3 "$GEN" --selftest > "$T/self.txt" 2>&1
if [ $? -eq 0 ] && grep -q 'arms green' "$T/self.txt"; then echo "  arm 1 PASS: generator $(grep -o 'SELFTEST .*' "$T/self.txt") -- including the planted dropped symbol and the planted OTHER-widened-to-DESCR"
else echo "⛔ arm 1 RED: the generator's own selftest is not green -- an instrument not shown to discriminate has measured nothing"; sed 's/^/      /' "$T/self.txt" | head -10; RC=1; fi

[ -f "$TAB" ] || { echo "⛔ GATE REFUSE(2) [$G]: $TAB is not in the tree -- generate it with $GEN"; exit 2; }
python3 "$GEN" --check --so "$SO" --out "$TAB" > "$T/check.txt" 2>&1; CRC=$?
SUM="$(grep -o 'GC-ALLOC-TABLE .*' "$T/check.txt" | head -1)"
if [ "$CRC" -eq 0 ]; then echo "  arm 2 PASS: $SUM -- byte-identical to what this binary's call graph and DWARF produce right now"
else echo "⛔ arm 2 RED: the checked-in table disagrees with the binary (rc=$CRC):"; sed 's/^/      /' "$T/check.txt" | head -10; RC=1; fi
sed 's/GC_RET_OTHER/GC_RET_DESCR/' "$TAB" > "$T/widened.inc"
python3 "$GEN" --check --so "$SO" --out "$T/widened.inc" > "$T/plant2.txt" 2>&1
if [ $? -ne 0 ]; then echo "  arm 2 planted-violation: a table whose OTHER returns are silently widened to DESCR is REFUSED -- that is the mutation that would spill an untagged long as a descriptor cell into the swept range"
else echo "⛔ arm 2 PLANTED-VIOLATION DID NOT TRIP: the freshness check accepted a table with every return class widened to DESCR"; RC=1; fi

NV=$(grep -c ', GC_RET_VOID },$' "$TAB")
ND=$(grep -c ', GC_RET_DESCR },$' "$TAB")
NO=$(grep -c ', GC_RET_OTHER },$' "$TAB")
NU=$(grep -c ', GC_RET_UNKNOWN },$' "$TAB")
if [ "${NV:-0}" -gt 0 ] && [ "${ND:-0}" -gt 0 ] && [ "${NO:-0}" -gt 0 ]; then
    echo "  arm 3 PASS: every return class the table distinguishes OCCURS in it -- VOID=$NV DESCR=$ND OTHER=$NO UNKNOWN=$NU. The column is graded by a population that contains it, which is the question CTO-78 found a gate failing."
else echo "⛔ arm 3 RED: VOID=${NV:-0} DESCR=${ND:-0} OTHER=${NO:-0} -- a return class with no instance in the table makes that column vacuous while the gate reads green"; RC=1; fi
if [ "${NU:-0}" -eq 0 ]; then echo "  arm 3b PASS: 0 symbols are UNKNOWN -- every allocating symbol's return class is settled by the binary's DWARF, and an UNKNOWN would mean the emitter must emit NO poll there rather than guess"
else echo "  arm 3b REPORTED: $NU symbol(s) UNKNOWN -- the emitter emits no poll for those and they are named, not guessed"; fi

MISS=""
for s in rt_str_alloc rt_agg_alloc; do grep -q "\"$s\"," "$TAB" || MISS="$MISS $s"; done
if [ -z "$MISS" ]; then echo "  arm 4 PASS: the TAIL-JUMP allocators rt_str_alloc and rt_agg_alloc are in the table -- they reach the carve by jmp and never call rt_gcheap_alloc, and a call-edge-only derivation loses them and the 99 functions that reach the heap only through them (27 emitter call sites, allocating_call_sites 210 -> 237)"
else echo "⛔ arm 4 RED: absent from the table:$MISS -- the derivation has narrowed back to call edges only, and every caller of these is silently non-allocating again"; RC=1; fi
grep -q 'DW_TAG_unspecified_type\|EDGE_RXS' "$HERE/util_gc_census.py" && echo "  arm 4b PASS: the census's derivation names its tail-jump edge set (EDGE_RXS) rather than matching call alone" || { echo "⛔ arm 4b RED: util_gc_census.py no longer carries the tail-jump edge set"; RC=1; }

python3 - "$SO" "$TAB" > "$T/agree.txt" 2>&1 <<'PY'
import importlib.util, os, re, sys
so, tab = sys.argv[1], sys.argv[2]
here = os.path.dirname(os.path.abspath(tab))
spec = importlib.util.spec_from_file_location("c", os.path.join(os.path.dirname(so), "..", "..", "harness", "scripts", "util_gc_census.py"))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
live = m.allocating_entries_from_binary(so, out=lambda *a, **k: None)
have = set(re.findall(r'^\s*\{ "([^"]+)",', open(tab, encoding="utf-8").read(), re.M))
print("TABLE=%d CENSUS=%d ONLY_TABLE=%d ONLY_CENSUS=%d" % (len(have), len(live), len(have - live), len(live - have)))
print("SAMPLE_ONLY_CENSUS", sorted(live - have)[:5])
print("SAMPLE_ONLY_TABLE", sorted(have - live)[:5])
PY
AG="$(grep -o 'TABLE=.*' "$T/agree.txt" | head -1)"
OT=$(printf '%s' "$AG" | sed -n 's/.*ONLY_TABLE=\([0-9]*\).*/\1/p'); OC=$(printf '%s' "$AG" | sed -n 's/.*ONLY_CENSUS=\([0-9]*\).*/\1/p')
if [ -n "$AG" ] && [ "${OT:-1}" -eq 0 ] && [ "${OC:-1}" -eq 0 ]; then echo "  arm 5 PASS: $AG -- the emitter's table and the coo's safe-point census grade EXACTLY the same population, so the two instruments cannot drift apart and report progress against different denominators"
else echo "⛔ arm 5 RED: $AG -- the table and the census disagree about which functions allocate"; sed 's/^/      /' "$T/agree.txt" | head -6; RC=1; fi

BAD=$(grep -nE '/\*|//|^[[:space:]]*$' "$TAB" | head -3)
if [ -z "$BAD" ]; then echo "  arm 6 PASS: the generated src/ file carries no comment and no blank line -- RULES.md ABSOLUTE, and the pre-commit hook refuses a staged src/ file that does. Its provenance lives in the generator and in this gate."
else echo "⛔ arm 6 RED: the generated table carries a comment or a blank line:"; printf '      %s\n' "$BAD"; RC=1; fi

[ $RC -eq 0 ] && echo "✅ GATE PASS [$G]" || echo "⛔ GATE FAIL [$G]"
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC

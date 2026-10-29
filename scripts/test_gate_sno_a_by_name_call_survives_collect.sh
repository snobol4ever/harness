#!/usr/bin/env bash
# test_gate_sno_a_by_name_call_survives_collect.sh -- A FUNCTION NAME IS NOT A HEAP OBJECT: a by-name call still
# resolves its function after COLLECT has run twice (hq_V, HQV-52/53, ceo rank-0
# snobol4-a-by-name-call-loses-its-function-name-across-collect-so-the-next-builtin-resolves-the-empty-string).
#
# MECHANISM, measured 2026-09-13 and not inferred: the lowerer interns every function-name string through
# lp_strdup (src/lower/lower_common.c), which allocated with rt_pinned_strdup and so put the name IN THE COLLECTED
# HEAP as HB_WSS. bb_call.cpp:453 emits the call site two ways -- mode 4 writes the name into .rodata and takes a
# rip-relative lea (a fresh copy OUTSIDE the heap, which is why every mode-4 arm was byte-exact), mode 3 bakes the
# RAW POINTER as an immediate. ⭐ AN IMMEDIATE IN AN INSTRUCTION STREAM IS NOT A SLOT IN MEMORY, so no root scan
# reaches it, so the block is never marked, so COLLECT reclaims it and the next by-name call resolves the empty
# string: SCRIP_DEBUG_APPLY=1 printed unresolved '' (ufname='', nargs=1) and core.c's _func_buckets lookup missed,
# raising error 22 Undefined function called. ⛔ PINNING WAS NEVER THE PROTECTION -- HB_WSS IS pinned, and PINNED
# MEANS DOES NOT MOVE, NOT IS NOT RECLAIMED. Direct observation: the heap top moves BACKWARDS across the second
# COLLECT, ...fc0 -> ...f60, with the name pointer left below it. CURE (SCRIP e593ee934): lp_strdup allocates with
# malloc, evicting the program-lifetime string class from the collected heap.
#
# ⛔ WHY THIS GATE EXISTS AT ALL: the cure was proven on csnobol4_suite/intval, a PACKAGE entry, and a cure proven
# on a program that can leave the denominator owes a gate that keeps it under test. The witness below is minted
# here, graded against the oracle, and cannot be cut from under the cure by a suite edit.
#
# ARMS: (1) mode 3, the 5-statement witness, 20 runs, every one byte-identical to the oracle -- THE DISCRIMINATOR;
# (2) mode 4, the same witness, byte-identical to the same oracle ref -- mode 4 was never exposed and this arm
# keeps it that way rather than assuming it; (3) csnobol4_suite/intval in mode 3 against its shipped ref, the
# package entry the row was opened on.
# ⛔ THE SECOND COLLECT IS LOAD-BEARING: a witness with ONE COLLECT passes on the defective build. Measured.
# FAIL-ONCE / PASS-ONCE, 2026-09-13, by reverting lp_strdup to rt_pinned_strdup and REBUILDING (the two libraries
# verified distinct by sha256 -- an A/B that does not prove that compared a build with itself, which is how two of
# my own control arms were voided this week): arm 1 FAILS 20/20 on the reverted build, PASSES 20/20 on the cure.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- this gate's ref is CUT FROM THE ORACLE at run time, never typed"; exit 2; }
INTVAL="${CORPUS_ROOT:-$(cd "$ROOT/.." && pwd)}/corpus/packages/snobol4/csnobol4_suite/intval.sno"
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
printf '\t&TRIM = 1.0\n\tCOLLECT(999.9)\n\tOUTPUT = CHAR(65.0)\n\tCOLLECT(999.9)\n\tOUTPUT = CHAR(66.0)\nEND\n' > "$T/w.sno"
( cd "$T" && timeout -k 5 20s "$SBL" -bf w.sno </dev/null ) > "$T/w.ref" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the oracle refused its own witness -- no ref to grade against"; exit 2; }
[ -s "$T/w.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced an EMPTY ref -- an instrument that cannot measure refuses"; exit 2; }
bad=0; first=""
for i in $(seq 1 20); do
    got="$(timeout -k 5 8s "$SCRIP" "$T/w.sno" </dev/null 2>&1)"
    if [ "$got" != "$(cat "$T/w.ref")" ]; then bad=$((bad+1)); [ -z "$first" ] && first="$got"; fi
done
if [ "$bad" = 0 ]; then echo "  m3 PASS (20/20 byte-identical to the oracle across two COLLECTs: $(tr '\n' '|' < "$T/w.ref"))"
else echo "  m3 FAIL ($bad/20 diverged -- the by-name call lost its function name across COLLECT; first divergence: $(echo "$first" | tr '\n' '|'); oracle: $(tr '\n' '|' < "$T/w.ref"))"; RC=1; fi
if "$SCRIP" --compile "$T/w.sno" --out="$T/w.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/w.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$T/w" 2>"$T/ld.log"; then
    got4="$(timeout -k 5 8s "$T/w" </dev/null 2>&1)"
    if [ "$got4" = "$(cat "$T/w.ref")" ]; then echo "  m4 PASS (the .rodata copy is outside the heap and stays outside it: $(echo "$got4" | tr '\n' '|'))"
    else echo "  m4 FAIL (mode 4 diverged from the oracle: got $(echo "$got4" | tr '\n' '|'), oracle $(tr '\n' '|' < "$T/w.ref"))"; RC=1; fi
else echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link failed, so arm 2 measured nothing (see $T/ld.log)"; exit 2; fi
if [ -f "$INTVAL" ] && [ -f "${INTVAL%.sno}.ref" ]; then
    if timeout -k 5 8s "$SCRIP" "$INTVAL" </dev/null 2>&1 | diff -q - "${INTVAL%.sno}.ref" >/dev/null; then echo "  intval PASS (the csnobol4 package entry the row was opened on is green in mode 3)"
    else echo "  intval FAIL (csnobol4_suite/intval diverged from its shipped ref)"; RC=1; fi
else echo "  intval SKIP (csnobol4_suite/intval not present at $INTVAL -- arms 1 and 2 are minted here and still bind)"; fi
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: a by-name call resolves its function after two COLLECTs, in both modes, and the package entry stays green"
else echo "⛔ GATE FAIL(1) [$G]: a function-name string is reachable by the collector again (examined 3 arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC

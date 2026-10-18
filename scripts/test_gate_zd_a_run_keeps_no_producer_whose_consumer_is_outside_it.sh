#!/usr/bin/env bash
# test_gate_zd_a_run_keeps_no_producer_whose_consumer_is_outside_it.sh -- A PLANNED PRODUCER WRITES THE SPINE ONLY, SO A
# CONSUMER OUTSIDE ITS RUN READS A FRAME SLOT NOBODY WROTE (cfo 2026-09-16, the negation row, minted on the CEO-773 row).
#
# MECHANISM, measured with SCRIP_ZD_DIAG=1 and the emitted .s, not inferred: `OUTPUT = SIZE('ab') ~DIFFER('a','a')` lowers
# to LIT 'ab' -> CALL SIZE -> LIT 'a' -> LIT 'a' -> DIFFER, whose gamma (success) fails the statement and whose omega (the
# negation's null) runs LIT '' -> BINOP concat -> ASSIGN. zd_plan (src/emitter/emit.cpp) plans the statement's gamma chain
# as one run (SIZE on the spine, op_zres=1: the CALL template stores its result at [rsp+0] and never its frame slot) and
# then refuses the omega-head run holding the ASSIGN with why="opnd", because a run may only read operands produced
# inside it. The refused ASSIGN is emitted UNPLANNED and reads its operand where an unplanned box reads: the frame slot
# (+64, IR_CALL result, [rsp+64] at depth 0). DIFFER's omega exit unwinds through the operand literals' beta chain and
# pops all 80 bytes to the statement base, so the value is gone and the slot was never written: '' or a garbage
# integer prints where sbl -bf prints the value. A literal on the left survives only because the concat-with-null fold
# re-materialises it inside the omega run; a variable, a builtin call, a user call, a parenthesised concat all lose.
# CURE (planner, never the lowering): after a run is built, no node stays in it whose result is consumed by a node
# outside the run -- the run is CUT before that producer and re-checked until stable (SCRIP_ZD_CONSUMER_CUT=0 restores
# the old plan; that killswitch is deleted (hq_zetas 2026-10-17, the spine flip, under the cto's review: ZETA HAS NO MODES, and CEO-1680 allows no seam in SCRIP for a test)). xop frame members (the blob rbp channel) are exempt because their reader has a frame home; literals are
# NOT exempt -- with them exempt the unplanned SIZE read its 'ab' from an unwritten frame slot and printed 29059.
#
# ARMS: the row's DONE-WHEN witness (a user-function result concatenated before a negation, two statements) plus eleven
# labelled variants -- builtin call, variable, parenthesised concat, trailing literal, ~IDENT, a literal control, an
# operand-order control -- graded in mode 3 and mode 4 against `sbl -bf`, ref cut at run time. FAIL-ONCE / PASS-ONCE
# 2026-09-16 on one tree, `git stash` around the diff, compiler rebuilt each side (4.4 s): origin db4a6b1fc m3 and m4
# both FAIL (rc=0, 18 differing diff lines = 9 of the 12 printed lines wrong), cure both PASS. Cost ~2 s at load 7.
# INERTNESS on one binary through SCRIP_ZD_CONSUMER_CUT=0 vs =1: 178 loose+csnobol4 programs emit byte-identical .s, and
# the 80-program m3 sample is identical row for row unstressed and at SCRIP_GC_STRESS=30 -- the class is absent from the
# loose corpus (it was found in aisnobol's SNOLISP). Two exemptions, each measured: pattern-family consumers (IR_MATCH_*)
# read the spine through the blob's own channel, and cutting before them turned pos_dyn_inline MATCHED -> NO MATCH;
# literals are NOT exempt, because an unplanned consumer reads a literal's frame slot too (exempting them printed 29059).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- the ref is CUT FROM THE ORACLE at run time, never typed"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
printf " DEFINE('ID(A)') :(ID.END)\nID ID = A :(RETURN)\nID.END\n OUTPUT = '1:' 'x' ~DIFFER('a','a')\n OUTPUT = '2:' SIZE('ab') ~DIFFER('a','a')\n OUTPUT = '3:' ID('A') ~DIFFER('a','a')\n OUTPUT = '4:' ID('A') DIFFER('a','b')\n OUTPUT = '5:' ID('A') ~IDENT('a','b')\n OUTPUT = '6:' SIZE('ab') ~DIFFER('a','b')\n OUTPUT = '7:' ~DIFFER('a','a') SIZE('ab')\n X = 'q'\n OUTPUT = '8:' X ~DIFFER('a','a')\n OUTPUT = '9:' (SIZE('ab') 'z') ~DIFFER('a','a')\n OUTPUT = '10:' SIZE('ab') ~DIFFER('a','a') 'tail'\n OUTPUT = '11:' SIZE('ab') (~DIFFER('a','a'))\n OUTPUT = '12:' SIZE('ab') ~SIZE('')\n OUTPUT = '13:' SIZE('ab') 'm' ~DIFFER('a','a')\n OUTPUT = '14:' ID('A') ~DIFFER('a','a')\n OUTPUT = '15:' ID('A') ~DIFFER('a','b')\nEND\n" > "$T/w.sno"
( cd "$T" && timeout -k 5 20s "$SBL" -bf w.sno </dev/null ) > "$T/w.ref" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the oracle refused its own witness -- no ref to grade against"; exit 2; }
[ "$(wc -l < "$T/w.ref")" -ge 12 ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced $(wc -l < "$T/w.ref") lines, expected at least 12"; exit 2; }
( cd "$T" && timeout -k 5 20s "$SCRIP" w.sno </dev/null > m3.out 2>/dev/null ); r=$?
if [ "$r" -eq 0 ] && cmp -s "$T/m3.out" "$T/w.ref"; then echo "  m3 PASS (rc=0, $(wc -l < "$T/w.ref") lines byte-identical to the oracle)"; else echo "  m3 FAIL (rc=$r; $(diff "$T/m3.out" "$T/w.ref" | grep -c '^[<>]') differing lines -- a value produced before a negation is lost)"; RC=1; fi
if "$SCRIP" --compile "$T/w.sno" -o "$T/w.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/w.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$T/w4" 2>"$T/ld.log"; then :; else echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link refused ($(head -c 200 "$T/ld.log"))"; exit 2; fi
( cd "$T" && timeout -k 5 20s ./w4 </dev/null > m4.out 2>/dev/null ); r=$?
if [ "$r" -eq 0 ] && cmp -s "$T/m4.out" "$T/w.ref"; then echo "  m4 PASS (rc=0, byte-identical to the oracle)"; else echo "  m4 FAIL (rc=$r; $(diff "$T/m4.out" "$T/w.ref" | grep -c '^[<>]') differing lines)"; RC=1; fi
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: a value produced before a negation reaches its consumer in both modes; 13 shapes byte-identical to the oracle (2 arms)"
else echo "⛔ GATE FAIL(1) [$G]: a planned producer's value is lost to a consumer outside its run (examined 2 arms)"; fi
exit $RC

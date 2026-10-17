#!/bin/bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ ROW icon-dump-zeta-segfaults-reading-a-non-string-union-member-as-a-pointer-in-the-zr-guard-arm (minted by hq_icon
# 2026-09-17, rooted with gdb; claimed and cured by the cto, whose rung-0 dump arm it was).  zls_reuse_dump's ZR_GUARD
# line printed the guard box's NAME by reading IR_LIT(guard).sval behind an op BLACKLIST (not straight, not IR_VAR),
# and IR_LIT is a union: IR_COERCE_NUMERIC passes the blacklist with integer data in the union, so gs came back
# 0x101000066 and gs[0] faulted -- 30 of 42 Icon benchmark programs SIGSEGV'd under --dump-zeta on 3afb59316 and the
# 4-line witness below (a binop with a VARIABLE operand; a literal operand does not coerce) reproduced it alone.
# The cure is a POSITIVE test (frame_layout.c zls_op_names_a_string): the call family, IR_MATCH_DEFER, IR_LIT_STRING,
# IR_VAR and IR_VAR_REF carry a string in the union; every other op prints its op name and no sval.
# ⛔ THE CLAIM IS HELD BY INSTRUMENTS: (1) the witness dumps rc=0 and its guard line names IR_COERCE_NUMERIC; (2) every
# Icon benchmark program under corpus/benchmarks/icon dumps with rc != 139; (3) a call guard still prints its NAME
# (micro.icn's IR_CALL_ICON guard, the whitelist keeps what the dump was for); (4) the Prolog and SNOBOL4 witnesses still dump.  zls_dump has one
# caller behind --dump-zeta (scrip.c), so nothing emitted moves and no frontend arm is owed.
# RED-BEFORE on 3afb59316: witness rc=139, 30 of 42 benchmarks rc=139.
# ⛔ REFUSES rc=2 when the benchmark population is empty.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
cd "$ROOT" || exit 2
CORPUS="$ROOT/../corpus"; [ -d "$CORPUS/benchmarks/icon" ] || { echo "⛔ REFUSE(2): no corpus/benchmarks/icon beside SCRIP"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf 'procedure main()\n  local s, t;\n  s := 0;\n  t := s + 1;\nend\n' > "$T/zw.icn"
bad=0
timeout -k 5 20s ./scrip --dump-zeta "$T/zw.icn" </dev/null > "$T/zw.dump" 2>/dev/null; rc=$?
echo "witness --dump-zeta rc=$rc (want 0; 139 before the cure)"
[ "$rc" -eq 0 ] || { echo "  ⛔ the witness does not dump"; bad=$((bad+1)); }
grep -qE 'PINNED guard: box @[0-9]+ IR_COERCE_NUMERIC can recede' "$T/zw.dump" || { echo "  ⛔ the witness's guard line does not name IR_COERCE_NUMERIC as the guard box"; bad=$((bad+1)); }
n=0; seg=0
for f in "$CORPUS"/benchmarks/icon/*.icn "$CORPUS"/benchmarks/icon/*/*.icn; do [ -f "$f" ] || continue; n=$((n+1)); timeout -k 5 60s ./scrip --dump-zeta "$f" </dev/null >/dev/null 2>&1; r=$?; [ "$r" -eq 139 ] && { seg=$((seg+1)); echo "  ⛔ SIGSEGV under --dump-zeta: $f"; }; done
echo "icon benchmarks: $n dumped, $seg segfault (30 of 42 before the cure)"
[ "$n" -gt 0 ] || { echo "⛔ REFUSE(2): the Icon benchmark population is empty"; exit 2; }
[ "$seg" -eq 0 ] || bad=$((bad+1))
timeout -k 5 20s ./scrip --dump-zeta ../harness/scripts/fixtures/frame_r1_witness.pl </dev/null > "$T/pl.dump" 2>/dev/null || { echo "  ⛔ the Prolog witness does not dump"; bad=$((bad+1)); }
timeout -k 5 60s ./scrip --dump-zeta "$CORPUS/reference/icon/icont-bench/micro.icn" </dev/null > "$T/micro.dump" 2>/dev/null
grep -qE 'PINNED guard: box @[0-9]+ IR_CALL_ICON [a-z_]+ can recede' "$T/micro.dump" || { echo "  ⛔ micro.icn's builtin-call guard no longer prints its name -- the whitelist dropped what the dump was for"; bad=$((bad+1)); }
printf "        S = 'abcabc'\n        S BREAK('c') . T\n        OUTPUT = T\nEND\n" > "$T/w.sno"
timeout -k 5 20s ./scrip --dump-zeta "$T/w.sno" </dev/null >/dev/null 2>&1 || { echo "  ⛔ the SNOBOL4 witness does not dump"; bad=$((bad+1)); }
if [ "$bad" -gt 0 ]; then echo "⛔ GATE FAIL: $bad finding(s)"; exit 1; fi
echo "GATE OK: the guard arm names only ops that carry a string -- the witness and all $n Icon benchmarks dump, a call guard still prints its name, Prolog and SNOBOL4 dump"

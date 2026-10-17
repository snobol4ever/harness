#!/usr/bin/env bash
# test_gate_a_program_with_more_functions_than_the_old_cell_table_held_compiles_and_runs.sh -- THE FUNCTION-CELL STORE HAS NO
# FIXED LIMIT (row compiler-every-population-table-grows-in-the-compile-time-arena-through-ct-grow-no-fixed-limit-a-program-can-reach;
# hq_snocone's ask 2026-09-25: 27 of 129 Raku corpus sources died in the parser_raku.sc chain on "FATAL bb_ab_slot_for: cell table
# full (1024) at 'alpha$EXPR$2205$g_infix__x7ex5e'", because the chain's runtime compiles one cell per deferred grammar rule).
#
# THE DEFECT: emit.cpp kept the call cells a procedure call jumps through (alpha$F, entry$F, F) in g_ab_fn_cells[AB_FNCELL_MAX=1024]
# with names in g_ab_fn_names[1024][64], so a program with more than about 512 DEFINEs aborted in mode 3 (two cells each) and more
# than about 1024 in mode 4, and two names sharing a 63-character prefix could share one cell.
# THE CURE: cells live in 1024-cell chunks allocated once in the compile-time arena and never moved (their addresses are baked into
# emitted code as movabs immediates), under a growable chunk directory; names are full copies, and the name index is an open-addressed
# table that doubles at half load (SCRIP_AB_HASH=0 keeps the linear scan).
#
# ARM 1: 1100 DEFINEs, each called once, print what sbl -bf prints in mode 3 and in mode 4 (compile, link, run).
# ARM 2 (RETIRED 2026-09-26 with SCRIP_AB_HASH, CEO-1274 (2)): the same program under the linear-scan lookup printed the same in mode 3.
# FAIL-ONCE: SCRIP_BIN may name another tree's scrip (its out/ is used for mode 4). On the parent of the cure (origin 2c9e07a9d) arm 1
# reads RED in both modes: m3 rc=134 "cell table full (1024) at 'entry$F512'", m4 compile rc=134 at 'entry$F1024'.
# rc 0 GREEN · 1 RED (named) · 2 REFUSE (cannot measure).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
TREE="$(cd "$(dirname "$SCRIP")" && pwd)"; LIBDIR="$TREE/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no correctness oracle ($SBL) -- the ref is cut from the oracle at run time, never typed"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
export SNO_LIB="${SNO_LIB:-$ROOT/../corpus/include}"
python3 -c "
n = 1100; L = []
for i in range(n): L += ['\tDEFINE(\'F%d(X)\')\t:(F%d_END)' % (i, i), 'F%d\tF%d = X + %d\t:(RETURN)' % (i, i, i), 'F%d_END' % i]
L.append('\tS = 0'); L += ['\tS = S + F%d(1)' % i for i in range(n)]; L += ['\tOUTPUT = S', 'END']
open('$T/w.sno', 'w').write('\n'.join(L) + '\n')" || { echo "⛔ GATE REFUSE(2) [$G]: could not write the witness"; exit 2; }
( cd "$T" && timeout -k 5 60 "$SBL" $(sbl_lang_flags) w.sno < /dev/null > w.ref 2> /dev/null )
[ -s "$T/w.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for the witness"; exit 2; }
RC=0; red=""
( cd "$T" && timeout -k 5 120 "$SCRIP" w.sno < /dev/null > m3.out 2> m3.err ); r3=$?
cmp -s "$T/m3.out" "$T/w.ref" && [ "$r3" = 0 ] || red="$red m3(rc=$r3 $(head -c 90 "$T/m3.err" | tr '\n' ' '))"
( cd "$T" && timeout -k 5 180 "$SCRIP" --compile -o w.s w.sno < /dev/null > /dev/null 2> c4.err ); rc4=$?
if [ "$rc4" = 0 ] && ( cd "$T" && gcc w.s -o w.bin -L"$LIBDIR" -lscrip_rt -lm -lpthread -Wl,-rpath,"$LIBDIR" 2> /dev/null ); then
    ( cd "$T" && timeout -k 5 60 ./w.bin < /dev/null > m4.out 2> m4.err ); r4=$?
    cmp -s "$T/m4.out" "$T/w.ref" && [ "$r4" = 0 ] || red="$red m4(rc=$r4 $(head -c 90 "$T/m4.err" | tr '\n' ' '))"
else red="$red m4-compile(rc=$rc4 $(head -c 90 "$T/c4.err" | tr '\n' ' '))"; fi
if [ -z "$red" ]; then echo "  arm 1 PASS: 1100 DEFINEs print '$(cat "$T/w.ref")' like sbl -bf in mode 3 and mode 4 -- the call cells grow past the old 1024-cell table"
else echo "  arm 1 RED:$red -- a program with more functions than a fixed cell table holds did not compile or run"; RC=1; fi
echo "  arm 2 RETIRED with SCRIP_AB_HASH (cto 2026-09-26, CEO-1274 (2)): the linear-scan lookup it exercised is deleted; the hashed lookup is the only lookup and arm 1 grades it"
if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$G]: the function-cell store grows with the program (2 arms)"
else echo "GATE FAIL(1) [$G]: a program with more functions than the old cell table held fails (2 arms)"; fi
echo "    tree: SCRIP=$(git -C "$TREE" rev-parse --short HEAD 2>/dev/null)$(git -C "$TREE" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC

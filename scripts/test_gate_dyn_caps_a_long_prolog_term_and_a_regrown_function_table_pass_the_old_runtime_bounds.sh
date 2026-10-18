#!/usr/bin/env bash
# test_gate_dyn_caps_a_long_prolog_term_and_a_regrown_function_table_pass_the_old_runtime_bounds.sh -- the fixed-tables row's
# runtime batch 2 (cfo 2026-10-04, no-more-whack-a-mole-every-fixed-table-a-program-can-fill-is-converted-in-one-pass-...).
#
# MEASURED 2026-10-04 on SCRIP d86f708d0: read/1 and read_term/2 read a term's text into a static char text[65536], so a term
# of 65528 characters or more raised syntax_error(term_too_long) where swipl reads it (a 70000-character quoted atom: swipl
# 70000, scrip the ball). CURE: pl_read_term_text grows its buffer on the collected heap as it reads (no collection runs
# inside the leaf; the buffer is garbage after the read). The function table's 128 static buckets (restored at dd42f8c28
# after a GC-heap bucket vector broke SncBench parser_icon) now grow in slab memory -- non-moving and never collected, like
# the static array -- so 4100 run-time functions regrow it past its first 4096 buckets; arm B grades that against sbl, also under SCRIP_GC_PLANT_SHIFT
# (every live block forwarded at every collection), the plant that showed the heap-resident vector was the defect.
# Arms, each in m3 and m4: A a 70000-character atom through read/1 and a 200000-character one through read_term/2, value
# equal to swipl's; B 4100 functions defined at run time through CODE (127 builtins + 4100 > the first table of 4096 buckets, so the table regrows) called through APPLY and directly, stream byte-identical to sbl -bf, and m4 again under
# the flip plant. FAIL_ONCE=1 corrupts arm A's reading.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ REFUSE(2): no sbl at $SBL"; exit 2; }
SWIPL="$(command -v swipl || true)"; [ -n "$SWIPL" ] || { echo "⛔ REFUSE(2): no swipl -- arm A's expected value is cut from it"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
python3 - "$T" <<'EOF'
import sys
d = sys.argv[1]
open(d + '/a.txt', 'w').write("'" + "a" * 70000 + "'.\n")
open(d + '/b.txt', 'w').write("'" + "b" * 100000 + "\\x41\\" + "c" * 99999 + "'.\n")
open(d + '/r.pl', 'w').write(":- initialization(main).\nmain :- open('a.txt', read, S), read(S, A), close(S), atom_length(A, L1),\n"
    "  open('b.txt', read, S2), read_term(S2, B, []), close(S2), atom_length(B, L2), atom_codes(B, Cs), nth0(100000, Cs, K), char_code(C, K),\n"
    "  write(L1), nl, write(L2), nl, write(C), nl, halt.\n")
with open(d + '/f.sno', 'w') as f:
    f.write("        i = 0\nmk      C = CODE(\" DEFINE('f\" i \"(x)') :(e\" i \");f\" i \" f\" i \" = x + \" i \" :(RETURN);e\" i \" :(BACK)\")   :F(bad)\n"
            "                                                         :<C>\nBACK    i = i + 1\n        LT(i, 4100)          :S(mk)\n"
            "        s = 0\n        i = 0\nlp      s = s + APPLY('f' i, 1)\n        i = i + 1\n        LT(i, 4100)          :S(lp)\n"
            "        OUTPUT = s\n        OUTPUT = f4099(1) ' ' f0(1) ' ' f2048(5)          :(END)\nbad     OUTPUT = 'CODE failed at ' i\nEND\n")
EOF
( cd "$T" && "$SWIPL" -q r.pl </dev/null ) > "$T/r.ref" 2>/dev/null; ( cd "$T" && "$SBL" -bf f.sno </dev/null ) > "$T/f.ref" 2>&1
[ "$(tr '\n' ';' < "$T/r.ref")" = "70000;200000;A;" ] || { echo "⛔ REFUSE(2): swipl's reading is not the one this gate was cut on: $(tr '\n' ';' < "$T/r.ref")"; exit 2; }
[ "$(tr '\n' ';' < "$T/f.ref")" = "8407050;4100 1 2053;" ] || { echo "⛔ REFUSE(2): sbl's stream is not the one this gate was cut on"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m4 ]; then for W in r f; do ext=pl; [ $W = f ] && ext=sno; ( cd "$T" && "$SCRIP" --compile -o $W.s $W.$ext </dev/null && gcc $W.s -o $W.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness $W did not build"; exit 2; }; done; fi
  run() { if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 120 "$SCRIP" "$1" </dev/null ); else ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 120 "./${1%.*}.bin" </dev/null ); fi; }
  ra=$(run r.pl 2>/dev/null | tr '\n' ';'); [ -n "${FAIL_ONCE:-}" ] && ra="65528;$ra"
  if [ "$ra" = "70000;200000;A;" ]; then echo "  $M arm A PASS (read/1 70000, read_term/2 200000 with its escape, as swipl)"; else echo "  $M arm A FAIL (got '$ra', swipl 70000;200000;A;)"; RC=1; fi
  rb=$(run f.sno 2>&1 | tr '\n' ';')
  if [ "$rb" = "8407050;4100 1 2053;" ]; then echo "  $M arm B PASS (4100 run-time functions past the first table, byte-identical to sbl)"; else echo "  $M arm B FAIL (got '$(echo "$rb" | cut -c1-120)')"; RC=1; fi
done
rs=$( cd "$T" && SCRIP_HEAP_KB=1024 SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_STRESS=3 LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 300 ./f.bin </dev/null 2>"$T/shift.err" | tr '\n' ';' )
grep -q '^\[GC-FLIP\] plant:' "$T/shift.err" || { echo "  m4 arm B under the flip plant FAIL (the plant printed no applied banner, so nothing moved)"; RC=1; }
if [ "$rs" = "8407050;4100 1 2053;" ]; then echo "  m4 arm B under SCRIP_GC_PLANT_FLIP=1 PASS"; else echo "  m4 arm B under the flip plant FAIL (got '$(echo "$rs" | cut -c1-120)')"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: a term past the old read buffer and 4100 run-time functions past the first function table read and run as the oracles do"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: an old runtime bound still cuts a program"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracles: $SWIPL, $SBL  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC

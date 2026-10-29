#!/usr/bin/env bash
# test_gate_icn_alternation_beyond_32_arms.sh -- an alternation with more than 32 arms delivers every arm's own value (ceo CEO-632).
#
# MEASURED 2026-09-12 on 26bbc4c6f: `every write("s1" | ... | "s34")` printed s32 for arms 33 and 34 in BOTH modes -- a silently
# wrong value -- and inside a co-expression the same arms came out &null (IPL's fileprnt: a 33-way `create "NUL" | ... | " SP"`
# read &null on its 33rd activation and raised error 103 in `&null || "|"`). The emitter's template context carried a fixed
# op_parts_ival[32] that the disjunction box indexes per arm (the fill loop stopped at 32 while op_parts_n said N), and
# lower_alt_impl capped the arm list at 64. Cure: the parts table is growable (emit_parts_reserve, the two writers reserve N),
# and the lowerer sizes its arm list by n. Arms: a 40-way alternation plain and inside a co-expression, both modes, byte-identical
# to icont; FAIL_ONCE=1 corrupts the 33rd line of the captured stream to prove the diff arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
alts=""; for i in $(seq 1 40); do alts="$alts | \"s$i\""; done; alts="${alts# | }"
cat > "$T/a.icn" <<ICN
procedure main()
   local g, c, n;
   every write("plain ", $alts);
   g := create $alts;
   n := 0;
   every c := 1 to 42 do { n +:= 1; write("coex ", n, " ", image(@g) | "failed") };
end
ICN
( cd "$T" && "$ICONT" -s a.icn -x ) >"$T/a.ref" 2>&1 || { echo "⛔ REFUSE(2): the oracle itself did not run the witness"; exit 2; }
grep -q '^plain s33$' "$T/a.ref" || { echo "⛔ REFUSE(2): the oracle's own stream lacks 'plain s33' -- this gate is asserting the wrong thing, or the oracle moved"; exit 2; }
grep -q '^coex 40 "s40"$' "$T/a.ref" || { echo "⛔ REFUSE(2): the oracle's own stream lacks the 40th co-expression result"; exit 2; }
[ "$(grep -c . "$T/a.ref")" = 82 ] || { echo "⛔ REFUSE(2): the oracle's stream is not the 82 lines two 40-way arms plus two exhaustions produce"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" a.icn </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile --out=a.s a.icn </dev/null && gcc a.s -o a.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./a.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i 's/^plain s33$/plain s32/' "$T/$M.out"; fi
  if diff -u "$T/a.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS (byte-identical to icont, 40 arms plain + in a co-expression)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,14p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: every arm of a 40-way alternation delivers its own value, plain and through a co-expression (2 shapes x 2 modes)"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: an arm beyond the 32nd does not deliver its own value (examined 2 shapes x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC

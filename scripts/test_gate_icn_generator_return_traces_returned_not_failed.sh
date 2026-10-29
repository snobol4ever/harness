#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the instrumentation switch (--stlimit): Icon &trace rides the call/return hooks that are off by default since SCRIP 2026-09-24 (Lon: monitor hooks behind the switch)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/g.icn" <<'ICN'
procedure gen3();
  suspend 1;
  return 3;
end
procedure main();
  &trace := -1;
  every write(gen3() \ 2);
end
ICN
( cd "$T" && "$ICONT" -s g.icn -x ) >"$T/g.ref" 2>&1 || { echo "⛔ REFUSE(2): the oracle itself did not run the witness"; exit 2; }
grep -q 'gen3 returned 3' "$T/g.ref" || { echo "⛔ REFUSE(2): the oracle's own stream carries no 'gen3 returned 3' -- this gate is asserting the wrong thing, or the oracle moved"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" g.icn </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile --out=g.s g.icn </dev/null && gcc g.s -o g.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./g.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i 's/gen3 returned 3/gen3 failed/' "$T/$M.out"; fi
  if diff -u "$T/g.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS (byte-identical to icont)"
  else echo "  $M FAIL ($(grep -c '^[<>]' "$T/$M.diff") diff lines)"; sed -n '1,12p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: a return reached after a RESUME traces 'gen3 returned 3', both modes, byte-identical to icont over 1 witness x 2 modes"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: a return on a resumed activation does not trace 'NAME returned VALUE' (examined 1 witness x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC

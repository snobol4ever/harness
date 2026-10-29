#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the instrumentation switch (--stlimit): Icon &trace rides the call/return hooks that are off by default since SCRIP 2026-09-24 (Lon: monitor hooks behind the switch)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/v.icn" <<'ICN'
procedure main();
   local s, t, r, n;
   &trace := -1;
   s := "abc";
   every gs(s);
   t := table(); t["k"] := 7;
   every gt(t);
   r := [2,3];
   every gr(r);
   n := 5;
   every gl(n);
end
procedure gs(x); suspend !x; end
procedure gt(x); suspend !x; end
procedure gr(x); suspend !x; end
procedure gl(x); suspend x; end
ICN
( cd "$T" && "$ICONT" -s v.icn -x ) >"$T/v.ref" 2>&1 || { echo "⛔ REFUSE(2): the oracle itself did not run the witness"; exit 2; }
for want in 'gr suspended (variable = 2)' 'gt suspended table_1(1)["k"]' 'gs suspended "a"' 'gl suspended 5'; do
  grep -qF "$want" "$T/v.ref" || { echo "⛔ REFUSE(2): the oracle's own stream carries no '$want' -- this gate is asserting the wrong thing, or the oracle moved"; exit 2; }
done
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" v.icn </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile --out=v.s v.icn </dev/null && gcc v.s -o v.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./v.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i 's/gr suspended (variable = 2)/gr suspended 2/' "$T/$M.out"; fi
  if diff -u "$T/v.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS (byte-identical to icont)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,14p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: a suspend of a list element images (variable = V), a table element table_1(1)[k], a string element and a local their plain value -- 4 renderings x 2 modes, byte-identical to icont"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: a traced suspend does not image the VARIABLE it produced (examined 4 renderings x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC

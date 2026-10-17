#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/b.icn" <<'ICN'
procedure main();
   local b, s;
   b := [1,2,3];
   every vproc(b) := 0;
   every write("elem ", !b);
   write("sum ", vproc(b) + 10);
   write("cat ", "x" || vproc(b));
   write("img ", image(vproc(b)));
   s := vproc(b);
   write("asn ", s);
end
procedure vproc(x); suspend !x; end
ICN
( cd "$T" && "$ICONT" -s b.icn -x ) >"$T/b.ref" 2>&1 || { echo "⛔ REFUSE(2): the oracle itself did not run the witness"; exit 2; }
grep -q '^elem 0$' "$T/b.ref" || { echo "⛔ REFUSE(2): the oracle's own stream does not show the assign-through storing 0 -- this gate is asserting the wrong thing, or the oracle moved"; exit 2; }
grep -q '^sum 10$' "$T/b.ref" || { echo "⛔ REFUSE(2): the oracle's own stream carries no 'sum 10' -- the rvalue control arm cannot be graded"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" b.icn </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile -o b.s b.icn </dev/null && gcc b.s -o b.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./b.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i 's/^elem 0$/elem 1/' "$T/$M.out"; fi
  if diff -u "$T/b.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS (byte-identical to icont)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,14p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: a variable survives a procedure suspend -- every vproc(b) := 0 assigns THROUGH the suspended list element, while the same call in rvalue position still yields the VALUE to arithmetic, concatenation, image and a plain assignment; 2 modes, byte-identical to icont"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: a variable does not survive the procedure suspend boundary, or the rvalue dereference was lost with it (examined 5 arms x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC

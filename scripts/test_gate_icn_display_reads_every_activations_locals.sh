#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/d1.icn" <<'ICN'
procedure main()
   outer(7, 8);
end
procedure outer(p, q)
   local a, b, c, d;
   a := 11; b := 22; c := 33; d := 44;
   inner(1);
   return;
end
procedure inner(k)
   local r, s;
   static t;
   r := "sixteen chars ok, this one is longer";
   s := [1, 2, [3, 4]];
   t := 99;
   display(3, &output);
   return;
end
ICN
cat > "$T/d1.want" <<'WANT'
co-expression_1(1)

inner local identifiers:
   k = 1
   r = "sixteen chars ok..."
   s = list_2 = [1,2,list_1(2)]
   t = 99
outer local identifiers:
   p = 7
   q = 8
   a = 11
   b = 22
   c = 33
   d = 44
main local identifiers:

global identifiers:
   display = function display
   inner = procedure inner
   main = procedure main
   outer = procedure outer
WANT
fail=0
( cd "$T" && timeout -k 5 60 "$SCRIP" d1.icn </dev/null > d1.m3 2>&1 ); rc3=$?
if [ "$rc3" = 0 ] && cmp -s "$T/d1.m3" "$T/d1.want"; then echo "  PASS  m3 d1: three activations, their locals, a static, an elided string and a nested list"; else echo "  FAIL  m3 d1 rc=$rc3"; diff "$T/d1.want" "$T/d1.m3" | head -12 | sed 's/^/        /'; fail=1; fi
( cd "$T" && timeout -k 5 60 "$SCRIP" --trace d1.icn </dev/null > d1.tr 2>/dev/null ); rct=$?
grep -v '^\*\*\*\*' "$T/d1.tr" > "$T/d1.trd"
if [ "$rct" = 0 ] && cmp -s "$T/d1.trd" "$T/d1.want"; then echo "  PASS  m3 d1 --trace: the lowerer's __trace_* taps are monitor artifacts and stay out of display's global identifiers"; else echo "  FAIL  m3 d1 --trace rc=$rct (the statement trace lines removed, display must read as without --trace)"; diff "$T/d1.want" "$T/d1.trd" | head -12 | sed 's/^/        /'; fail=1; fi
if [ "$fail" = 0 ]; then echo "✅ PASS: display reads every displayed activation's locals from their own frame slots"; exit 0; fi
echo "⛔ FAIL: display lost an activation's locals (see the FAIL rows)"; exit 1

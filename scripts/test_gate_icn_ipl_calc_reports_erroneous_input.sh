#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the refs are CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
PROGS="$ROOT/../corpus/packages/icon/ipl/progs"
for f in calc.icn calc.dat calc.ref; do [ -f "$PROGS/$f" ] || { echo "⛔ REFUSE(2): $PROGS/$f is missing -- this gate cannot measure the class it names"; exit 2; }; done
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cp "$PROGS/calc.icn" "$PROGS/calc.dat" "$PROGS/calc.ref" "$T/" || exit 2
grep -q 'erroneous input' "$T/calc.ref" || { echo "⛔ REFUSE(2): calc.ref no longer carries an 'erroneous input' line -- the fixture moved and this gate is asserting the wrong thing"; exit 2; }
cat > "$T/contract.icn" <<'ICN'
global gv
procedure helper(x); return x; end
procedure main()
   local lv, r, s;
   lv := 7; gv := 9; s := "the quick brown fox";
   every s2 := "gv" | "&pi" | "nosuchname" | "" | "helper" | "write" do {
      if r := variable(s2) then write("variable(", image(s2), ") -> ", image(r)) else write("variable(", image(s2), ") -> FAILED");
      };
   if r := variable(s) then write("variable(via local) -> ", image(r)) else write("variable(via local) -> FAILED");
   every s3 := "12 7 93 7 12" | "1 2" | "0x1f" | "12 " | " 12 " | "12" | "3.5" | "3.5.6" | "1e3" | "+5" | "-5" | "12abc" | "" | "  " | "16r1f" do {
      if r := numeric(s3) then write("numeric(", image(s3), ") -> ", image(r)) else write("numeric(", image(s3), ") -> FAILED");
      };
end
ICN
( cd "$T" && "$ICONT" -s contract.icn -x ) >"$T/contract.ref" 2>&1 || { echo "⛔ REFUSE(2): the oracle itself did not run the contract witness"; exit 2; }
nf=$(grep -c -- '-> FAILED' "$T/contract.ref"); nv=$(grep -c -- '-> [^F]' "$T/contract.ref")
[ "$nf" -ge 10 ] && [ "$nv" -ge 8 ] || { echo "⛔ REFUSE(2): the oracle's own stream no longer carries both outcomes -- FAILED=$nf (want >=10) value=$nv (want >=8); a gate that sees only refusals is satisfied by a variable()/numeric() that never succeeds"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 30 "$SCRIP" calc.icn < calc.dat ) >"$T/calc.$M" 2>&1
                          ( cd "$T" && timeout -k 5 30 "$SCRIP" contract.icn </dev/null ) >"$T/contract.$M" 2>&1
  else ( cd "$T" && timeout -k 5 30 "$SCRIP" --compile --out=calc.s calc.icn </dev/null && gcc -m64 -no-pie calc.s -o calc.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread \
                 && timeout -k 5 30 "$SCRIP" --compile --out=contract.s contract.icn </dev/null && gcc -m64 -no-pie contract.s -o contract.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 \
         || { echo "⛔ REFUSE(2): a mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 30 ./calc.bin < calc.dat ) >"$T/calc.$M" 2>&1
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 30 ./contract.bin </dev/null ) >"$T/contract.$M" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i '5d' "$T/calc.$M"; sed -i 's/^variable("nosuchname") -> FAILED/variable("nosuchname") -> \&null/' "$T/contract.$M"; fi
  for pair in "calc.ref:calc.$M:calc.icn against its own .ref" "contract.ref:contract.$M:the variable()/numeric() contract against icont"; do
    want="${pair%%:*}"; rest="${pair#*:}"; got="${rest%%:*}"; what="${rest#*:}"
    if diff -q "$T/$want" "$T/$got" >/dev/null; then echo "  $M PASS -- $what"
    else echo "  $M FAIL ($(diff -u "$T/$want" "$T/$got" | grep -c '^[-+][^-+]') diff lines) -- $what"; diff -u "$T/$want" "$T/$got" | sed -n '3,12p' | sed 's/^/      /'; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: calc.icn reports every unparseable line, and variable() fails on a name that is not in scope while numeric() rejects trailing garbage and C hex -- 2 witnesses x 2 modes, byte-identical to the oracle"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: calc.icn is silent where iconx reports erroneous input, or variable()/numeric() accepts what the oracle refuses"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC

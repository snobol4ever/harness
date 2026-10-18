#!/usr/bin/env bash
# test_gate_icn_integer_and_real_refuse_a_c_hex_string.sh -- integer("0x10") and real("0x1p4") FAIL, as under icont (ceo CEO-640).
#
# MEASURED 2026-09-12 on bebf6df1a (the adversarial batch, Lon: "Try to break it"): integer("0x10") answered 16 in both modes
# where icont fails -- numeric() already refused a C-hex string through icn_numeric_is_c_hex, but integer() and real() fell
# through their radix and strtoll paths to strtod, which parses C hex floats. Cure: both refuse a C-hex string before strtod.
# Arms: one witness with integer("0x10"), real("0x1p4"), numeric("0x10"), the legal radix form "16r10", and "0x10" as a plain
# string, byte-identical to icont in both modes. FAIL_ONCE=1 corrupts the captured stream to prove the diff arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/h.icn" <<'ICN'
procedure main()
   write(integer("0x10") | "int-fails", " ", real("0x1p4") | "real-fails", " ", numeric("0x10") | "num-fails");
   write(integer("16r10"), " ", real("16r10"), " ", integer(" 0X1F ") | "upper-fails", " ", integer("0x") | "bare-fails");
   write("0x10" == "0x10", " ", integer("010"), " ", real("1e1"), " ", integer("-0x1") | "neg-fails", " ", numeric("0b1") | "b-fails");
end
ICN
( cd "$T" && "$ICONT" -s h.icn -x ) >"$T/h.ref" 2>&1 || { echo "⛔ REFUSE(2): the oracle itself did not run the witness"; exit 2; }
grep -q '^int-fails real-fails num-fails$' "$T/h.ref" || { echo "⛔ REFUSE(2): the oracle's own stream does not refuse the C-hex strings -- this gate is asserting the wrong thing, or the oracle moved"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" h.icn </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile -o h.s h.icn </dev/null && gcc h.s -o h.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./h.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i 's/^int-fails /16 /' "$T/$M.out"; fi
  if diff -u "$T/h.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS (byte-identical to icont)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,10p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: integer, real and numeric refuse C-hex strings and keep the radix forms, as icont does (3 lines x 2 modes)"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: a C-hex string converts where icont refuses it (examined 3 lines x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC

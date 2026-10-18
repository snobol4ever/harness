#!/usr/bin/env bash
# test_gate_icn_find_takes_negative_positions.sh -- find(s1, s2, i, j) normalizes negative and zero positions like its siblings (ceo CEO-644).
#
# MEASURED 2026-09-12 on 3de7f285d (the adversarial batch): find("a", "banana", -3) FAILED in both modes where icont answers 4;
# upto/many/match/any/bal with negative positions all agreed with icont. The by-name find branch carried its own position
# logic (i1 <= 0 -> fail; i2 <= 0 -> end) instead of bn_str_anal, the normalizer every sibling calls (negative positions
# count from the right, 0 is the end, i and j are ordered). Cure: find calls bn_str_anal with carried lengths and memcmp.
# Arms: first-result and generator forms over negative i, negative j, both negative, zero, reversed order, and inside a
# scan; byte-identical to icont in both modes. FAIL_ONCE=1 corrupts the captured stream to prove the diff arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/f.icn" <<'ICN'
procedure main()
   local s;
   s := "banana";
   write(find("a", s, -3) | "f1", " ", find("a", s, 1, -2) | "f2", " ", find("a", s, -5, -1) | "f3", " ", find("a", s, 0) | "f4", " ", find("a", s, 5, 2) | "f5");
   every writes(find("a", s, -4), " "); write();
   every writes(find("na", s, 1, -1), " "); write();
   every writes(find("a", s, -1, 3), " "); write();
   s ? { tab(3); write(find("a") | "f6", " ", find("a", &subject, -2) | "f7", " ", &pos); };
   write(find("", s, -1) | "f8", " ", find("x", s, -6) | "f9", " ", find("b", s, -6, -5) | "f10");
end
ICN
( cd "$T" && "$ICONT" -s f.icn -x ) >"$T/f.ref" 2>&1 || { echo "⛔ REFUSE(2): the oracle itself did not run the witness"; exit 2; }
grep -q '^4 2 2 f4 2$' "$T/f.ref" || { echo "⛔ REFUSE(2): the oracle's own first line is not the position row this gate pins -- the oracle moved: $(head -1 "$T/f.ref")"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" f.icn </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile -o f.s f.icn </dev/null && gcc f.s -o f.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./f.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i '1s/^4 /f1 /' "$T/$M.out"; fi
  if diff -u "$T/f.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS (byte-identical to icont, 6 lines)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,10p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: find takes negative, zero and reversed positions like its siblings, first-result and generator forms, in both modes"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: find with a negative or zero position does not answer as icont does (examined 6 lines x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC

#!/usr/bin/env bash
# test_gate_icn_a_string_with_an_embedded_nul_subscripts_by_its_length.sh -- a string is subscripted by its CARRIED length (ceo CEO-641).
#
# MEASURED 2026-09-12 on 969a4bc89 (the adversarial batch, Lon: "Try to break it"): string(&cset) is 256 characters and
# *string(&cset) read 256, but string(&cset)[255] and [256] FAILED in both modes where icont answers "\xfe" and "\xff",
# and image(&cset[256]) was dropped from the same write. The string begins with char(0): subscript_get_s in
# pattern_match.c measured a plain string with strlen. RULES.md: no strlen on a descriptor's .s -- the length is carried,
# NUL is a valid string element (test_gate_sno_cset_from_a_string_view_uses_its_length.sh pins the SNOBOL4 side). Cure: the
# subscript takes the descriptor's slen when it carries one. Arms: string(&cset) subscripted at 1, 2, 255, 256, sectioned
# across the NUL, &cset[256], a literal with an embedded NUL, and *string(&cset) -- byte-identical to icont in both modes.
# FAIL_ONCE=1 corrupts the captured stream to prove the diff arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/n.icn" <<'ICN'
procedure main()
   local s;
   s := string(&cset);
   write(*s, " ", image(s[1]), " ", ord(s[2]), " ", image(s[255]) | "f255", " ", image(s[256]) | "f256");
   write(image(s[254:0]) | "fsect", " ", *s[1:3], " ", image(s[-1]), " ", image(&cset[256]) | "fcset");
   s := "a" || char(0) || "b";
   write(*s, " ", image(s[3]) | "f3", " ", image(s[2:0]), " ", image(reverse(s)), " ", image(s[2]));
end
ICN
( cd "$T" && "$ICONT" -s n.icn -x ) >"$T/n.ref" 2>&1 || { echo "⛔ REFUSE(2): the oracle itself did not run the witness"; exit 2; }
grep -q '^256 "\\x00" 1 "\\xfe" "\\xff"$' "$T/n.ref" || { echo "⛔ REFUSE(2): the oracle's own first line is not the 256-character subscript row -- this gate is asserting the wrong thing, or the oracle moved: $(head -1 "$T/n.ref")"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" n.icn </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile --out=n.s n.icn </dev/null && gcc n.s -o n.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./n.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i 's/"\\xfe" "\\xff"$/f255 f256/' "$T/$M.out"; fi
  if diff -u "$T/n.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS (byte-identical to icont, 3 lines)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,10p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: a string with an embedded NUL subscripts and sections by its carried length in both modes"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: a subscript past an embedded NUL fails or answers wrongly (examined 3 lines x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC

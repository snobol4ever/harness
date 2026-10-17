#!/usr/bin/env bash
# test_gate_icn_string_escapes_match_icont_including_unknown_and_uppercase.sh -- every one-character escape in an Icon string or cset literal means what icont says it means: recognized letters are case-insensitive, \8 and \9 are their digit values, \x is hex but \X is not, and an UNRECOGNIZED escape is the character itself with the backslash dropped (ceo CEO-665).
#
# MEASURED 2026-09-13 on 24f1ec353, found by the image-leak row's own oracle-diff arm: "q\y" imaged as "q\\y" where
# icont says "qy" -- our lexer's default arm KEPT the backslash for an escape it did not recognize, where icont's
# esctab maps an unknown escape to the character itself. Two more defects fell out of the same sweep: the uppercase
# forms \T \N \B \R \V \F \E \D \L were all unrecognized (icont accepts them, its table is case-insensitive), and \X
# was treated as a hex escape though icont's hex escape is lowercase \x only, so "\X" read 0 instead of 'X'.
# THE REF IS THE ORACLE ITSELF: this gate GENERATES a witness that takes ord() of \<c> for every printable c (bar the
# four that cannot be written bare: " \ ' ^), plus a cset literal, an image() of a mixed string, and the multi-char
# escapes \^A \101 \x41, and diffs the whole stream against icont in both modes. FAIL_ONCE=1 corrupts the first line.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ GATE REFUSE(2) [$G]: no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
python3 - "$T/e.icn" <<'PY'
import sys
chars=[c for c in map(chr,range(33,127)) if c not in '"\\\'^']
lines=["procedure main()"]
for c in chars: lines.append('   writes(ord("\\%s"), " ");' % c)
lines += ['   write();',
          '   writes(*\'\\y\\T\\q\', " ");',
          '   write(image("mix\\Q\\t\\N\\8\\9end"));',
          '   write(image("ctl\\^A oct\\101 hex\\x41"));',
          '   write(image("q\\y"), " ", image("a\\zb"), " ", image("\\\\"));',
          "end"]
open(sys.argv[1],'w').write("\n".join(lines)+"\n")
PY
[ -s "$T/e.icn" ] || { echo "⛔ GATE REFUSE(2) [$G]: could not generate the witness"; exit 2; }
( cd "$T" && "$ICONT" -s e.icn -x ) >"$T/e.ref" 2>&1
grep -q '^33 35' "$T/e.ref" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle's first line is not the ord sweep this gate pins -- the oracle moved: $(head -c 80 "$T/e.ref")"; exit 2; }
grep -q '"qy"' "$T/e.ref" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle no longer drops the backslash of an unknown escape -- re-derive the table before trusting this gate"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 30 "$SCRIP" e.icn </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && timeout -k 5 30 "$SCRIP" --compile -o e.s e.icn </dev/null && gcc e.s -o e.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 30 ./e.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i '1s/^33 /34 /' "$T/$M.out"; fi
  if diff -u "$T/e.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS (90 single-char escapes + csets + multi-char forms, byte-identical to icont)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,10p' "$T/$M.diff" | cut -c1-200 | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: Icon string and cset escapes agree with icont, unknown and uppercase forms included, in both modes"
else echo "GATE FAIL(1) [$G]: an Icon escape disagrees with icont (examined 2 modes over every printable escape)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC

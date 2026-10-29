#!/usr/bin/env bash
# test_gate_pas_a_character_string_is_never_empty.sh -- '' is not an ISO 7185 character-string (6.1.7), and a program that writes one is refused
#
# MEASURED 2026-09-25 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. PAT iso7185prt1841 (writeln(''))
# read "accepted": the lexer's string rule took '' as an empty STRINGCONST. ISO 7185 6.1.7 builds a character-string from ONE OR MORE
# string-elements, so '' is not one. The cure is the lexer's own rule: a quoted literal with no string-element reports 6.1.7 and counts
# an ISO error, and the parse goes on so every such literal is named. Four FPC-suite programs fpc -Miso accepts write '' and are graded
# as ISO expected refusals under CEO-1228 (corpus/packages/pascal/fpc_tests/ISO_EXPECTED_REFUSALS.tsv).
#
# ARMS: the vendored PAT witness refused with a 6.1.7 diagnostic in BOTH modes (m4: --compile refuses); and a legal control cut LIVE
# from fpc -Miso and byte-identical in both modes -- '''' (one apostrophe), 'it''s', a one-char string and a string beside a char, so a
# check that miscounted the doubled apostrophe would refuse a legal program. FAIL_ONCE=1 corrupts the control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- the control arm's ref is CUT FROM THE ORACLE"; exit 2; }
W="$S4E/corpus/packages/pascal/pat/iso7185prt1841.pas"; [ -f "$W" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $W"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
e3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$W" </dev/null 2>&1 >/dev/null ); r3=$?
e4=$( cd "$T" && timeout -k 5 10s "$SCRIP" --compile --out="$T/w.s" "$W" </dev/null 2>&1 >/dev/null ); r4=$?
if [ "$r3" -ne 0 ] && [ "$r3" -lt 124 ] && [ "$r4" -ne 0 ] && [ "$r4" -lt 124 ] && printf '%s' "$e3" | grep -q 'ISO 7185 6\.1\.7' && printf '%s' "$e4" | grep -q 'ISO 7185 6\.1\.7'; then
     echo "  witness iso7185prt1841: refused naming ISO 7185 6.1.7 in both modes"
else echo "  ⛔ witness iso7185prt1841 ACCEPTED or refused without 6.1.7: m3 rc=$r3, m4 rc=$r4"; echo "      m3 err: $(printf '%s' "$e3" | head -1 | cut -c1-140)"; RC=1; fi
cat > "$T/ok.pas" <<'PAS'
program strctl(output);
const q = ''''; s = 'it''s';
var c: char;
begin
  c := 'z';
  writeln(q, s, q, ' ', 'x', c, ' ', '''''', ' ', 'a''b''c')
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/ok.ref"; fi
o3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); c3=$?
( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/ok.s" ok.pas </dev/null >/dev/null 2>&1 ) && \
( cd "$T" && cc -m64 -no-pie ok.s -o okm4 -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ control arm: m4 would not compile or link"; RC=1; }
o4=$( cd "$T" && timeout -k 5 20s ./okm4 </dev/null 2>&1 ); c4=$?
if [ "$c3" = 0 ] && [ "$c4" = 0 ] && [ "$o3" = "$(cat "$T/ok.ref")" ] && [ "$o4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: doubled apostrophes run byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles a LEGAL program"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"
     echo "      m3  : rc=$c3 $(printf '%s' "$o3" | tr '\n' '|')"; echo "      m4  : rc=$c4 $(printf '%s' "$o4" | tr '\n' '|')"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: '' is refused as ISO 7185 6.1.7 and doubled apostrophes stay legal, both modes"
else echo "GATE FAIL(1) [$G]: examined one vendored witness and one oracle-cut control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC

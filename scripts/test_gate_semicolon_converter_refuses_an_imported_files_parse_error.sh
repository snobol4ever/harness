#!/usr/bin/env bash
"$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_semicolon_converter_refuses_an_imported_files_parse_error.sh -- THE SEMICOLON CONVERTER NEVER INSERTS INTO ITS FILE FOR A PARSE ERROR RAISED IN
# AN IMPORTED FILE (UniTests u6b, officer_01's cut to officer_02 2026-11-08 13:0x; designed by officer_02). senior_01 MEASURED (u6 rung 3, harness 53e552bd)
# that util_icon_semicolons.py --compile-args=--dialect=unicon "gives up at the cap" on six uni/lib files (blockread 752, encode 628, four at 500). officer_02
# MEASURED the cause on harness 710f57f1, SCRIP 203fc0d8c: blockread.icn ALONE in a directory converts rc 0 (15 insertions); beside a raw package-lang file
# (decode.icn) it runs away: 753 insertions starting at 182:5242, then the cap. The parser's message is "parse error in imported file ./decode.icn: line 18
# ... after the token at line 17 col 10" (blockread imports lang, the resolver finds decode.icn in ., decode.icn is not converted), and the converter's ERR
# pattern takes decode's line and column as blockread's. The cap is the symptom, never the cause. Two arms, on scratch copies of /home/resources/unicon/uni/lib:
#   imported  blockread.icn beside raw decode.icn -> rc 1, a STILL REFUSED line naming the imported file decode.icn, no "gave up", blockread.icn unchanged
#   alone     blockread.icn alone                 -> rc 0 (the ordinary road unchanged)
# FAIL ONCE: arm imported reads red at harness 710f57f1 (gave up after 752 insertions).
# EXIT: 0 both arms hold; 1 an arm red, named; 2 refused (no converter, no scrip, no uni/lib source).
set -u
G=test_gate_semicolon_converter_refuses_an_imported_files_parse_error
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; C="$HERE/util_icon_semicolons.py"; LIB=/home/resources/unicon/uni/lib
[ -f "$C" ] || { echo "⛔ REFUSE(2) [$G]: no util_icon_semicolons.py beside the gate"; exit 2; }
[ -f "$LIB/blockread.icn" ] && [ -f "$LIB/decode.icn" ] || { echo "⛔ REFUSE(2) [$G]: no $LIB/blockread.icn or decode.icn"; exit 2; }
grep -q '^package lang' "$LIB/decode.icn" && grep -q '^import lang' "$LIB/blockread.icn" || { echo "⛔ REFUSE(2) [$G]: the fixture no longer holds (decode.icn package lang, blockread.icn import lang)"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/$G.XXXXXX")"; trap 'rm -rf "${T:?}"' EXIT
RED=0; NOTE=""
mkdir -p "$T/imported" "$T/alone"
cp "$LIB/blockread.icn" "$LIB/decode.icn" "$T/imported/"; cp "$LIB/blockread.icn" "$T/alone/"
( cd "$T/imported" && timeout -k 5 1200 python3 "$C" --compile-args=--dialect=unicon blockread.icn ) > "$T/imported.log" 2>&1 < /dev/null; r1=$?
if [ "$r1" = 1 ] && grep -q '^STILL REFUSED blockread.icn: .*imported file \./decode\.icn' "$T/imported.log" && ! grep -q 'gave up' "$T/imported.log" \
   && cmp -s "$T/imported/blockread.icn" "$LIB/blockread.icn"; then :; else
    RED=$((RED + 1)); NOTE="$NOTE imported:rc$r1:$(grep -m1 -oE 'gave up after [0-9]+|STILL REFUSED[^:]*: .{0,60}' "$T/imported.log" | tr ' ' '_')"; fi
( cd "$T/alone" && timeout -k 5 1200 python3 "$C" --compile-args=--dialect=unicon blockread.icn ) > "$T/alone.log" 2>&1 < /dev/null; r2=$?
[ "$r2" = 0 ] || { RED=$((RED + 1)); NOTE="$NOTE alone:rc$r2"; }
echo "SEMICOLON_CONVERTER_IMPORTED_ERROR_BOARD arms=2 red=$RED${NOTE:+ red_arms=$NOTE} (tree $(git -C "$HERE/.." rev-parse --short HEAD 2>/dev/null))"
[ "$RED" = 0 ] && { echo "GATE OK [$G]: an imported file's parse error is refused and named, never inserted; a lone file still converts"; exit 0; }
echo "GATE FAIL [$G]:$NOTE"; exit 1

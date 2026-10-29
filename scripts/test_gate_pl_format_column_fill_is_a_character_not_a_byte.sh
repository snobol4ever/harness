#!/usr/bin/env bash
# test_gate_pl_format_column_fill_is_a_character_not_a_byte.sh -- format/2,3's ~Nt fill and ~N| column stop
# must count and emit CHARACTERS, so a fill given as a code point above 127 arrives whole (row prolog-
# logtalk-eleven-unicode-stream-cases-routed-from-the-builtins-family-row, hq_R 2026-09-13).
#
# TWO DEFECTS, ONE SYMPTOM. plc_fb_stop() wrote the fill as `char c = (char)f->fchr[fi]`, TRUNCATING a code
# point to its low byte -- format('~8594t~8|') emitted eight copies of byte 0x92, which is not a character
# in any encoding and renders as replacement junk. And plc_fb_colat() counted BYTES since the last newline
# rather than characters, so any multibyte content mis-columned every stop after it.
#
# ⛔⭐ THE ASCII ARMS ARE THE POINT OF THIS GATE, NOT THE ARROW. The Unicode arm alone is passed by any cure
# that special-cases wide fills; what must not move is the column arithmetic everything else depends on, so
# the four ASCII arms below are graded byte-for-byte against swipl 9.0.4's own output -- measured identical
# 2026-09-13 -- and they are the arms that would catch a character-counting change that shifted ordinary
# padding by one. A column fix that breaks plain ~t~| is a worse defect than the one it cures.
#
# ⭐ WHY THE ORACLE IS USED HERE AND NOT FOR THE ARROW: swipl agrees with this engine about ASCII columns,
# so it is a real control. It is NOT consulted about the Unicode fill, where the criterion is the Logtalk
# suite's own case (lgt_unicode_format_3_01, ISO-derived) -- the same standing rule as the encoding gate
# one file over.
# rc 0 green · 1 red · 2 could not measure.
set -uo pipefail
GATE_NAME=test_gate_pl_format_column_fill_is_a_character_not_a_byte
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no scrip at $SCRIP -- a missing binary prints a plausible all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$ROOT/out}/libscrip_rt.so" || exit 2
[ -f "$ROOT/out/libscrip_rt.so" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no out/libscrip_rt.so -- m4 cannot link"; exit 2; }
D=$(mktemp -d) || { echo "⛔ REFUSE(2) [$GATE_NAME]: no tmpdir"; exit 2; }
trap 'rm -rf "$D"' EXIT
PASS=0; FAIL=0; N=0
cat > "$D/fm.pl" <<'PLEOF'
:- initialization(main).
main :-	format('~8594t~8|', []), nl,
	format('~`-t~10|~w~n', [end]),
	format('~w~t~10|~w~n', [ab, cd]),
	format('~t~w~10|~n', [right]),
	format('~w~t~8|~w~t~16|~w~n', [a,b,c]),
	halt.
PLEOF
want='→→→→→→→→
----------end
ab        cd
     right
a       b       c'
for mode in m3 m4; do
    N=$((N+1))
    if [ "$mode" = m3 ]; then got=$(cd "$D" && timeout -k 5 20 "$SCRIP" "$D/fm.pl" </dev/null 2>&1)
    else
        if (cd "$D" && timeout -k 5 60 "$SCRIP" --compile --out="$D/fm.s" "$D/fm.pl" >/dev/null 2>&1) \
           && gcc -m64 -no-pie "$D/fm.s" -o "$D/fm.bin" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm >/dev/null 2>&1; then
            got=$(cd "$D" && timeout -k 5 20 "$D/fm.bin" 2>&1)
        else echo "  RED  $mode: the witness failed to compile or link"; FAIL=$((FAIL+1)); continue; fi
    fi
    if [ "$got" = "$want" ]; then PASS=$((PASS+1))
    else printf '  RED  %s: got\n%s\n       want\n%s\n' "$mode" "$got" "$want"; FAIL=$((FAIL+1)); fi
    # ---- THE BYTES, because "eight arrows" and "eight copies of a truncated byte" are the same LENGTH.
    N=$((N+1)); line1=$(printf '%s\n' "$got" | sed -n '1p')
    first=$(printf '%s' "$line1" | od -An -tx1 | tr -s ' \n' '  ' | sed 's/^ *//;s/ *$//')
    exp='e2 86 92 e2 86 92 e2 86 92 e2 86 92 e2 86 92 e2 86 92 e2 86 92 e2 86 92'
    if [ "$first" = "$exp" ]; then PASS=$((PASS+1)); else echo "  RED  $mode: the fill run is [$first], want eight whole U+2192 [$exp]"; FAIL=$((FAIL+1)); fi
done
# ---- THE ORACLE CONTROL on the four ASCII lines only, graded, because swipl agrees about ASCII columns.
cat > "$D/asc.pl" <<'PLEOF'
:- initialization(main).
main :-	format('~`-t~10|~w~n', [end]), format('~w~t~10|~w~n', [ab, cd]),
	format('~t~w~10|~n', [right]), format('~w~t~8|~w~t~16|~w~n', [a,b,c]), halt.
PLEOF
if command -v swipl >/dev/null 2>&1; then
    N=$((N+1)); sw=$(cd "$D" && timeout -k 5 20 swipl -q -g true "$D/asc.pl" 2>/dev/null)
    ours=$(cd "$D" && timeout -k 5 20 "$SCRIP" "$D/asc.pl" </dev/null 2>/dev/null)
    if [ "$sw" = "$ours" ]; then PASS=$((PASS+1)); else printf '  RED  oracle: swipl\n%s\n       ours\n%s\n' "$sw" "$ours"; FAIL=$((FAIL+1)); fi
else echo "    swipl unavailable -- the ASCII control arm was NOT graded this run, and that is stated rather than counted as a pass"; fi
[ "$N" -gt 0 ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: graded ZERO witnesses"; exit 2; }
echo "PL FORMAT COLUMN FILL: PASS=$PASS FAIL=$FAIL / $N arms graded (m3+m4 text and bytes, plus the swipl ASCII control)"
[ "$FAIL" -eq 0 ] && { echo "verdict=GREEN -- a wide fill arrives whole, columns count characters, and ordinary ASCII padding still matches swipl byte for byte"; exit 0; }
echo "verdict=RED"; exit 1

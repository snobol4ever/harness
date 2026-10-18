#!/usr/bin/env bash
# test_gate_pl_bom_is_written_detected_and_reported.sh -- open/4's bom(Bool) option must WRITE the UTF-8 BOM
# on a write stream and DETECT it on a read stream, and stream_property/2 must report bom/1 for text streams
# and have NO SOLUTION for it on binary ones (row prolog-logtalk-eleven-unicode-stream-cases-routed-from-the-
# builtins-family-row, hq_R 2026-09-13).
#
# WHAT WAS WRONG. bom(Bool) parsed, validated, and was then used on ONE path only: a read stream skipped a
# BOM if it found one. Nothing wrote a BOM, nothing recorded whether one had been seen, and bom/1 was not a
# stream property at all -- so `stream_property(S, bom(B))` simply failed for every stream in every state.
# ⭐ THE FAILING SHAPE IS WHY IT LASTED: a property that HAS NO SOLUTION and a property that is CORRECTLY
# ABSENT print the same thing, so the six Logtalk cases asserting bom(false) and the four asserting
# `\+ stream_property(S, bom(_))` were half right for free, and the half that was right was the half a
# reader checks first.
#
# ⛔ THE DEFAULTS RUN IN OPPOSITE DIRECTIONS AND ARM 1 IS WHERE THAT IS PINNED. A read stream skips a BOM it
# was not told about; a write stream must emit one ONLY when asked. The option was held in a plain int
# defaulted to 1, which was right for reading and would have meant "write a BOM" the moment the write path
# looked at it -- and an unrequested BOM corrupts every file this engine produces, which no Prolog-level
# test would ever show. It is tristate now, and ARM 1 reads the actual first bytes rather than asking the
# engine what it thinks it did.
#
# ⛔ ARM 6 IS THE ONE THAT STOPS THE CHEAP CURE. Reporting bom(false) unconditionally passes every positive
# arm above it and reds the four binary cases that assert the property is ABSENT -- and a cure that trades
# one case for another never lands (CEO-589).
#
# ⛔ THE BOM IS NOT CONTENT (ARM 5). A detected BOM must be consumed, not delivered: if it reaches the
# program as a character, every read of a BOM'd file is off by one and the file's first term is corrupt.
# rc 0 green · 1 red · 2 could not measure.
set -uo pipefail
GATE_NAME=test_gate_pl_bom_is_written_detected_and_reported
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no scrip at $SCRIP -- a missing binary prints a plausible all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$ROOT/out}/libscrip_rt.so" || exit 2
[ -f "$ROOT/out/libscrip_rt.so" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no out/libscrip_rt.so -- m4 cannot link"; exit 2; }
D=$(mktemp -d) || { echo "⛔ REFUSE(2) [$GATE_NAME]: no tmpdir"; exit 2; }
trap 'rm -rf "$D"' EXIT
PASS=0; FAIL=0; N=0
cat > "$D/bom.pl" <<'PLEOF'
:- initialization(main).
main :-
	open('plain.txt', write, A, [encoding('UTF-8')]),
	stream_property(A, bom(BA)), write(arm1_default(BA)), nl, write(A, abc), close(A),
	open('off.txt', write, B, [encoding('UTF-8'), bom(false)]),
	stream_property(B, bom(BB)), write(arm2_false(BB)), nl, close(B),
	open('on.txt', write, C, [encoding('UTF-8'), bom(true)]),
	stream_property(C, bom(BC)), write(arm3_true(BC)), nl, write(C, hello), close(C),
	open('on.txt', read, E),
	stream_property(E, bom(BE)), stream_property(E, encoding(EE)), write(arm4_reread(BE-EE)), nl,
	get_char(E, Ch), write(arm5_first_char(Ch)), nl, close(E),
	open('plain.txt', read, F),
	stream_property(F, bom(BF)), write(arm5b_nobom_reread(BF)), nl, close(F),
	open('b.bin', write, G, [type(binary), bom(true)]),
	( stream_property(G, bom(_)) -> write(arm6_binary_has_bom_WRONG) ; write(arm6_binary_no_bom) ), nl, close(G),
	halt.
PLEOF
want='arm1_default(false)
arm2_false(false)
arm3_true(true)
arm4_reread(true-UTF-8)
arm5_first_char(h)
arm5b_nobom_reread(false)
arm6_binary_no_bom'
for mode in m3 m4; do
    N=$((N+1)); rm -f "$D"/*.txt "$D"/*.bin
    if [ "$mode" = m3 ]; then got=$(cd "$D" && timeout -k 5 20 "$SCRIP" "$D/bom.pl" </dev/null 2>&1)
    else
        if (cd "$D" && timeout -k 5 60 "$SCRIP" --compile -o "$D/bom.s" "$D/bom.pl" >/dev/null 2>&1) \
           && gcc -m64 -no-pie "$D/bom.s" -o "$D/bom.bin" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm >/dev/null 2>&1; then
            got=$(cd "$D" && timeout -k 5 20 "$D/bom.bin" 2>&1)
        else echo "  RED  $mode: the witness failed to compile or link"; FAIL=$((FAIL+1)); continue; fi
    fi
    if [ "$got" = "$want" ]; then PASS=$((PASS+1))
    else printf '  RED  %s: got\n%s\n       want\n%s\n' "$mode" "$got" "$want"; FAIL=$((FAIL+1)); fi
    # ---- THE BYTES ON DISK, which is the only arm that can tell "wrote a BOM" from "says it wrote a BOM".
    N=$((N+1)); on=$(head -c3 "$D/on.txt" 2>/dev/null | od -An -tx1 | tr -s ' ' | sed 's/^ //;s/ $//')
    if [ "$on" = "ef bb bf" ]; then PASS=$((PASS+1)); else echo "  RED  $mode: bom(true) wrote [$on], want [ef bb bf]"; FAIL=$((FAIL+1)); fi
    N=$((N+1)); pl=$(head -c3 "$D/plain.txt" 2>/dev/null | od -An -tx1 | tr -s ' ' | sed 's/^ //;s/ $//')
    if [ "$pl" = "61 62 63" ]; then PASS=$((PASS+1)); else echo "  RED  $mode: a stream with NO bom option wrote [$pl], want the content [61 62 63] and no BOM"; FAIL=$((FAIL+1)); fi
done
[ "$N" -gt 0 ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: graded ZERO witnesses"; exit 2; }
echo "PL BOM WRITE/DETECT/REPORT: PASS=$PASS FAIL=$FAIL / $N arms graded (m3+m4, plus the bytes on disk in each mode)"
[ "$FAIL" -eq 0 ] && { echo "verdict=GREEN -- bom(true) writes the BOM, a reread detects it, the BOM is consumed rather than delivered, an unasked stream writes none, and a binary stream has no bom property"; exit 0; }
echo "verdict=RED"; exit 1

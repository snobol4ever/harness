#!/usr/bin/env bash
# test_gate_pl_a_text_stream_reads_characters_not_bytes.sh -- get_char/get_code/peek_char/peek_code on a TEXT
# stream must yield one CODE POINT per call and must consume a leading BOM, while a BINARY stream keeps its
# byte semantics (row prolog-logtalk-encodings-group, hq_C 2026-09-13).
#
# THE DEFECT THIS PINS. All four character reads were a bare fgetc, so a UTF-8 file read one character at a
# time came back one BYTE at a time and every non-ASCII character split into its encoding. Measured against
# swipl 9.0.4 on 2026-09-13: the four-character file `a<U+00E9>b\n` read 4 characters under the oracle and
# FIVE here, with the e-acute arriving as two replacement characters. The atom layer was never the defect --
# atom_length for a one-character non-ASCII atom is 1 on both sides -- which is exactly why this survived: an
# engine can be fully UTF-8 aware in its terms and still read files a byte at a time, and every ASCII test in
# the suite passes identically either way. ⭐ NO LOGTALK CASE FLIPPED ON THIS CURE, so without this arm the
# whole change is invisible to every board and the next byte-oriented rewrite of get_char is uncontested.
#
# ⛔ ARM 3 IS THE ARM THAT STOPS THE OVER-BROAD CURE. Decoding unconditionally -- on type(binary) streams too
# -- passes ARMS 1 and 2 perfectly and silently corrupts get_byte/peek_byte, whose whole contract is that a
# byte is a byte. A cure that trades one case for another never lands (CEO-589), so the binary arm is graded
# beside the text ones, always.
#
# ⛔ THE BOM IS A STREAM ANNOTATION, NOT DATA, AND bom(false) IS THE WAY TO ASK FOR THE BYTES. swipl consumes
# a leading BOM on open and hands back the first real character; reading it as U+FEFF corrupts the first term
# of every BOM-carrying file. ARM 4 grades the bom(false) escape hatch, which must still deliver 0xFEFF as
# ONE character -- that is the suite's own lgt_unicode_open_4_read_09 expectation.
# rc 0 green · 1 red · 2 could not measure.
set -uo pipefail
GATE_NAME=test_gate_pl_a_text_stream_reads_characters_not_bytes
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no scrip at $SCRIP -- a missing binary prints a plausible all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$ROOT/out}/libscrip_rt.so" || exit 2
D=$(mktemp -d) || { echo "⛔ REFUSE(2) [$GATE_NAME]: no tmpdir"; exit 2; }
trap 'rm -rf "$D"' EXIT
PASS=0; FAIL=0; N=0
printf 'a\303\251b\n'          > "$D/plain.txt"
printf '\357\273\277hi\n'      > "$D/bom.txt"
[ "$(wc -c < "$D/plain.txt")" = 5 ] && [ "$(wc -c < "$D/bom.txt")" = 6 ] \
  || { echo "⛔ REFUSE(2) [$GATE_NAME]: the fixtures are not the byte lengths this gate reasons about"; exit 2; }
cat > "$D/rd.pl" <<'PLEOF'
:- initialization(main).
rd(S,L) :- get_char(S,C), ( C == end_of_file -> L=[] ; L=[C|T], rd(S,T) ).
main :- open('plain.txt', read, S, []), rd(S,L), close(S), length(L,N), write(text_chars(N)), nl,
	open('plain.txt', read, S2, []), get_char(S2,_), peek_char(S2,P), get_char(S2,G), close(S2),
	( P == G -> write(peek_agrees_with_get) ; write(peek_disagrees(P,G)) ), nl,
	open('plain.txt', read, S3, []), get_char(S3,_), get_code(S3,C3), close(S3), write(second_code(C3)), nl,
	open('bom.txt', read, S4, []), get_char(S4,B1), close(S4), write(bom_skipped_first(B1)), nl,
	open('bom.txt', read, S5, [bom(false)]), get_code(S5,B2), close(S5), write(bom_kept_code(B2)), nl,
	open('plain.txt', read, S6, [type(binary)]), get_byte(S6,Y1), get_byte(S6,Y2), close(S6),
	write(binary_bytes(Y1,Y2)), nl, halt.
PLEOF
want='text_chars(4)
peek_agrees_with_get
second_code(233)
bom_skipped_first(h)
bom_kept_code(65279)
binary_bytes(97,195)'
for mode in m3 m4; do
    N=$((N+1))
    if [ "$mode" = m3 ]; then got=$(cd "$D" && timeout -k 5 20 "$SCRIP" "$D/rd.pl" </dev/null 2>&1)
    else
        if (cd "$D" && timeout -k 5 60 "$SCRIP" --compile --out="$D/rd.s" "$D/rd.pl" >/dev/null 2>&1) \
           && gcc -m64 -no-pie "$D/rd.s" -o "$D/rd.bin" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm >/dev/null 2>&1; then
            got=$(cd "$D" && timeout -k 5 20 "$D/rd.bin" 2>&1)
        else echo "  RED  $mode: the witness failed to compile or link"; FAIL=$((FAIL+1)); continue; fi
    fi
    if [ "$got" = "$want" ]; then PASS=$((PASS+1))
    else printf '  RED  %s: got\n%s\n       want\n%s\n' "$mode" "$got" "$want"; FAIL=$((FAIL+1)); fi
done
# ---- THE ORACLE'S OWN ANSWER, PRINTED AND NEVER GRADED. Unlike the binary-encoding gate beside it, this
# engine AGREES with swipl on every arm here; printing it says so, so a later reader does not re-litigate it.
sw="unavailable"
if command -v swipl >/dev/null 2>&1; then
  cat > "$D/orc.pl" <<'PLEOF'
:- initialization(main, main).
rd(S,L) :- get_char(S,C), ( C == end_of_file -> L=[] ; L=[C|T], rd(S,T) ).
main :- open('plain.txt', read, S, []), rd(S,L), close(S), length(L,N),
	open('bom.txt', read, S4, []), get_char(S4,B1), close(S4), format("chars=~w bom_first=~q~n",[N,B1]).
PLEOF
  sw=$(cd "$D" && timeout -k 5 20 swipl -q "$D/orc.pl" 2>&1 | tr '\n' ' ')
fi
echo "    NOT GRADED, printed so agreement is on the record: swipl [$sw] · this engine: text_chars(4) bom_skipped_first(h)"
[ "$N" -gt 0 ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: graded ZERO witnesses"; exit 2; }
echo "PL TEXT STREAM CHARACTERS: PASS=$PASS FAIL=$FAIL / $N arms graded (m3+m4; text decodes UTF-8 and eats the BOM, binary still reads bytes)"
[ "$FAIL" -eq 0 ] && { echo "verdict=GREEN -- a text stream yields code points and consumes a leading BOM, bom(false) still delivers U+FEFF, and a binary stream is untouched"; exit 0; }
echo "verdict=RED"; exit 1

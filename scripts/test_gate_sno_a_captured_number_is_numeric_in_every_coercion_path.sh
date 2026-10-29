#!/usr/bin/env bash
# test_gate_sno_a_captured_number_is_numeric_in_every_coercion_path.sh -- a value that came out of a pattern
# capture is the SAME value as a literal one, in every path that asks "is this a number?".
#
# ⛔ THE DEFECT (ceo 2026-09-14, gimpel ASM_driver, row snobol4-gimpel-suite-126-to-100-percent-by-class).
# A capture is a VIEW: its descriptor's .s points INTO the subject and the length is CARRIED in .slen, so the
# bytes do not end at a NUL. Three numeric paths read .s raw and demanded the number end at '\0':
# bn_integer's scan, and the _OPCOERCE / _SNOCOERCE macros every numeric builtin in the dispatcher goes through.
# On `AC` captured as "1" out of "START LOAD 1,ONE " they walked into ",ONE " and concluded it was not a number.
#
# ⭐ WHAT MADE IT INVISIBLE FOR SO LONG, and the reason this gate tests FOUR paths rather than the one that broke:
# the TEMPLATE arithmetic path already honoured the carried length, so `AC + 1` was 2 and `SIZE(AC)` was 1 on the
# very same value that `INTEGER(AC)` called non-numeric. Two coercions for one language, disagreeing about what
# the value IS, with each one right on its own witness. A gate that held only INTEGER would have let the next
# builtin re-acquire the defect in silence.
#
# ⛔ AND THE SYMPTOM WAS NOWHERE NEAR THE CAUSE: ASM_driver printed a wrong REGISTER COLUMN and two spurious
# error causes, sixty lines of assembler listing away from any mention of numbers.
#
# THE EXPECTATIONS ARE CUT FROM THE ORACLE (`sbl -bf`), not from our output -- each line below was produced by
# the oracle on this exact witness before the cure existed. NO BUILD NEEDED beyond ./scrip already being built.
# rc=0 clean · rc=1 a coercion path disagrees · rc=2 REFUSAL (cannot measure).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
[ -x "$B/scrip" ] || { echo "⛔ REFUSES rc=2: $B/scrip is not built -- cannot measure"; exit 2; }
D="$(mktemp -d)" || { echo "⛔ REFUSES rc=2: no scratch dir"; exit 2; }
trap 'rm -rf "$D"' EXIT

cat > "$D/w.sno" <<'SNO'
        LINE = 'START LOAD 1,ONE '
        LINE ? POS(0) BREAK(' ') SPAN(' ') BREAK(' ') . OP SPAN(' ') (BREAK(' ,') . AC ',' | NULL) REM . A
        OUTPUT = 'cap=' AC
        OUTPUT = 'size=' SIZE(AC)
        OUTPUT = 'plus=' AC + 1
        INTEGER(AC)                             :S(I1)F(I0)
I1      OUTPUT = 'integer=yes'                  :(R)
I0      OUTPUT = 'integer=no'
R       OUTPUT = 'remdr=' REMDR(AC,16)
        OUTPUT = 'lt=' LT(AC,5) 'yes'
        OUTPUT = 'eq=' EQ(AC,1) 'yes'
END
SNO
cat > "$D/w.ref" <<'REF'
cap=1
size=1
plus=2
integer=yes
remdr=1
lt=yes
eq=yes
REF

fails=0
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then
        (cd "$D" && timeout -k 5 20 "$B/scrip" w.sno </dev/null > "out.$mode" 2>&1)
    else
        "$B/scrip" --compile --out="$D/w.s" "$D/w.sno" </dev/null >/dev/null 2>&1 \
          && as -o "$D/w.o" "$D/w.s" 2>/dev/null \
          && gcc -o "$D/w.bin" "$D/w.o" "$B/out/libscrip_rt.so" -Wl,-rpath,"$B/out" 2>/dev/null \
          || { echo "⛔ REFUSES rc=2: could not build the m4 arm -- that is a toolchain failure, not a verdict"; exit 2; }
        (cd "$D" && timeout -k 5 20 ./w.bin </dev/null > "out.$mode" 2>&1)
    fi
    if diff -q "$D/w.ref" "$D/out.$mode" >/dev/null 2>&1; then
        printf '  ok    %s: a captured number is numeric in all four paths (INTEGER, REMDR, the relations, arithmetic)\n' "$mode"
    else
        printf '  FAIL  %s: a coercion path disagrees with the oracle on a CAPTURED number --\n' "$mode"
        diff "$D/w.ref" "$D/out.$mode" | sed 's/^/          /'
        fails=$((fails+1))
    fi
done

[ "$fails" -eq 0 ] || { echo "⛔ GATE FAILED: $fails of 2 mode(s) red."
                        echo "   ⭐ THE CURE IS THE CARRIED LENGTH, NEVER A strlen: rt_cstr_d(d) returns .s untouched when the byte"
                        echo "      at slen is already NUL and materialises a copy only when it is not. Fix the COERCION, not the"
                        echo "      one builtin that reported it -- every numeric builtin in the dispatcher shares _OPCOERCE."
                        exit 1; }
echo "✅ GATE OK: a pattern-captured number is numeric in INTEGER, REMDR, the numeric relations and arithmetic, both modes"
exit 0

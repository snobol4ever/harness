#!/usr/bin/env bash
# test_gate_sno_ord_reads_the_first_character_and_fails_only_on_null.sh -- ORD(S) is the character code of S's FIRST character, S taken
# as a string (an integer or a real converts first), and it FAILS only when S is null -- CSNOBOL4's ORD, the reference for the feature,
# and the ORD the ceo compiled into our SPITBOL fork (ceo CEO-1415; Lon 2026-10-02, in-chat to the ceo: "Add the ORD function." and
# "Finish ORD and test6.").
#
# ⛔⭐ FOUND MEASURING ORD FOR THE ORACLE: SCRIP's ORD failed unless S was exactly one character, so ORD('AB') and ORD(65) FAILED where
# CSNOBOL4 answers 65 and 54 (the string '65', its first character '6'). The witness drives every class: one character, several, the
# two ends of the byte range, a byte above 127, an integer and a real argument, the result's datatype, the null string, and all 256
# CHAR(I) round trips.
#
# THE ARMS:
#   1  the reference (csnobol4 -b) prints the pinned lines (refuses if not: the reference moved, re-measure the pin)
#   1b the oracle (sbl -bf), when it knows ORD (it did not before the fork's ORD landing: ERROR 022), prints the pinned lines too
#   2  m3 prints the pinned lines            3  m4 prints the pinned lines
# A one-character-only ORD prints no line for 'AB', 65 or 1.5 and fails 2-3; an ORD that never fails prints no 'null fails' line.
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no reference, reference moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_ord_reads_the_first_character_and_fails_only_on_null
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
CSN="$(csnobol4_bin 2>/dev/null || true)"; [ -n "${CSN:-}" ] && [ -x "$CSN" ] || refuse "no csnobol4 reference -- cannot check the pin"
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/w.sno" <<'SNO'
        OUTPUT = ORD('A')
        OUTPUT = ORD('AB')
        OUTPUT = ORD(CHAR(0))
        OUTPUT = ORD(CHAR(255))
        OUTPUT = ORD(CHAR(128))
        OUTPUT = ORD(65)
        OUTPUT = ORD(1.5)
        OUTPUT = DATATYPE(ORD('z'))
        X = ORD('')                     :S(BAD)
        OUTPUT = 'null fails'
        I = 0
L       EQ(ORD(CHAR(I)), I)             :F(BAD)
        I = LT(I, 255) I + 1            :S(L)
        OUTPUT = 'all 256 round-trip'   :(END)
BAD     OUTPUT = 'BAD'
END
SNO
printf '65\n65\n0\n255\n128\n54\n49\nINTEGER\nnull fails\nall 256 round-trip\n' > "$T/want"
fails=0
arm() { if [ "$2" = 0 ]; then echo "  ok   arm $1"; else echo "  FAIL arm $1"; fails=$((fails+1)); fi; }
(cd "$T" && timeout -k 5 10 "$CSN" -b w.sno </dev/null >ref 2>/dev/null)
cmp -s "$T/ref" "$T/want" || refuse "csnobol4 no longer prints the pinned lines -- re-measure the pin: $(tr '\n' '|' < "$T/ref" | cut -c1-120)"
arm "1 csnobol4 prints the pin" 0
if [ -x "$SBL" ]; then
    (cd "$T" && timeout -k 5 10 "$SBL" -bf w.sno </dev/null >ora 2>&1)
    if grep -q 'ERROR 022' "$T/ora"; then echo "  --   arm 1b sbl -bf does not know ORD (ERROR 022): not compared"
    else cmp -s "$T/ora" "$T/want"; arm "1b sbl -bf prints the pin" $?; fi
fi
(cd "$T" && timeout -k 5 10 "$SCRIP" w.sno </dev/null >m3 2>/dev/null)
cmp -s "$T/m3" "$T/want"; arm "2 m3 prints the pin" $?
if (cd "$T" && timeout -k 5 30 "$SCRIP" --compile w.sno </dev/null >w.s 2>/dev/null) && gcc -no-pie "$T/w.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/w.bin" 2>/dev/null; then
    (cd "$T" && timeout -k 5 10 ./w.bin </dev/null >m4 2>/dev/null); cmp -s "$T/m4" "$T/want"; arm "3 m4 prints the pin" $?
else arm "3 m4 compiles and links" 1; fi
[ "$fails" = 0 ] && { echo "GATE PASS(0) [$NAME]: ORD reads the first character and fails only on null, both modes"; exit 0; }
echo "GATE FAIL(1) [$NAME]: $fails arm(s) red"; exit 1

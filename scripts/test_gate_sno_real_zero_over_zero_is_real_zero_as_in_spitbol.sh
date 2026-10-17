#!/usr/bin/env bash
# test_gate_sno_real_zero_over_zero_is_real_zero_as_in_spitbol.sh
#
# SPITBOL'S RULE (measured with sbl -bf; ceo CEO-1419 ticket snobol4-real-zero-divided-by-zero-is-zero-in-spitbol-
# where-scrip-raises-error-262, found by Lon's infinite_snobol4): a real division whose numerator and divisor are both
# zero -- 0 / 0.0, 0.0 / 0, -0.0 / 0, 0.0 / 0.0 -- yields REAL 0. with no error, and that value is 0.0 afterwards
# (EQ(X,0) succeeds, 1 / X raises 262). A non-zero real over zero is still 262, and integer 0 / 0 is still 14.
# SCRIP raised 262 for all of them. THE CURE: arithmetic.c's BINOP_DIV real arm returns REALVAL(0.0) when both are
# zero, off Icon's path (strict 1 keeps Icon's 204). Operands are run-time values because sbl folds 0 / 0 at compile.
# Expectations are cut from sbl -bf AT RUN TIME, both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- the expectations are cut from it at run time"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/z.sno" <<'SNO'
        &ERRLIMIT = 10
        Z = 0
        ZR = 0.0
        NZ = -0.0
        X = Z / ZR
        OUTPUT = 'X=' X ' ' DATATYPE(X)
        OUTPUT = 'X+1=' (X + 1)
        OUTPUT = 'EQ(X,0) ' (EQ(X, 0) 'yes', 'no')
        Y = 1 / X                    :F(F)
        OUTPUT = 'Y=' Y              :(G)
F       OUTPUT = 'Y fails ' &ERRTYPE
G       OUTPUT = 'zr/z: ' (ZR / Z)
        OUTPUT = 'nz/z: ' (NZ / Z)
        OUTPUT = 'zr/zr: ' (ZR / ZR)
        V = 1.5 / ZR                 :F(K)
        OUTPUT = 'nonzero/zr: ' V    :(J)
K       OUTPUT = 'nonzero/zr fails ' &ERRTYPE
J       W = Z / Z                    :F(H)
        OUTPUT = 'z/z: ' W           :(END)
H       OUTPUT = 'z/z fails ' &ERRTYPE
END
SNO
(cd "$D" && timeout -k 5 20 "$SBL" -bf z.sno < /dev/null > z.sbl 2>/dev/null)
grep -qx "X=0. REAL" "$D/z.sbl" && grep -qx "nonzero/zr fails 262" "$D/z.sbl" || refuse "the oracle no longer reads 0. REAL for 0 / 0.0 and 262 for 1.5 / 0.0 -- re-read sbl"
fails=0
(cd "$D" && timeout -k 5 20 "$B/scrip" z.sno < /dev/null > z.m3 2>/dev/null)
"$B/scrip" --compile -o "$D/z.s" "$D/z.sno" </dev/null >/dev/null 2>&1 && gcc -no-pie -o "$D/z.bin" "$D/z.s" -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" 2>/dev/null || refuse "could not build the m4 arm -- a toolchain failure, not a verdict"
(cd "$D" && timeout -k 5 20 ./z.bin < /dev/null > z.m4 2>/dev/null)
for m in m3 m4; do
    if cmp -s "$D/z.sbl" "$D/z.$m"; then echo "  ok    $m $(wc -l < "$D/z.sbl") lines, byte-identical to sbl"
    else echo "  FAIL  $m"; diff "$D/z.sbl" "$D/z.$m" | head -8 | sed 's/^/          /'; fails=$((fails+1)); fi
done
[ "$fails" -eq 0 ] || { echo "⛔ GATE FAILED: $fails of 2 mode(s) red -- arithmetic.c's real BINOP_DIV no longer returns 0.0 for zero over zero, or raises where sbl does not"; exit 1; }
echo "✅ GATE OK: 2 modes -- real zero over zero is REAL 0. as in SPITBOL, a non-zero real over zero is 262, integer 0 / 0 is 14"
exit 0

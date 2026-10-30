#!/usr/bin/env bash
# test_gate_a_taken_direct_goto_pops_its_whole_statement_carve_whatever_its_gamma_is.sh -- CEO-2020, cto R9 THE TRANSFER LAW (ARCH-ZETA-LAYOUT-ONE-SOURCE-OF-TRUTH.md section 3): a
# transfer pops the statement's whole carve, the distance from rsp in the box to the statement base (op_zdepth), and never gamma's pop (op_zgpop).
#
# THE SHAPE: SCRIP e0b38b501 (an error in a direct goto is trappable error 24) wired the direct goto's gamma at the retake copy of the failure exit, a deeper node, so
# op_zgpop read 0 and bb_goto_deferred.cpp's resolved path emitted a bare jmp rax: every taken direct goto left the statement's 16-byte cell on the stack. Output alone cannot see it
# (the leak is 16 bytes a goto), so every arm runs at -s128k with a loop that takes the goto 20,000 to 200,000 times: three witnesses, the unconditional :<C> into a CODE chunk that
# loops back, the :S<X>F<Y> shape, and a direct goto taken from inside a CODE chunk.
#
# THE EXPECTATIONS are cut from sbl -bf (the correctness oracle) at run time, never typed. THE NEGATIVE CONTROL (CEO-1680: a proper test, no seam in src/): the runtime built from SCRIP
# 076ff808a, one commit before the cure, run under SCRIP_ALLOW_STALE=1 with RT_DIR and LD_LIBRARY_PATH at it, reads ERROR 246 stack overflow in FIVE of the six arms (leak and sf in both
# modes, chunk in mode 3); the chunk witness's mode-4 arm reads the oracle's answer there too (measured twice, also with the loop head on its own statement), so it is correctness
# coverage of an in-chunk direct goto in mode 4 and not a trip. The cured tree reads the oracle's answer in all six arms.
#
# Usage: bash ../harness/scripts/test_gate_a_taken_direct_goto_pops_its_whole_statement_carve_whatever_its_gamma_is.sh   (rc 0 green, 1 red, 2 could not measure)
set -uo pipefail
GATE_NAME=test_gate_a_taken_direct_goto_pops_its_whole_statement_carve_whatever_its_gamma_is
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
. "$HERE/lib_gate.sh"
. "$HERE/lib_oracle_flags.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: correctness oracle missing ($SBL)"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: no gcc -- the mode-4 arm cannot be linked"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf '%s\n' " C = CODE(' X = X + 1 :(LOOP)')" " X = 0" "LOOP LT(X, 200000) :F(DONE)" " :<C>" "DONE OUTPUT = 'x ' X" "END" > "$T/leak.sno"
printf '%s\n' " T1 = CODE(' N = N + 1 :(LOOP)')" " T2 = CODE(' OUTPUT = \"x \" X \" \" N :(END)')" " X = 0" "LOOP X = X + 1" " LT(X, 50000) :S<T1>F<T2>" "END" > "$T/sf.sno"
printf '%s\n' " D = CODE(' Y = Y + 1 :(LOOP)')" " C = CODE(' X = X + 1;  LT(X, 20000) :S<D>F(DONE)')" " X = 0" "LOOP :<C>" "DONE OUTPUT = 'x ' X ' ' Y" "END" > "$T/chunk.sno"
fail=0
for w in leak sf chunk; do
    want="$( cd "$T" && timeout -k 5 60 "$SBL" $(sbl_lang_flags) "$w.sno" < /dev/null 2> /dev/null )"
    [ -n "$want" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: the oracle printed nothing for $w.sno"; exit 2; }
    got3="$( cd "$T" && timeout -k 5 60 "$SCRIP" -s128k "$w.sno" < /dev/null 2>&1 )"
    if [ "$got3" = "$want" ]; then echo "  ok   ($w m3) at -s128k: $want"; else echo "  FAIL ($w m3) at -s128k: wanted [$want], got [$(printf '%s' "$got3" | tail -1)]"; fail=1; fi
    if ( cd "$T" && "$SCRIP" --compile --out="$w.s" "$w.sno" < /dev/null > /dev/null 2>&1 && gcc -m64 -no-pie -o "$w.bin" "$w.s" -L"$RT" -lscrip_rt -lm -lpthread -Wl,-rpath,"$RT" 2> /dev/null ); then
        got4="$( cd "$T" && timeout -k 5 60 "./$w.bin" -s128k < /dev/null 2>&1 )"
        if [ "$got4" = "$want" ]; then echo "  ok   ($w m4) at -s128k: the same, from the standalone build"; else echo "  FAIL ($w m4) at -s128k: wanted [$want], got [$(printf '%s' "$got4" | tail -1)]"; fail=1; fi
    else echo "  FAIL ($w m4) the witness did not compile or link in mode 4"; fail=1; fi
done
[ "$fail" = 0 ] && { echo "✅ GATE PASS [$GATE_NAME]: three direct-goto shapes run 20,000 to 200,000 gotos at -s128k as the oracle does, in both modes"; exit 0; }
echo "⛔ GATE RED [$GATE_NAME]"; exit 1

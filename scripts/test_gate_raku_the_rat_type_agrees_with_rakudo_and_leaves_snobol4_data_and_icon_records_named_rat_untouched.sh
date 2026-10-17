#!/usr/bin/env bash
# test_gate_raku_the_rat_type_agrees_with_rakudo_and_leaves_snobol4_data_and_icon_records_named_rat_untouched.sh -- THE RAT TYPE: decimal literals, Int/Int division, Int ** negative Int, Rat and FatRat
# arithmetic with arbitrary-size numerators and a denominator limit of 2**64, six-digit stringification, and every numeric builtin that takes a Rat (index, range bounds, x, floor, abs, sqrt, sprintf, Int,
# ^N, sort, min, max, sum) (row raku-every-suite-to-100-under-nonet-ceo-1266; cto rulings ask-rat-type-arithmetic-hook and ask-rat-hook-reaches-core-numeric-coercion).
#
# THE DEFECT: a Raku decimal literal was a binary double (0.1 + 0.2 printed 0.30000000000000004, 1/3 printed 0.3333333333333333, 6/3 was an Int), there was no Rat, no FatRat and no exact
# arithmetic, Int ** -2 was 0 and 0 ** 0 died, and RakBench's mb-rat_mul_div_cancel, mb-rat_harmonic, pi-sequential-iteration and rc-dragon-curve could not pass.
# THE CURE: src/runtime/rk_rat.c holds a Rat as a DATA instance of the type "\x01Rat" (and "\x01FatRat"), a name no frontend can spell, with an exact integer numerator (a bignum when it leaves int64) and a denominator
# below 2**64 (a Rat whose denominator would reach 2**64 becomes a Num, as in Rakudo; a FatRat never does). rt_binop_overload, rt_jct_relop, to_real, to_int_slow and is_numeric_like reach it through
# one leaf each (rk_rat_binop, rk_rat_cmp, rk_rat_to_real, rk_rat_to_int, rk_rat_is) that answers not-mine for every other DATA type; the Raku type-name printer is the one place the control byte is mapped back.
# THE WITNESSES: eight master entries (six for the type; two, argument and testmod, for a Rat reaching an integer argument, a Cool method receiver, a container element and the Test module's plan, skip and is-approx -- found by the sprintf, math-and-list and is-approx gates), rung 02 (ladder__rung02_arithmetic_rat_* and ladder__rung02_arithmetic_fatrat_*), expected output cut by Rakudo, each in m3 and m4, the allocating ones under
# SCRIP_GC_STRESS 1 3 5.
# THE OTHER LANGUAGES: ../harness/scripts/fixtures/rat_other_languages holds 18 SNOBOL4 programs that build a DATA named RAT and 18 Icon programs that build a record named Rat and push it through every coercion the
# landing widened (+ - * / ** unary minus, SIN SQRT ABS CHAR DUPL LPAD SUBSTR ARRAY REMDR LT SIZE INTEGER REAL, integer real numeric string repl left sqrt sin abs % < to); their expected output (stdout, stderr and
# rc, modes 3 and 4) was cut from the BASE binary (SCRIP b01fdb21a) before the change, so a byte of difference is a behaviour the landing changed for those languages.
# RE-CUT (cfo 2026-10-17, row gate-raku-rat-an-icon-record-is-now-taken-as-numeric-error-102-in-icn-05-ceo-1807): icn_02 (sqrt), icn_05 (abs) and icn_17 (sin) of a record printed done on the base
# binary where iconx raises 102; SCRIP 49c2cdaee cured abs and the math-builtins landing cured sqrt and sin, and their refs are re-cut to the runs that raise 102 at line 5 on record Rat_1(1,2) as iconx
# does. Every other Icon fixture already agrees with iconx in error number, line and offending value.
# FAILED ONCE: the six witnesses differ from Rakudo on b01fdb21a (Num literals, no Rat).
#
# EXIT: 0 every pair matches; 1 a mismatch or a crash; 2 REFUSED (stale binary, no gcc, no corpus).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_rat_type"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
MASTER="$ROOT/../corpus/tests/raku/ALL.raku"; REFS="$ROOT/../corpus/tests/raku/ALL.ref"
FX="$ROOT/../harness/scripts/fixtures/rat_other_languages"
[ -f "$MASTER" ] && [ -f "$REFS" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: no master at $MASTER"; exit 2; }
[ -d "$FX" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: no fixtures at $FX"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
fails=0; GATE_EXAMINED=0
python3 - "$MASTER" "$REFS" "$W" <<'PY' || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: cannot extract the master entries"; exit 2; }
import re, sys
def split(path):
    d = {}; cur = None; buf = []
    for line in open(path, encoding='utf-8', errors='surrogateescape'):
        m = re.match(r'^#-+ \d+ (\S+)(?: .*)?$', line)
        if m:
            if cur: d[cur] = ''.join(buf)
            cur = m.group(1); buf = []
        else: buf.append(line)
    if cur: d[cur] = ''.join(buf)
    return d
src, ref = split(sys.argv[1]), split(sys.argv[2])
names = {'literals': 'rat_literals_division_stringification_and_methods', 'exact': 'rat_exact_with_big_numerators_and_the_64_bit_denominator_limit',
         'builtins': 'rat_in_the_builtins_index_range_x_floor_abs_sqrt_sprintf_int_and_caret', 'smartmatch': 'rat_smartmatch_truthiness_function_forms_and_type_checks',
         'rounding': 'rat_rounding_comparison_sums_and_mixed_operands', 'fatrat': 'fatrat_keeps_every_digit',
         'argument': 'rat_as_an_argument_a_receiver_and_a_container_element_agrees_with_rakudo', 'testmod': 'rat_counts_and_tolerances_in_the_test_module_plan_skip_is_approx'}
for g, full in names.items():
    n = 'ladder__rung02_arithmetic_' + full
    open('%s/%s.raku' % (sys.argv[3], g), 'w', encoding='utf-8', errors='surrogateescape').write(src[n])
    open('%s/%s.ref' % (sys.argv[3], g), 'w', encoding='utf-8', errors='surrogateescape').write(ref[n])
PY
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-13s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-13s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-13s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-13s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in literals exact builtins smartmatch rounding fatrat argument testmod; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in exact rounding fatrat argument; do for m in m3 m4; do ck "$w" "$m"; done; done; done
fx_bad=0; fx_n=0
for f in "$FX"/sno_*.sno "$FX"/icn_*.icn; do
    b="$(basename "${f%.*}")"
    for m in m3 m4; do
        fx_n=$((fx_n + 1)); GATE_EXAMINED=$((GATE_EXAMINED + 1))
        if [ "$m" = m3 ]; then want="$FX/$b.ref"; got="$(cd "$FX" && timeout -k 5 30 "$ROOT/scrip" "$(basename "$f")" </dev/null 2>&1; echo "rc=$?")"
        else
            want="$FX/$b.ref4"
            if (cd "$FX" && timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$b.s" "$(basename "$f")" </dev/null >"$W/$b.cerr" 2>&1) && gcc -o "$W/$b.bin" "$W/$b.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$b.cerr" 2>&1; then
                got="$(cd "$FX" && timeout -k 5 30 "$W/$b.bin" </dev/null 2>&1; echo "rc=$?")"
            else got="COMPILE-FAIL: $(head -1 "$W/$b.cerr" | cut -c1-100)
rc=1"; fi
        fi
        if [ "$got" != "$(cat "$want")" ]; then fx_bad=$((fx_bad + 1)); printf '  FAIL %-10s %s: the base binary printed [%s], this one [%s]\n' "$b" "$m" "$(tr '\n' '|' < "$want" | cut -c1-80)" "$(printf '%s' "$got" | tr '\n' '|' | cut -c1-80)"; fi
    done
done
[ "$fx_bad" = 0 ] && printf '  ok   %d other-language fixture runs (SNOBOL4 DATA RAT, Icon record Rat; modes 3 and 4) byte-identical to the base binary\n' "$fx_n"
fails=$((fails + fx_bad))
gate_verdict "$fails" "witness-mode pair(s) or other-language fixture(s) wrong: the Rat type disagrees with Rakudo or changed a program that has its own Rat"

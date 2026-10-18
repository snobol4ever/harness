#!/usr/bin/env bash
# test_gate_raku_rat_base_prints_the_fraction_digits_rakudo_prints.sh -- Rat.base(radix[, digits]) OF A NON-INTEGRAL RAT
# (row raku-rat-base-of-a-non-integral-rat-prints-its-fraction-digits-as-rakudo-does; the cto's Rat review RULING 2, 2026-10-10).
#
# THE DEFECT: .base on a non-integral Rat printed nothing and exited 0 (a silent wrong answer): rk_rat_dispatch had only the integral case.
# THE CURE: rk_rat.c rk_rat_base follows Rakudo's Rational.base (src/core.c/Rational.rakumod): with no digit count, 6 digits when the denominator is below radix**6, else
# ceil(log_radix(denominator)) + 1, trailing zeros stripped; with a digit count, that many digits kept; 0 digits is .round.base; the fraction is rounded half up and a carry
# moves into the whole part; the 1e0 floating-noise guard kept. Exact arithmetic on the numerator and denominator throughout (bi_*), digits 0-9A-Z.
# THE WITNESS, graded in m3 and m4 against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes: 17 cases (hex, binary, base 36, negative, the
# carry 0.99.base(10, 1), digit counts 0, 3, 4 and 5, long periodic and long-denominator fractions).
# FAILED ONCE, measured on SCRIP 530987afb before the cure: every line empty.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash; 2 REFUSED (stale binary, no gcc).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_rat_base_prints_the_fraction_digits_rakudo_prints"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/ratbase.raku" <<'EOF'
say 11.1.base(16);
say (1/3).base(10, 5);
say 3.75.base(2);
say (-2.5).base(16);
say 0.1.base(3, 4);
say 255.5.base(16);
say 2.5.base(10, 0);
say (-2.5).base(10, 0);
say 3.5.base(2, 3);
say 0.99.base(10, 1);
say (1/7).base(10);
say (22/7).base(16);
say (1/1000003).base(10);
say 0.5.base(36);
say (-0.0625).base(2);
say 7.0.base(2);
say (10/4).base(10, 4);
EOF
cat > "$W/ratbase.ref" <<'EOF'
B.19999A
0.33333
11.11
-2.8
0.0022
FF.8
3
-2
11.100
1.0
0.142857
3.249249
0.000001
0.I
-0.0001
111
2.5000
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc ent
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} SCRIP_C2BB_TRACE="$W/$w.$m.tr" timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(env ${ST:+SCRIP_GC_STRESS=$ST} SCRIP_C2BB_TRACE="$W/$w.$m.tr" timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ne 0 ]; then printf '  FAIL %-7s %s%s: died rc=%s\n' "$w" "$m" "${ST:+ stress=$ST}" "$rc"; fails=$((fails + 1)); return; fi
    ent=0; [ -s "$W/$w.$m.tr" ] && ent=$(grep -vc '\.open	' "$W/$w.$m.tr"); rm -f "$W/$w.$m.tr"
    if [ "$ent" != 0 ]; then printf '  FAIL %-7s %s: %s non-open C-to-BB entries (want 0)\n' "$w" "$m" "$ent"; fails=$((fails + 1)); return; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-7s %s%s: got [%s] want [%s]\n' "$w" "$m" "${ST:+ stress=$ST}" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in ratbase; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in ratbase; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a Rat.base that disagrees with Rakudo or a crash"

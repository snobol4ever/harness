#!/bin/bash
# Icon exponentiation must RAISE the oracle's arithmetic runtime errors, not substitute a failure
# port or a NaN value and keep running. Row icon-pow-error-cases-fail-or-print-nan-instead-of-raising-204-and-206.
#
# Measured 2026-09-05 (hq_B, SCRIP e5b9f3333, RT_OPT=-O0), identical in BOTH modes:
#   0 ^ (-1)     oracle iconx: 'before' then Run-time error 204, rc=1  | SCRIP: 'before','after', rc=0
#                ⛔ the middle write NEVER RUNS -- the operator FAILED rather than erroring, and in Icon
#                expression failure is a CONTROL-FLOW SIGNAL, so this does not merely lose a diagnostic,
#                it can silently redirect an if/every/while written to depend on the error halting.
#   (-2.0) ^ 0.5 oracle iconx: 'before' then Run-time error 206, rc=1  | SCRIP: 'before','nan','after', rc=0
#
# These are the two named reds of the Icon rungs board (ladder_rung26_pow_pow_zero_negexp,
# ladder_rung26_pow_pow_negbase_real) and the reason its watermark pins at 607 and not 609.
# ALL.wantrc requires rc=1 and ALL.ref requires stdout to be exactly 'before' for both.
#
# ⭐⭐ THE TWO ARMS ABOVE ASSERT AN ABSENCE, AND seat05's WITNESS AUDIT (2026-09-05) IS RIGHT THAT AN
# ABSENCE IS A WEAK ASSERTION: rc=1 with stdout "before" also passes if SCRIP raises the WRONG error
# NUMBER, which is the exact shape that would survive a future regression unnoticed. So five ORACLE-
# GRADED arms were added 2026-09-06 with the cure, each trapping the error with &error and printing
# &errornumber, which asserts the CODE and not merely the halt:
#   0 ^ (-1) trapped        -> 204        (-2.0) ^ 0.5 trapped -> 206
#   0 ^ 0                   -> 204        2.0 ^ 10000          -> 204   (overflow, not a value)
#   (-2.0) ^ 2.0            -> 206   ⛔ NEGATIVE BASE IS 206 EVEN FOR AN INTEGRAL REAL EXPONENT --
#                                    measured against iconx, and the arm exists because the obvious
#                                    reading ("only non-integral exponents are illegal") is wrong.
# Expectations come from a LIVE iconx run, never hardcoded, so these cannot drift from the oracle.
#
# ⛔ A GATE THAT CANNOT MEASURE REFUSES rc=2 -- never skip-as-success (RULES.md). All FOURTEEN runs
# (7 witnesses x 2 modes) must be graded or this refuses; it can never fall through to a green.
# ⭐ Proved THREE ways when written: rc=1 today naming all four, rc=2 on an unreachable tree, and
# rc=0 against a stub that behaves correctly -- the last arm on purpose, because a criterion nobody
# has ever seen go green is indistinguishable from one that CANNOT (this session cured exactly that
# defect on the snoflake row's own DONE-WHEN).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT" || exit 2
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "⛔ GATE REFUSES (rc=2): scrip/runtime not built at $ROOT"; exit 2; }
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
printf 'procedure main()\n  write("before");\n  write(0 ^ (-1));\n  write("after");\nend\n'      > "$d/zero_negexp.icn"
printf 'procedure main()\n  write("before");\n  write((-2.0) ^ 0.5);\n  write("after");\nend\n' > "$d/negbase_real.icn"
ICONT=/home/resources/icon-master/bin/icont; ICONX=/home/resources/icon-master/bin/iconx
[ -x "$ICONT" ] && [ -x "$ICONX" ] || { echo "⛔ GATE REFUSES (rc=2): Icon oracle missing at $ICONT / $ICONX -- it is NOT on PATH, so command -v answers a narrower question than this gate is asking"; exit 2; }
printf 'procedure main()\n  &error := 1;\n  write("before");\n  write(0 ^ (-1));\n  write("num=", &errornumber);\nend\n'      > "$d/zero_negexp_trapped.icn"
printf 'procedure main()\n  &error := 1;\n  write("before");\n  write((-2.0) ^ 0.5);\n  write("num=", &errornumber);\nend\n' > "$d/negbase_real_trapped.icn"
printf 'procedure main()\n  &error := 1;\n  write("before");\n  write(0 ^ 0);\n  write("num=", &errornumber);\nend\n'        > "$d/zero_zero_trapped.icn"
printf 'procedure main()\n  &error := 1;\n  write("before");\n  write(2.0 ^ 10000);\n  write("num=", &errornumber);\nend\n'  > "$d/overflow_trapped.icn"
printf 'procedure main()\n  &error := 1;\n  write("before");\n  write((-2.0) ^ 2.0);\n  write("num=", &errornumber);\nend\n' > "$d/negbase_intexp_trapped.icn"
graded=0; bad=0
for w in zero_negexp_trapped negbase_real_trapped zero_zero_trapped overflow_trapped negbase_intexp_trapped; do
    "$ICONT" -s -o "$d/$w.ora" "$d/$w.icn" >/dev/null 2>&1 || { echo "⛔ GATE REFUSES (rc=2): icont rejected $w -- cannot measure"; exit 2; }
    want=$(timeout -k 5 20 "$ICONX" "$d/$w.ora" </dev/null 2>/dev/null); wrc=$?
    [ "$wrc" != 124 ] || { echo "⛔ GATE REFUSES (rc=2): the ORACLE timed out on $w -- cannot measure"; exit 2; }
    o=$(timeout -k 5 20 ./scrip "$d/$w.icn" </dev/null 2>/dev/null); r=$?; graded=$((graded+1))
    if [ "$o" != "$want" ] || [ "$r" != "$wrc" ]; then
        echo "  ⛔ RED m3 $w: rc=$r stdout=[$(printf '%s' "$o" | tr '\n' '|')] -- iconx rc=$wrc stdout=[$(printf '%s' "$want" | tr '\n' '|')]"; bad=1
    fi
    if timeout -k 5 120 ./scrip --compile -o "$d/$w.s" "$d/$w.icn" </dev/null >/dev/null 2>&1 \
       && gcc -m64 -no-pie "$d/$w.s" -o "$d/$w.m4" -L./out -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null; then
        o=$(timeout -k 5 20 "$d/$w.m4" </dev/null 2>/dev/null); r=$?; graded=$((graded+1))
        if [ "$o" != "$want" ] || [ "$r" != "$wrc" ]; then
            echo "  ⛔ RED m4 $w: rc=$r stdout=[$(printf '%s' "$o" | tr '\n' '|')] -- iconx rc=$wrc stdout=[$(printf '%s' "$want" | tr '\n' '|')]"; bad=1
        fi
    else
        graded=$((graded+1)); echo "  ⛔ RED m4 $w: does not compile/link"; bad=1
    fi
done
for w in zero_negexp negbase_real; do
    o=$(timeout -k 5 10 ./scrip "$d/$w.icn" </dev/null 2>/dev/null); r=$?; graded=$((graded+1))
    if [ "$o" != "before" ] || [ "$r" != 1 ]; then
        echo "  ⛔ RED m3 $w: rc=$r stdout=[$(printf '%s' "$o" | tr '\n' '|')] -- want rc=1 stdout=[before]"; bad=1
    fi
    timeout -k 5 60 ./scrip --compile -o "$d/$w.s" "$d/$w.icn" </dev/null >/dev/null 2>&1 \
        || { echo "⛔ GATE REFUSES (rc=2): mode-4 compile failed for $w"; exit 2; }
    gcc -m64 -no-pie "$d/$w.s" -o "$d/$w.m4" -L./out -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null \
        || { echo "⛔ GATE REFUSES (rc=2): mode-4 link failed for $w"; exit 2; }
    o=$(timeout -k 5 10 "$d/$w.m4" </dev/null 2>/dev/null); r=$?; graded=$((graded+1))
    if [ "$o" != "before" ] || [ "$r" != 1 ]; then
        echo "  ⛔ RED m4 $w: rc=$r stdout=[$(printf '%s' "$o" | tr '\n' '|')] -- want rc=1 stdout=[before]"; bad=1
    fi
done
[ "$graded" = 14 ] || { echo "⛔ GATE REFUSES (rc=2): graded $graded of the 14 required runs"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ GATE RED [icn_pow_error_cases]: Icon '^' does not raise on the oracle's error cases"; exit 1; }
echo "✅ GATE OK [icn_pow_error_cases]: both untrapped forms raise (rc=1, stdout=before) and all five trapped forms report the oracle's own error NUMBER -- BOTH modes"

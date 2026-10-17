#!/bin/bash
# When &error is set, Icon converts a run-time error into a FAILURE of the offending expression: the
# error is recorded in &errornumber/&errortext and evaluation CONTINUES. SCRIP records the error and
# then carries on as if nothing had failed, which is two very different symptoms with one root. Row
# icon-error-conversion-records-the-error-but-does-not-fail-the-expression.
#
# ⛔ ONE OF THE TWO SYMPTOMS IS A HANG, WHICH IS WHY THIS GATE TIMES OUT AND CALLS IT RED rather than
# leaving the runner to hang: `&error := 1; every write(1 to 5 by 0)` prints 1 forever at ~100% CPU
# (seat05 confirmed it twice, once live via ps) because core_icn_by_zero_check absorbs error 211 and
# returns, so the generator restarts from its first value instead of failing. iconx prints nothing and
# reaches the next statement with &errornumber = 211. The second symptom is silent in the other
# direction: `runerr(500)` under &error aborts the program, where iconx converts it to a failure --
# by_name_dispatch's runerr arm prints and exits(1) without ever consulting the &error state.
#
# ⭐ THE UNTRAPPED ARMS ARE CONTROL ARMS AND THEY ARE THE POINT: with &error unset, `by 0` and
# `runerr` must STILL abort with their error. A cure that makes them fail unconditionally would turn
# every uncaught Icon run-time error into a silent failure -- far worse than the defect -- and those
# two arms are what catch it.
# ⭐ A NEGATIVE &error COUNTS DOWN THROUGH EVERY NEGATIVE VALUE (iconx: -1 -> -2 -> -3 ...), so the count shares g_error with the
# SNOBOL4 evaluation stage and must never meet it: 4ff9addec spelled that stage -3, and the THIRD converted error of `&error := -1`
# went fatal (rungs rung29 operator-value witnesses and procedure_record_every_replace_12, bisected by hq_icon 2026-09-27). The
# neg_countdown witness converts four errors from -1 and prints &error; the stage is G_ERROR_EVAL_STAGE (keywords.h) since.
# ⛔ REFUSES rc=2 unless all 12 runs (6 witnesses x 2 modes) are graded, and rc=2 if the oracle is
# missing. Expectations come from a LIVE iconx run, never hardcoded.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || exit 2
ICONT=/home/resources/icon-master/bin/icont; ICONX=/home/resources/icon-master/bin/iconx
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "⛔ GATE REFUSES (rc=2): scrip/runtime not built at $ROOT"; exit 2; }
[ -x "$ICONT" ] && [ -x "$ICONX" ] || { echo "⛔ GATE REFUSES (rc=2): Icon oracle missing at $ICONT / $ICONX"; exit 2; }
d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT
printf 'procedure main()\n  &error := 1;\n  every write(1 to 5 by 0);\n  write("after=", &errornumber);\nend\n' > "$d/by_zero_trapped.icn"
printf 'procedure main()\n  &error := 1;\n  runerr(500);\n  write("caught=", &errornumber);\nend\n'             > "$d/runerr_trapped.icn"
printf 'procedure main()\n  every write(1 to 5 by 0);\nend\n'                                                   > "$d/by_zero_untrapped.icn"
printf 'procedure main()\n  runerr(500);\nend\n'                                                                > "$d/runerr_untrapped.icn"
printf 'procedure main()\n  every write(1 to 5 by 2);\nend\n'                                                   > "$d/by_two.icn"
printf 'procedure main()\n  &error := -1;\n  every 1 to 4 do write(&null + 1 | &errornumber);\n  write("error=", &error);\nend\n' > "$d/neg_countdown.icn"
graded=0; bad=0
for w in by_zero_trapped runerr_trapped by_zero_untrapped runerr_untrapped by_two neg_countdown; do
    "$ICONT" -s -o "$d/$w.ora" "$d/$w.icn" >/dev/null 2>&1 || { echo "⛔ GATE REFUSES (rc=2): icont rejected $w -- cannot measure"; exit 2; }
    want=$(timeout -k 5 20 "$ICONX" "$d/$w.ora" </dev/null 2>/dev/null); wrc=$?
    [ "$wrc" != 124 ] || { echo "⛔ GATE REFUSES (rc=2): the ORACLE timed out on $w -- cannot measure"; exit 2; }
    o=$(timeout -k 5 20 ./scrip "$d/$w.icn" </dev/null 2>/dev/null); r=$?; graded=$((graded+1))
    if [ "$r" = 124 ]; then echo "  ⛔ RED m3 $w: HANGS (SIGTERM at 20s) -- iconx rc=$wrc out=[$(printf '%s' "$want" | tr '\n' '|')]"; bad=1
    elif [ "$o" != "$want" ] || [ "$r" != "$wrc" ]; then
        echo "  ⛔ RED m3 $w: rc=$r out=[$(printf '%s' "$o" | tr '\n' '|' | cut -c1-60)] -- iconx rc=$wrc out=[$(printf '%s' "$want" | tr '\n' '|' | cut -c1-60)]"; bad=1
    fi
    if timeout -k 5 120 ./scrip --compile -o "$d/$w.s" "$d/$w.icn" </dev/null >/dev/null 2>&1 \
       && gcc -m64 -no-pie "$d/$w.s" -o "$d/$w.m4" -L./out -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null; then
        o=$(timeout -k 5 20 "$d/$w.m4" </dev/null 2>/dev/null); r=$?; graded=$((graded+1))
        if [ "$r" = 124 ]; then echo "  ⛔ RED m4 $w: HANGS (SIGTERM at 20s) -- iconx rc=$wrc out=[$(printf '%s' "$want" | tr '\n' '|')]"; bad=1
        elif [ "$o" != "$want" ] || [ "$r" != "$wrc" ]; then
            echo "  ⛔ RED m4 $w: rc=$r out=[$(printf '%s' "$o" | tr '\n' '|' | cut -c1-60)] -- iconx rc=$wrc out=[$(printf '%s' "$want" | tr '\n' '|' | cut -c1-60)]"; bad=1
        fi
    else
        graded=$((graded+1)); echo "  ⛔ RED m4 $w: does not compile/link"; bad=1
    fi
done
[ "$graded" = 12 ] || { echo "⛔ GATE REFUSES (rc=2): graded $graded of the 12 required runs"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ GATE RED [icn_error_conversion_fails_the_expression]: an absorbed error still does not fail its expression"; exit 1; }
echo "✅ GATE OK [icn_error_conversion_fails_the_expression]: &error converts to failure and evaluation continues; untrapped errors still abort -- BOTH modes"

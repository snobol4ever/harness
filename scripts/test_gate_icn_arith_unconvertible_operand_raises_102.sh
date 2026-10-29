#!/bin/bash
# Icon arithmetic on an operand that cannot be converted to a number must raise RUN-TIME ERROR 102
# ("numeric expected"). SCRIP silently coerces the operand to 0 instead: `x := "abc"; write(2 + x)`
# prints 2 where iconx errors and exits 1. Row
# icon-arith-unconvertible-operand-coerces-to-zero-instead-of-raising-error-102 (raised by seat05 on
# rung41, and it is the root cause of the rung41/rung42 &error, &errornumber and errorclear reds --
# there is never a real error event for them to catch).
#
# ⭐ THE CONTROL ARMS ARE THE POINT OF THIS GATE, not decoration: Icon DOES convert numeric strings,
# so "12" + 2 is 14 and "3" * "4" is 12, and a cure that makes every string operand an error would
# break far more than it fixes. Those two arms fail loudly here if that happens.
#
# ⛔ HOW THE ERROR ARMS ARE GRADED, and why not byte-for-byte: iconx writes
#   Run-time error 102 / File f.icn; Line N / numeric expected / offending value: "abc"
# on stderr with a file and line SCRIP does not carry. Grading that text byte-for-byte would pin our
# diagnostics to icont's source layout, which is not the semantics under test. So each error arm is
# graded on the THREE things that are the semantics: STDOUT identical to iconx (nothing printed --
# the expression must not produce a value), rc identical to iconx, and SCRIP's stderr naming code 102.
# ⛔ REFUSES rc=2 unless all 10 runs (5 witnesses x 2 modes) are graded, and rc=2 if icont/iconx are
# missing -- these live under /home/resources and are NOT on PATH, so `command -v` answers a narrower
# question than this gate is asking.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || exit 2
ICONT=/home/resources/icon-master/bin/icont; ICONX=/home/resources/icon-master/bin/iconx
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "⛔ GATE REFUSES (rc=2): scrip/runtime not built at $ROOT"; exit 2; }
[ -x "$ICONT" ] && [ -x "$ICONX" ] || { echo "⛔ GATE REFUSES (rc=2): Icon oracle missing at $ICONT / $ICONX"; exit 2; }
d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT
printf 'procedure main()\n  x := "abc";\n  write(2 + x);\nend\n'                                             > "$d/bad_add.icn"
printf 'procedure main()\n  x := "abc";\n  write(-x);\nend\n'                                                > "$d/bad_neg.icn"
printf 'procedure main()\n  x := "12";\n  write(2 + x);\nend\n'                                              > "$d/good_numstr.icn"
printf 'procedure main()\n  write(2 + 3);\n  write("3" * "4");\nend\n'                                       > "$d/good_plain.icn"
printf 'procedure main()\n  &error := 1;\n  x := "abc";\n  y := 2 + x;\n  write("err=", &errornumber);\nend\n' > "$d/error_convert.icn"
needs102_bad_add=1; needs102_bad_neg=1; needs102_good_numstr=0; needs102_good_plain=0; needs102_error_convert=0
graded=0; bad=0
for w in bad_add bad_neg good_numstr good_plain error_convert; do
    eval "need=\$needs102_$w"
    "$ICONT" -s -o "$d/$w.ora" "$d/$w.icn" >/dev/null 2>&1 || { echo "⛔ GATE REFUSES (rc=2): icont rejected $w -- cannot measure"; exit 2; }
    want=$(timeout -k 5 20 "$ICONX" "$d/$w.ora" </dev/null 2>/dev/null); wrc=$?
    o=$(timeout -k 5 20 ./scrip "$d/$w.icn" </dev/null 2>"$d/$w.m3err"); r=$?; graded=$((graded+1))
    if [ "$o" != "$want" ] || [ "$r" != "$wrc" ]; then
        echo "  ⛔ RED m3 $w: rc=$r stdout=[$(printf '%s' "$o" | tr '\n' '|' | cut -c1-60)] -- iconx rc=$wrc stdout=[$(printf '%s' "$want" | tr '\n' '|' | cut -c1-60)]"; bad=1
    elif [ "$need" = 1 ] && ! grep -q "102" "$d/$w.m3err"; then
        echo "  ⛔ RED m3 $w: right stdout and rc, but stderr never names error 102: [$(head -c 90 "$d/$w.m3err" | tr '\n' '|')]"; bad=1
    fi
    if timeout -k 5 120 ./scrip --compile --out="$d/$w.s" "$d/$w.icn" </dev/null >/dev/null 2>&1 \
       && gcc -m64 -no-pie "$d/$w.s" -o "$d/$w.m4" -L./out -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null; then
        o=$(timeout -k 5 20 "$d/$w.m4" </dev/null 2>"$d/$w.m4err"); r=$?; graded=$((graded+1))
        if [ "$o" != "$want" ] || [ "$r" != "$wrc" ]; then
            echo "  ⛔ RED m4 $w: rc=$r stdout=[$(printf '%s' "$o" | tr '\n' '|' | cut -c1-60)] -- iconx rc=$wrc stdout=[$(printf '%s' "$want" | tr '\n' '|' | cut -c1-60)]"; bad=1
        elif [ "$need" = 1 ] && ! grep -q "102" "$d/$w.m4err"; then
            echo "  ⛔ RED m4 $w: right stdout and rc, but stderr never names error 102: [$(head -c 90 "$d/$w.m4err" | tr '\n' '|')]"; bad=1
        fi
    else
        graded=$((graded+1)); echo "  ⛔ RED m4 $w: does not compile/link"; bad=1
    fi
done
[ "$graded" = 10 ] || { echo "⛔ GATE REFUSES (rc=2): graded $graded of the 10 required runs"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ GATE RED [icn_arith_unconvertible_operand]: arithmetic still swallows an unconvertible operand"; exit 1; }
echo "✅ GATE OK [icn_arith_unconvertible_operand]: error 102 raised, numeric strings still convert, &error still converts to failure -- BOTH modes"

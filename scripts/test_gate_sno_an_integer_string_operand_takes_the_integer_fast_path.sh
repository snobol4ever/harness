#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_an_integer_string_operand_takes_the_integer_fast_path.sh -- AN ARITHMETIC ON TWO NUMERIC STRINGS USED TO PARSE EACH
# OPERAND SIX TO EIGHT TIMES: big_str_operand (strtoll), is_numeric_like (a scan, then strtod), operand_is_real_str (strtoll and
# strtod), to_real (strtod), to_int (strtoll), behind a setjmp and an Icon error context -- about 1,700 Ir per "12" + "3" at -O0,
# 47 M of the calculator demo's 373 M (ceo 2026-09-25, CEO-1257; notebook section 17). Since this landing every RT_BINOP_ENTRY
# tests the two operands with rt_int_str_operand first (blanks, an optional sign, digits, blanks, exactly the run of the descriptor
# and no overflow), and a pair of integer strings takes the same fast block a pair of integers takes; anything else (reals, empty,
# overflow, a non-numeric shape, DATA) falls through to the unchanged general path with the ORIGINAL operands.
# ARMS: (1) the witness prints the oracle's lines in m3 and m4 (blanks, tabs, signs, leading zeros, a real, an empty string, an
# int64 product, mixed int and string, REMDR, DATATYPE of the result); (2) the instruction slope per string addition, read by
# callgrind over two iteration counts of the same twin, is under 1,000 Ir -- the slope is the whole loop body (the string
# addition, its assignment, the LT predicate, the counter's integer addition and the branch), of which the pre-cure string
# addition alone was ~1,700 with its setjmp and error context (pre-cure slope 3,525).
# FAIL_ONCE (recorded): the pre-cure runtime at 71f47a9b1 read 3,525 Ir per iteration; this tree reads 675.
# ⛔ A NON-NUMERIC operand ('x' + 1) is left out: SPITBOL raises ERROR 001 where SCRIP fails the statement -- a standing divergence,
# not this gate's subject. EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle, valgrind or the build missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
command -v valgrind >/dev/null 2>&1 || { echo "REFUSED(2): valgrind missing -- arm 2 is an instruction slope"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/arith.sno" <<'SNO'
        tab = CHAR(9)
        a = '12'; b = '3'
        OUTPUT = a + b
        a = ' 7 '; b = '2'
        OUTPUT = a * b
        a = '-4'; b = '+4'
        OUTPUT = a - b
        a = '1.5'
        OUTPUT = a + 1
        a = ''
        OUTPUT = a + 1
        a = '  '
        OUTPUT = a + 2
        a = '7'; b = '2'
        OUTPUT = a / b
        b = '-1'
        OUTPUT = a / b
        a = '12'
        OUTPUT = a - 3.0
        a = '3'
        OUTPUT = 5 * a
        a = '0012'; b = '0'
        OUTPUT = a + b
        a = '+5'; b = '-5'
        OUTPUT = a + b
        a = '3'; b = '4'; c = '2'
        OUTPUT = (a + b) (c * c)
        OUTPUT = DATATYPE(a + b)
        a = '17'; b = '5'
        OUTPUT = REMDR(a, b) ' ' a * 1.0
        a = tab '42' tab
        OUTPUT = a + 0
        a = '-0'
        OUTPUT = a + 0 ' ' DATATYPE(a + 0)
        a = '007'; b = '003'
        OUTPUT = a + b ' ' a - b ' ' a * b ' ' a / b
        a = '2147483648'; b = '2147483648'
        OUTPUT = a * b
        a = '-9223372036854775807'; b = '1'
        OUTPUT = a - b
        n = 0
loop    s = s + 1
        n = LT(n, 5) n + 1                              :S(loop)
        OUTPUT = s ' ' DATATYPE(s)
END
SNO
"$SBL" $(sbl_lang_flags) "$W/arith.sno" < /dev/null > "$W/arith.ref" 2>&1 || true
[ -s "$W/arith.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the witness"; exit 2; }
red=0
( cd "$W" && timeout -k 5 20 "$ROOT/scrip" arith.sno < /dev/null > "$W/arith.m3" 2>&1 ); cmp -s "$W/arith.m3" "$W/arith.ref" && echo "ok  (1) m3 = oracle over $(wc -l < "$W/arith.ref") lines" || { echo "RED (1) m3 differs from the oracle:"; diff "$W/arith.ref" "$W/arith.m3" | head -6; red=1; }
( cd "$W" && "$ROOT/scrip" --compile -o "$W/arith.s" arith.sno < /dev/null > /dev/null 2>&1 && gcc "$W/arith.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/arith.bin" 2>/dev/null ) || { echo "REFUSED(2): the witness did not build in mode 4"; exit 2; }
( cd "$W" && timeout -k 5 20 ./arith.bin < /dev/null > "$W/arith.m4" 2>&1 ); cmp -s "$W/arith.m4" "$W/arith.ref" && echo "ok  (1) m4 = oracle" || { echo "RED (1) m4 differs from the oracle:"; diff "$W/arith.ref" "$W/arith.m4" | head -6; red=1; }
for n in 4000 8000; do cat > "$W/slope$n.sno" <<SNO
        a = '1234'; b = '5678'; n = 0
loop    s = a + b
        n = LT(n, $n) n + 1                             :S(loop)
        OUTPUT = s
END
SNO
( cd "$W" && "$ROOT/scrip" --compile -o "$W/slope$n.s" slope$n.sno < /dev/null > /dev/null 2>&1 && gcc "$W/slope$n.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/slope$n.bin" 2>/dev/null ) || { echo "REFUSED(2): the slope twin $n did not build"; exit 2; }
( cd "$W" && timeout -k 5 300 valgrind --tool=callgrind --callgrind-out-file="$W/cg$n.out" ./slope$n.bin < /dev/null > "$W/slope$n.out" 2>/dev/null ); grep -q '^6912$' "$W/slope$n.out" || { echo "REFUSED(2): the slope twin $n did not print 6912"; exit 2; }
eval "ir$n=\$(grep '^summary:' \"\$W/cg$n.out\" | awk '{print \$2}')"
done
[ -n "${ir4000:-}" ] && [ -n "${ir8000:-}" ] || { echo "REFUSED(2): callgrind printed no summary"; exit 2; }
per=$(( (ir8000 - ir4000) / 4000 ))
if [ "$per" -lt 1000 ]; then echo "ok  (2) $per Ir per loop iteration with one string addition (slope over 4,000 iterations) < 1000"
else echo "RED (2) $per Ir per loop iteration >= 1000: the string operands are being parsed the long way again"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: two integer strings take the integer fast path and every shape still answers the oracle"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1

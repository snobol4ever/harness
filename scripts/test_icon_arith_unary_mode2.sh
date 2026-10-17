#!/bin/bash
# test_icon_arith_unary_mode2.sh — Icon mode-2 (--run) arithmetic/unary oracle gate.
#
# Locks in two foundation correctness fixes (and the surrounding verified-correct
# behavior) so a future change that regresses them is caught:
#   * IR_UNOP exec arm (commit 8615c04): unary - + * \ ~ compute (were silently failing).
#   * BINOP_POW integer result (commit de0ce21): int ^ nonneg-int -> integer, not real.
# Grounded in canonical Icon refs/icon-master/src/runtime/oarith.r (^ / iipow / bigpowii)
# and ocomp.r (relops). Mode-2 (--run) is the GOAL-ICON-BB oracle (HARD gate).
#
# Each case: a one-statement procedure, run through `scrip --run`, output compared
# to the expected Icon value. Exits 0 iff every case matches.
set -u
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIP="${SCRIP:-$SCRIPT_DIR/../../SCRIP/scrip}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
PASS=0
FAIL=0
check() {
    desc="$1"; expr="$2"; want="$3"
    printf 'procedure main()\n   %s\nend\n' "$expr" > "$TMP/p.icn"
    got=$("$SCRIP" --run "$TMP/p.icn" < /dev/null 2>/dev/null | head -1)
    if [ "$got" = "$want" ]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        printf '  [FAIL] %-32s want=%-12s got=%s\n' "$desc" "$want" "$got"
    fi
}
echo "=== Icon mode-2 arithmetic / unary oracle gate ==="
# unary (IR_UNOP) — the fix in 8615c04
check "neg literal"        'write(-7)'           '-7'
check "neg of expr"        'write(-(3+4))'       '-7'
check "unary + coerce"     'write(+5)'           '5'
check "size *"             'write(*"hello")'     '5'
# integer power (BINOP_POW) — the fix in de0ce21
check "int pow"            'write(2^10)'         '1024'
check "int pow zero exp"   'write(2^0)'          '1'
check "int pow 3^3"        'write(3^3)'          '27'
check "real base pow"      'write(2.0^10)'       '1024.0'
check "frac exp -> real"   'write(2^0.5)'        '1.4142135623730951'
# surrounding verified-correct arithmetic
check "add"                'write(2+3)'          '5'
check "int div trunc"      'write(-17 / 5)'      '-3'
check "mod sign=dividend"  'write(-17 % 5)'      '-2'
check "real div"           'write(7.0 / 2)'      '3.5'
# relational (returns RHS on success; fails -> no output)
check "lt returns rhs"     'write(3 < 5)'        '5'
check "chain lt"           'write(1 < 2 < 3)'    '3'
# string relops + concat coercion
check "string << "         'write("abc" << "abd")' 'abd'
check "string ~=="         'write("abc" ~== "abd")' 'abd'
check "num concat"         'write(1 || 2)'       '12'
# to ... by <step> (jcon ir_a_ToBy; step was dropped -> always 1)
check_multi() {
    desc="$1"; expr="$2"; want="$3"
    printf 'procedure main()\n   %s\nend\n' "$expr" > "$TMP/p.icn"
    got=$("$SCRIP" --run "$TMP/p.icn" < /dev/null 2>/dev/null | paste -sd' ')
    if [ "$got" = "$want" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); printf '  [FAIL] %-32s want=[%s] got=[%s]\n' "$desc" "$want" "$got"; fi
}
check_multi "to by 2"          'every write(1 to 5 by 2)'  '1 3 5'
check_multi "to by 3"          'every write(1 to 6 by 3)'  '1 4'
check_multi "to by -1 (desc)"  'every write(3 to 1 by -1)' '3 2 1'
check_multi "to by -2 (desc)"  'every write(10 to 2 by -2)' '10 8 6 4 2'
check_multi "plain to (step 1)" 'every write(1 to 3)'      '1 2 3'
# Icon := is generator-transparent: `every i := gen do …` re-pumps (jcon ir_binary, := in funcs)
check_multi "every i:=to"      'every i := 1 to 3 do write(i)'      '1 2 3'
check_multi "every i:=to by"   'every i := 1 to 5 by 2 do write(i)' '1 3 5'
check_multi "every i:=alt"     'every j := (10 | 20 | 30) do write(j)' '10 20 30'
check "bounded := unchanged"   'x := 42; write(x)'  '42'
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]

#!/usr/bin/env bash
# test_gate_icn_string_invoked_to_by_is_a_generator.sh -- string invocation of the ternary "..." operator.
#
# WHY THIS EXISTS: TWO ternary operators were unreachable by string invocation -- "..." and "[:]" -- while every
# other Icon operator was already reachable -- "+" "-" "*" "||"
# "<" unary and binary, and "!" which is itself a GENERATOR -- and only "..." raised ERROR 022 Undefined
# function called. It is the one operator whose native form is a generator box AND whose by-name arm was
# missing, so a single-DESCR_t return could not carry it: the cure pumps it through the same ICN_OPGEN_t
# path "!" already used. The arity-3 shape is the oracle's own contract -- icont rejects "..."(1,5) with
# runtime error 106, because `to` and `to by` are one ternary operator in Icon.
#
# THE CONTROL ARMS ARE IN THE TABLE ON PURPOSE: "!" and "+" are graded here beside the cure, because the
# cure inserted an arm AHEAD of the "!" arm in the same dispatch -- a gate that only grades the new
# behaviour cannot see the sibling it displaced. `native` grades `1 to 5 by 2`, which was already correct
# and must stay so: the string form is required to agree with the operator it names, not merely with the oracle.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
NAME=icn_string_invoked_to_by_is_a_generator
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
mk() { printf 'procedure main();\n    every write(%s);\nend\n' "$2" > "$TD/$1.icn"; }
mk toby      '"..."(1,10,2)'
mk toby1     '"..."(1,5,1)'
mk tobyneg   '"..."(5,1,-2)'
mk tobynone  '"..."(5,1,1)'
mk tobystr   '"..."("1","4","1")'
mk procdots  'proc("...",3)(2,6,2)'
mk bang      '"!"([1,2,3])'
mk plus      '"+"(3,4)'
mk section   '"[:]"("abcdef", 3, 5)'
mk sectvar   'x := "abcdef" & "[:]"(x, 2, 4)'
mk subscript '"[]"(&lcase, 3)'
mk native    '1 to 5 by 2'
EXP_toby='1
3
5
7
9'
EXP_toby1='1
2
3
4
5'
EXP_tobyneg='5
3
1'
EXP_tobynone=''
EXP_tobystr='1
2
3
4'
EXP_procdots='2
4
6'
EXP_bang='1
2
3'
EXP_plus='7'
EXP_section='cd'
EXP_sectvar='bc'
EXP_subscript='c'
EXP_native='1
3
5'
GRADED=0; FAIL=0
for w in toby toby1 tobyneg tobynone tobystr procdots section sectvar subscript bang plus native; do
  eval "want=\$EXP_$w"
  for m in 3 4; do
    if [ "$m" = 3 ]; then
      out="$(timeout -k 5 20s "$SCRIP" "$TD/$w.icn" </dev/null 2>&1)"; rc=$?
    else
      "$SCRIP" --compile --out="$TD/$w.s" "$TD/$w.icn" </dev/null >/dev/null 2>&1 || refuse "$w: mode-4 compile failed -- cannot measure"
      gcc -no-pie "$TD/$w.s" -o "$TD/$w.bin" -L "$ROOT/out" -lscrip_rt -lm -lpthread >/dev/null 2>&1 || refuse "$w: mode-4 link failed -- cannot measure"
      out="$(LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20s "$TD/$w.bin" </dev/null 2>&1)"; rc=$?
    fi
    GRADED=$((GRADED+1))
    if [ "$rc" -ne 0 ]; then echo "  FAIL m$m $w: rc=$rc [$out]"; FAIL=$((FAIL+1)); continue; fi
    if [ "$out" != "$want" ]; then
      echo "  FAIL m$m $w: got [$(printf '%s' "$out" | tr '\n' '/')] want [$(printf '%s' "$want" | tr '\n' '/')]"
      FAIL=$((FAIL+1)); continue
    fi
    echo "  PASS m$m $w"
  done
done
[ "$GRADED" -eq 0 ] && refuse "graded zero witnesses"
echo "graded=$GRADED FAIL=$FAIL (toby* procdots section sectvar are the cured path, every expectation cut from icont+iconx; subscript bang plus are control arms that were ALREADY green -- subscript is the sibling ternary that worked, so it proves the section arm did not break its neighbour; native is the operator the string form must agree with)"
if [ "$FAIL" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: FAIL=$FAIL of $GRADED"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $GRADED/$GRADED"
exit 0

#!/usr/bin/env bash
# test_gate_icn_range_operands_must_be_integers.sh -- the IR_TO/IR_TO_BY integer OPERAND CONTRACT.
#
# WHY THIS EXISTS: Icon's `to` requires integer operands and refuses a non-integer with error 101.
# SCRIP coerced silently through raw to_int, so `"a" to 5` GENERATED 0 1 2 3 4 5 where iconx refuses,
# `seq("a")` generated, `5 to "a"` produced NO OUTPUT AND NO ERROR, and repl("x","a") returned empty.
# The checked helper already existed (core_icn_to_int_check) and was reached from exactly two boxes,
# bb_scan_tab and bb_scan_move -- which is why tab and move were the only two builtins already correct.
#
# ⛔ THE RAKU ARM IS THE LOAD-BEARING ONE AND MUST NEVER BE DELETED. IR_TO is lowered by icon=2,
# prolog=5 AND raku=3, so making the box strict outright would raise an ICON error from a RAKU program.
# The strictness is therefore an IR-level OPERAND CONTRACT set by lower_icon and left unset by the
# other two frontends (ir_range_operands_must_be_integers, IR.h). The Raku witnesses below prove the
# contract does not leak. They assert the ABSENCE of an Icon error, NOT a pinned value: SCRIP's Raku
# string range is separately wrong (prints 0 where rakudo gives a,b,c,d,e) and pinning that number
# here would freeze a defect into a gate. Guard the leak; do not bless the bug.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
NAME=icn_range_operands_must_be_integers
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
mk() { printf 'procedure main();\n    %s;\nend\n' "$2" > "$TD/$1.icn"; }
mk refuse_to    'every write("a" to 5)'
mk refuse_from  'every write(5 to "a")'
mk refuse_by    'every write(1 to 5 by "a")'
mk refuse_seq   'every write(seq("a") \ 3)'
mk refuse_repl  'write(repl("x","a"))'
mk refuse_strin 'every write("..."("a",5,1))'
mk neg_repl     'write(repl("x",-1))'
mk ok_numstr    'every write("2" to "4")'
mk ok_realstr   'every write("2.7" to 4)'
mk ok_expstr    'every write("1e2" to 101)'
mk ok_negreal   'every write("-2.7" to 0)'
mk ok_tab       'write("hello" ? tab("2.7"))'
mk ok_native    'every write(1 to 5 by 2)'
mk ok_strinv    'every write("..."(1,10,2))'
EXP_refuse_to='ERR101'; EXP_refuse_from='ERR101'; EXP_refuse_by='ERR101'; EXP_refuse_seq='ERR101'
EXP_refuse_repl='ERR101'; EXP_refuse_strin='ERR101'; EXP_neg_repl='ERR205'
EXP_ok_numstr='2
3
4'
EXP_ok_realstr='2
3
4'
EXP_ok_expstr='100
101'
EXP_ok_negreal='-2
-1
0'
EXP_ok_tab='h'
EXP_ok_native='1
3
5'
EXP_ok_strinv='1
3
5
7
9'
GRADED=0; FAIL=0
grade() { local w="$1" want="$2" got="$3" code; GRADED=$((GRADED+1))
  case "$want" in
    ERR*) code="${want#ERR}"
          if printf '%s' "$got" | grep -q "scrip: error $code:"; then echo "  PASS $w (refused $code)"; else echo "  FAIL $w: expected Run-time error $code, got [$(printf '%s' "$got" | tr '\n' '/' | cut -c1-70)]"; FAIL=$((FAIL+1)); fi ;;
    *)    if [ "$got" = "$want" ]; then echo "  PASS $w"; else echo "  FAIL $w: got [$(printf '%s' "$got" | tr '\n' '/')] want [$(printf '%s' "$want" | tr '\n' '/')]"; FAIL=$((FAIL+1)); fi ;;
  esac
}
for w in refuse_to refuse_from refuse_by refuse_seq refuse_repl refuse_strin neg_repl ok_numstr ok_realstr ok_expstr ok_negreal ok_tab ok_native ok_strinv; do
  eval "want=\$EXP_$w"
  for m in 3 4; do
    if [ "$m" = 3 ]; then out="$(timeout -k 5 20s "$SCRIP" "$TD/$w.icn" </dev/null 2>&1)"
    else
      "$SCRIP" --compile --out="$TD/$w.s" "$TD/$w.icn" </dev/null >/dev/null 2>&1 || refuse "$w: mode-4 compile failed -- cannot measure"
      gcc -no-pie "$TD/$w.s" -o "$TD/$w.bin" -L "$ROOT/out" -lscrip_rt -lm -lpthread >/dev/null 2>&1 || refuse "$w: mode-4 link failed -- cannot measure"
      out="$(LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20s "$TD/$w.bin" </dev/null 2>&1)"
    fi
    grade "m$m $w" "$want" "$out"
  done
done
printf 'my @a = 1 .. 5; say @a.join(",");\n' > "$TD/rk_num.raku"
printf 'my @a = "a" .. "e"; say @a.join(",");\n' > "$TD/rk_str.raku"
rk_num="$(timeout -k 5 20s "$SCRIP" "$TD/rk_num.raku" </dev/null 2>&1)"
GRADED=$((GRADED+1))
if [ "$rk_num" = "1,2,3,4,5" ]; then echo "  PASS raku numeric range (contract did not break it)"; else echo "  FAIL raku numeric range: got [$(printf '%s' "$rk_num" | tr '\n' '/')] want [1,2,3,4,5]"; FAIL=$((FAIL+1)); fi
rk_str="$(timeout -k 5 20s "$SCRIP" "$TD/rk_str.raku" </dev/null 2>&1)"
GRADED=$((GRADED+1))
if printf '%s' "$rk_str" | grep -q 'scrip: error 101:'; then echo "  FAIL raku string range: the Icon operand contract LEAKED into Raku -- got [$(printf '%s' "$rk_str" | tr '\n' '/' | cut -c1-70)]"; FAIL=$((FAIL+1)); else echo "  PASS raku string range (no Icon error; its own value is not pinned here)"; fi
[ "$GRADED" -eq 0 ] && refuse "graded zero witnesses"
echo "graded=$GRADED FAIL=$FAIL (refuse_* and neg_repl are the cured refusals, every code cut from iconx; ok_* are the acceptances that must NOT become strict -- realstr/expstr/negreal are the number grammar, tab is a pre-existing red this cure also flipped; the two raku arms prove the contract does not leak to a frontend that shares IR_TO)"
if [ "$FAIL" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: FAIL=$FAIL of $GRADED"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $GRADED/$GRADED"
exit 0

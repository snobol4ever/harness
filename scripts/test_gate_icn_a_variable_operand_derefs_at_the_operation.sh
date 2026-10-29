#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
NAME=icn_a_variable_operand_derefs_at_the_operation
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
printf '%s\n' 'global i' 'procedure main()' 'i := 1; write(i + (i := 5));' 'end'                                                        > "$TD/se_global.icn"
printf '%s\n' 'global i' 'procedure main()' 'i := "a"; write(i || (i := "b"));' 'end'                                                   > "$TD/se_concat.icn"
printf '%s\n' 'global i' 'procedure main()' 'i := 9; write(i > (i := 1));' 'end'                                                        > "$TD/se_gt.icn"
printf '%s\n' 'procedure main()' 'write(p());' 'end' 'procedure p()' 'static i;' 'i := 1; return i + (i := 5);' 'end'                    > "$TD/se_static.icn"
printf '%s\n' 'procedure main()' 'local i; i := 1; write(i + (i := 5));' 'end'                                                          > "$TD/se_local.icn"
printf '%s\n' 'global G' 'procedure main()' 'local L; L := [1,2,3];' 'G := 0; every G := G + !L; write(G);' 'end'                        > "$TD/gen_global.icn"
printf '%s\n' 'global G' 'procedure main()' 'local L; L := ["a","b","c"];' 'G := ""; every G := G || !L; write(G);' 'end'                > "$TD/gen_concat.icn"
printf '%s\n' 'global G' 'procedure main()' 'local L; L := [1,2,3];' 'G := 0; every G ||:= !L; write(G);' 'end'                          > "$TD/gen_aug.icn"
printf '%s\n' 'global G' 'procedure main()' 'G := 0; every G := G + (1 to 3); write(G);' 'end'                                          > "$TD/gen_to.icn"
printf '%s\n' 'procedure main()' 'write(p());' 'end' 'procedure p()' 'local L; static S;' 'L := [1,2,3]; S := 0;' 'every S := S + !L;' 'return S;' 'end' > "$TD/gen_static.icn"
printf '%s\n' 'procedure main()' 'local L, G; L := [1,2,3];' 'G := 0; every G := G + !L; write(G);' 'end'                                > "$TD/gen_local.icn"
printf '%s\n' 'global G' 'procedure main()' 'local L; L := [1,2,3];' 'G := 0; every G := !L + G; write(G);' 'end'                        > "$TD/gen_right.icn"
printf '%s\n' 'global A, B' 'procedure main()' 'local L; L := [1,2,3]; A := 0; B := 100;' 'every A := A + B + !L; write(A);' 'end'       > "$TD/gen_two.icn"
printf '%s\n' 'global G' 'procedure main()' 'local L, S; L := [1,2,3]; S := 0; G := 10;' 'every S := S + G + !L; write(S);' 'end'        > "$TD/gen_ro.icn"
printf '%s\n' 'procedure main()' 'local A; A := [1]; write(A[1], (A[1] := 2, ""), A[1]);' 'end'                                         > "$TD/identity.icn"
EXP_se_global='10'
EXP_se_concat='bb'
EXP_se_gt=''
EXP_se_static='10'
EXP_se_local='10'
EXP_gen_global='6'
EXP_gen_concat='abc'
EXP_gen_aug='0123'
EXP_gen_to='6'
EXP_gen_static='6'
EXP_gen_local='6'
EXP_gen_right='6'
EXP_gen_two='103'
EXP_gen_ro='13'
EXP_identity='22'
CURED="se_global se_concat se_gt se_static gen_global gen_concat gen_aug gen_to gen_static"
CONTROLS="se_local gen_local gen_right gen_two gen_ro identity"
GRADED=0; FAIL=0
build_m4() { "$SCRIP" --compile --out="$TD/$1.s" "$TD/$1.icn" </dev/null >/dev/null 2>&1 || refuse "$1: mode-4 compile failed -- cannot measure"
  gcc -no-pie "$TD/$1.s" -o "$TD/$1.bin" -L "$ROOT/out" -lscrip_rt -lm -lpthread >/dev/null 2>&1 || refuse "$1: mode-4 link failed -- cannot measure"; }
for w in $CURED $CONTROLS; do
  for m in 3 4; do
    if [ "$m" = 3 ]; then out="$(timeout -k 5 20s "$SCRIP" "$TD/$w.icn" </dev/null 2>&1)"; rc=$?
    else build_m4 "$w"; out="$(LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20s "$TD/$w.bin" </dev/null 2>&1)"; rc=$?; fi
    GRADED=$((GRADED+1))
    [ "$rc" = 124 ] && { echo "  FAIL m$m $w: timed out"; FAIL=$((FAIL+1)); continue; }
    eval "want=\$EXP_$w"
    if [ "$out" != "$want" ]; then
      echo "  FAIL m$m $w: got [$(printf '%s' "$out" | tr '\n' '/')] want [$(printf '%s' "$want" | tr '\n' '/')]"
      FAIL=$((FAIL+1)); continue
    fi
    echo "  PASS m$m $w"
  done
done
[ "$GRADED" -eq 0 ] && refuse "graded zero witnesses"
echo "graded=$GRADED FAIL=$FAIL (9 cured witnesses x2 modes + 6 controls x2, every expectation cut from icont/iconx v9.5.25a: a BARE VARIABLE operand is dereferenced when the operation executes, not when the operand is evaluated -- so a sibling that mutates it, or a generator that resumes past it, is seen. SCRIP was already right for a bare LOCAL by accident, because the operand resolver hands consumers the live varslot; a GLOBAL or a STATIC has no frame varslot and was snapshotted once. The controls are load-bearing: gen_local/se_local are the arms that were already green and must stay green, gen_right proves the read is correct when it already sits after the generator, and identity pins that the VARIABLE IDENTITY is still fixed at evaluation time -- only the dereference is late. NOT GRADED HERE, and uncured: a SUBSCRIPT variable A[1] and a RECORD FIELD r.v still dereference early -- A[1] + (A[1] := 5) gives 6 where iconx gives 10 -- because they are not bare-name operands and need the variable staged as a variable, the shape of the argument-dereference class; pinning our current answer for them would write it into the floor as the expectation)"
if [ "$FAIL" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: FAIL=$FAIL of $GRADED"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $GRADED/$GRADED"
exit 0

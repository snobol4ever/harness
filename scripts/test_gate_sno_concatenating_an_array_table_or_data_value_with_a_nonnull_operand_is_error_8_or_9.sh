#!/usr/bin/env bash
# test_gate_sno_concatenating_an_array_table_or_data_value_with_a_nonnull_operand_is_error_8_or_9.sh -- a SNOBOL4 concatenation whose LEFT operand is an ARRAY, TABLE or DATA instance raises ERROR 8, whose RIGHT one does ERROR 9.
#
# # ⛔ THE DEFECT (row scriptix-demos TixDemo 10/12, the two infinite_snobol4 demos, coo pass 37; found by the baton NEXT of snobol4-every-suite-to-100-under-nonet-ceo-1266): inf_eval.sno line 150 of its input,
#   g(8) f(u[X]) ? ANY('([{')  , concatenates the string g(8) with f(u[X]) -- the ARRAY a, since u[''] is null and a[''] is a[0]. sbl -bf raises ERROR 9 ("concatenation right operand is not a string or pattern"); SCRIP
#   built a STRING from it (str_concat_d stringifies a DT_A, DT_T and a DT_DATA instance: the empty string for an array) and the line read FAIL. The SNOBOL4 lowerer emitted BINOP_CONCAT, which every language shares, so the
#   operand check could not live in str_concat_d (Raku objects and Icon lists concatenate there).
#   THE CURE: BINOP_CONCAT_SNO, emitted by lower_snobol4.c for TT_SEQ and TT_CAT, calls sno_concat_d (string_ops.c): a NULL operand is the identity (sbl: '' a and a '' are a), else a DT_A / DT_T / DATA instance on the left
#   is ERROR 8 and on the right ERROR 9, then FAIL to the omega edge (the box checks DT_FAIL for the new op as it does for LCONCAT) so a SETEXIT trap resumes where sbl's does.
#   NOT CURED HERE (found): sbl groups a chain RIGHT to LEFT, so 'x' a 'z' is ERROR 8 there ('x' (a 'z')) and 9 here (('x' a) 'z') -- the error NUMBER of a chain with a bad middle operand; a lowerer associativity row.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4 BAD OPERANDS: ARRAY, TABLE and DATA on either side, ARRAY on both, a parenthesised ARRAY      -- RED on base (the base answers STRING)
#   3-4  m3 / m4 CONTROLS: null on either side of an ARRAY, string and integer and real operands, a pattern operand, a three-string chain, a failing operand
#   5-6  m3 / m4 inf_eval.sno on its own 200-line input against its committed .ref (the demo's own unit)
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir, the oracle's answer moved, the demo files absent).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
INF="$ROOT/../corpus/demos/scriptix/infinite_snobol4"
NAME=sno_concatenating_an_array_table_or_data_value_with_a_nonnull_operand_is_error_8_or_9
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
[ -f "$INF/inf_eval.sno" ] && [ -f "$INF/inf_eval.in" ] && [ -f "$INF/inf_eval.ref" ] || refuse "no demos/scriptix/infinite_snobol4/inf_eval.{sno,in,ref} under the corpus checkout -- pull corpus"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
mkprog() { local out="$1" n=0 e; shift
    { cat <<'EOS'
        DATA('rec(f)')
        &ERRLIMIT = 1000
        SETEXIT('errh')
        a = ARRAY('0:3'); t = TABLE(); d = rec(1)
        k = 0
        :(go)
errh    SETEXIT('errh')
        OUTPUT = k ' ERROR ' &ERRTYPE                           :(CONTINUE)
go
EOS
      while IFS= read -r e; do n=$((n + 1))
          printf "        k = %d ; r = 'unset'\n        r = %s                                   :S(s%d)F(f%d)\ns%d     OUTPUT = k ' ' DATATYPE(r)                    :(n%d)\nf%d     OUTPUT = k ' FAIL'\nn%d\n" "$n" "$e" "$n" "$n" "$n" "$n" "$n" "$n"
      done
      printf "END\n"; } > "$out"; }
cat > "$T/bad.txt" <<'EOS'
'i' a
a 'i'
'i' t
t 'i'
'i' d
d 'i'
a a
d d
'i' (a)
(t) 'i'
EOS
cat > "$T/ctl.txt" <<'EOS'
'' a
a ''
'' t
d ''
'i' 1
1.5 'i'
's' 'y' 'z'
'i' *a
'x' LT(1,0) 'z'
EOS
mkprog "$T/bad.sno" < "$T/bad.txt"
mkprog "$T/ctl.sno" < "$T/ctl.txt"
want() { timeout -k 5 30 "$SBL" -bf "$T/$1.sno" < /dev/null > "$T/$1.want" 2>/dev/null; [ -s "$T/$1.want" ] || refuse "sbl -bf produced no output for $1 -- the oracle's answer moved"; }
want bad; want ctl
grep -q '^1 ERROR 9$' "$T/bad.want" && grep -q '^2 ERROR 8$' "$T/bad.want" || refuse "sbl -bf no longer answers a string-ARRAY concatenation with ERROR 9 and an ARRAY-string one with ERROR 8"
fail=0; pass=0
arm() { local n="$1" what="$2" ok="$3"
    if [ "$ok" = 1 ]; then pass=$((pass + 1)); echo "  arm $n PASS  $what"; else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; fi; }
same_m3() { local src="$T/$1.sno" want="$T/$1.want" in="${2:-/dev/null}"
    timeout -k 5 60 "$SCRIP" -d131072k -s4096k "$src" < "$in" > "$T/$1.m3" 2>&1
    cmp -s "$want" "$T/$1.m3" || { diff "$want" "$T/$1.m3" | head -6 | sed 's/^/      /'; return 1; }; }
same_m4() { local src="$T/$1.sno" want="$T/$1.want" in="${2:-/dev/null}"
    timeout -k 5 120 "$SCRIP" --compile -o "$T/$1.s" "$src" < /dev/null > /dev/null 2>&1 \
        && gcc -no-pie "$T/$1.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/$1.bin" 2>/dev/null || { echo "      COMPILE-FAILED"; return 1; }
    timeout -k 5 60 "$T/$1.bin" -d131072k -s4096k -- < "$in" > "$T/$1.m4" 2>&1
    cmp -s "$want" "$T/$1.m4" || { diff "$want" "$T/$1.m4" | head -6 | sed 's/^/      /'; return 1; }; }
cp "$INF/inf_eval.sno" "$T/inf.sno"; cp "$INF/inf_eval.ref" "$T/inf.want"
same_m3 bad && arm 1 "m3 BAD OPERANDS: ERROR 8 on the left, ERROR 9 on the right, for ARRAY, TABLE and DATA" 1 || arm 1 "m3 BAD OPERANDS: ERROR 8 on the left, ERROR 9 on the right, for ARRAY, TABLE and DATA" 0
same_m4 bad && arm 2 "m4 BAD OPERANDS: the same" 1 || arm 2 "m4 BAD OPERANDS: the same" 0
same_m3 ctl && arm 3 "m3 CONTROLS: null identity, scalar and pattern operands, a failing operand" 1 || arm 3 "m3 CONTROLS: null identity, scalar and pattern operands, a failing operand" 0
same_m4 ctl && arm 4 "m4 CONTROLS: the same" 1 || arm 4 "m4 CONTROLS: the same" 0
same_m3 inf "$INF/inf_eval.in" && arm 5 "m3 inf_eval.sno on its 200-line input equals its .ref" 1 || arm 5 "m3 inf_eval.sno on its 200-line input equals its .ref" 0
same_m4 inf "$INF/inf_eval.in" && arm 6 "m4 inf_eval.sno on its 200-line input equals its .ref" 1 || arm 6 "m4 inf_eval.sno on its 200-line input equals its .ref" 0
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- an ARRAY, TABLE or DATA operand of a concatenation is ERROR 8 (left) or 9 (right), both modes"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1

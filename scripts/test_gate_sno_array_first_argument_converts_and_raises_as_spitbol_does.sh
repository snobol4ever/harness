#!/usr/bin/env bash
# test_gate_sno_array_first_argument_converts_and_raises_as_spitbol_does.sh -- ARRAY's first argument answers as sbl -bf does, in both modes
# (row snobol4-the-pattern-primitives-len-pos-rpos-tab-rtab-and-array-given-a-non-integer-argument-raise-the-spitbol-fatal-error). SPITBOL's
# s_arr (sbl.min): an argument gtint converts -- an integer, a real (truncated), a numeric string with blanks -- makes a vector of that many
# elements whose PROTOTYPE is the integer; any other STRING is scanned as lo:hi,lo:hi,... keeping the string as given for PROTOTYPE, each bound
# converted by gtint (the null string is 0), and raises 065 for a lower bound that does not convert, 066 for an upper bound, 067 when hi < lo,
# 068 when the element count is too large; anything else is 064. SCRIP read the bounds with strtol, so ARRAY('x') and ARRAY('3,x') raised 067,
# ARRAY('x:3') and ARRAY('1:2:3') built arrays, ARRAY('3,') built one dimension, ARRAY('1.5') kept '1.5', ARRAY(' 3 , 4 ') built ONE dimension,
# ARRAY(TABLE()) built an array, and PROTOTYPE recomputed ':3' as '0:3'. The cure is sno_array_d (both by-name arms: the direct call, EVAL and
# CODE through bn_array; APPLY and OPSYN through the BID arm) and agg_prototype keeping a prototype that starts as a SPITBOL one.
# THE WITNESSES: forms.sno (every form under SETEXIT, one line each: the prototype or the error number) and access.sno (element access on a
# blank-padded 2-D prototype, a ':2' lower bound of 0, a real bound, a real vector, APPLY with a default, a 3-D array), each graded in mode 3
# and mode 4 against the ref sbl -bf prints, CUT FROM THE ORACLE at run time.
# FAIL_ONCE (2026-10-17, bcd8eb18d without the cure): RED 4 of 4 -- forms.sno differs on 27 of its 57 oracle lines in both modes (the
# first: 'x' raises 67 where sbl raises 66), access.sno on 3 of 7 (the blank-padded 2-D prototype built one dimension, PROTOTYPE 2:4).
# rc 0 every arm equals the oracle / 1 an arm diverged / 2 could not measure (no scrip, runtime or oracle, or the oracle printed nothing).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- the ref is cut from the oracle at run time"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cd "$T" || exit 2
{
    printf "\t&ERRLIMIT = 100\n"
    k=0
    for a in "'x'" "'3,x'" "'x,3'" "'x:3'" "'3:x'" "'2:x,3'" "''" "'3,'" "',3'" "'1.5'" "1.5" "ARRAY(2)" "TABLE()" "LEN(2)" "'0'" "'-2'" "'3:1'" \
        "' 3'" "'3 '" "'+3'" "'3:'" "':3'" "'2:3:4'" "'a b'" "'2:5'" "'1:3'" "'-1:2'" "'3,4'" "' 3 , 4 '" "'1:3,2'" "'03'" "'2.7'" "-1.5" "'1e1'" \
        "'1.5,2'" "'2:3.7'" "'1e1,2'" "' ,3'" "'3,,4'" "'2:4,1:2'" "'0:0'" "'-3:-1'" "' 2 : 4 '" "'3:1,2'" "'2,x'" "'x:y'" "'1:2:3'" "'3'" "3" \
        "'9999999999999'" "'2:9999999999999'" "'2,3,4'" "' 3.0'" "'3.9'" "'0,x'" "'1:1,1:1,0'" "4"; do
        k=$((k + 1))
        printf "\tSETEXIT('ERR')\n\tY = ARRAY(%s)\t:F(N%d)\n\tOUTPUT = '%d [' PROTOTYPE(Y) ']'\nN%d\n" "$a" "$k" "$k" "$k"
    done
    printf "\t:(END)\nERR\tOUTPUT = 'error ' &ERRTYPE\t:(CONTINUE)\nEND\n"
} > forms.sno
cat > access.sno <<'EOF'
	A = ARRAY(' 2 : 4 , 3 ', 'd')
	A[4,3] = 'x'
	OUTPUT = A[2,1] A[4,3] '|' PROTOTYPE(A) '|'
	OUTPUT = DIFFER(A[5,1]) 'oob'	:S(N1)
	OUTPUT = 'out of bounds fails'
N1	B = ARRAY(':2')
	B[0] = 'zero'
	OUTPUT = B[0] '|' PROTOTYPE(B) '|'
	C = ARRAY('1.5,2', 7)
	OUTPUT = C[1,2] '|' PROTOTYPE(C)
	E = ARRAY(2.9)
	E[2] = 'two'
	OUTPUT = E[2] '|' PROTOTYPE(E)
	F = APPLY('ARRAY', '3:4,2', 'q')
	OUTPUT = F[4,2] '|' PROTOTYPE(F)
	G = ARRAY('2,3,4', 0)
	G[2,3,4] = 9
	OUTPUT = G[2,3,4] G[1,1,1] '|' PROTOTYPE(G)
END
EOF
RC=0; n=0; red=""
for w in forms access; do
    timeout -k 5 20s "$SBL" -bf $w.sno < /dev/null > $w.ref 2>&1
    [ -s $w.ref ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for $w"; exit 2; }
    timeout -k 5 20s "$SCRIP" $w.sno < /dev/null > $w.m3 2> $w.e3
    if "$SCRIP" --compile --out=$w.s $w.sno < /dev/null > $w.c 2>&1 && gcc $w.s -L"$LIBDIR" -lscrip_rt -lm -Wl,-rpath,"$LIBDIR" -o $w.x 2>> $w.c; then
        timeout -k 5 20s ./$w.x < /dev/null > $w.m4 2> $w.e4
    else echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link failed for $w: $(grep -m1 . $w.c | cut -c1-160)"; exit 2; fi
    for m in m3 m4; do
        n=$((n+1))
        if cmp -s $w.$m $w.ref; then echo "  $w $m PASS ($(wc -l < $w.ref) lines)"
        else echo "  $w $m FAIL ($(diff $w.$m $w.ref | grep -c '^>') of $(wc -l < $w.ref) oracle lines differ; first: $(diff $w.$m $w.ref | grep -m2 '^[<>]' | tr '\n' ' ' | cut -c1-160))"; RC=1; red="$red $w.$m"; fi
    done
done
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: ARRAY's first argument converts and raises as sbl -bf does -- $n of $n arms (2 witnesses x 2 modes)"
else echo "⛔ GATE FAIL(1) [$G]: diverged from sbl -bf:$red"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC

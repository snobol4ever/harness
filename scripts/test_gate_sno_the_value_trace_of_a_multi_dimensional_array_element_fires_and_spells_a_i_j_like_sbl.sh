#!/usr/bin/env bash
# test_gate_sno_the_value_trace_of_a_multi_dimensional_array_element_fires_and_spells_a_i_j_like_sbl.sh
#
# THE DEFECT (row snobol4-trace-of-a-two-dimensional-array-element-never-enters-trace-at-all): TRACE(.A[1,2]) registered nothing and A[1,2] = 5 printed no 'A<1,2> = 5' line, both modes, where
# sbl -bf prints '****4*******  A<1,2> = 5'. ARRAY('2,3') is a ROW ARRAY here (a 1-D array whose elements are the row arrays), so the element's cell lives in a row that no variable holds directly,
# and etrace_spell_of_cell, which found the owner by scanning each variable's own array, returned 0: _TRACE_ then fell back to the element's VALUE as the name (empty) and failed silently.
# THE CURE: when no variable's array holds the cell, etrace_spell_nested walks each variable's row arrays (etrace_row_path, depth 6) and spells A<i,j[,k]>.
# NOT HERE: a TRACE callback on an element (every element trace, 1-D and table too, reaches the deleted C road into a box) and ACCESS on an element -- their own rows.
# Every expected output is cut from sbl -bf and pinned: a program sbl no longer answers as pinned is a REFUSAL, never a green. Both modes, SCRIP_SNO_STMTKW=1.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
[ -x "$SBL" ] || refuse "the SNOBOL4 oracle $SBL is absent -- the pinned lines cannot be confirmed"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
export SCRIP_SNO_STMTKW=1
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/two_d.sno" <<'SNO'
        &TRACE = 100
        A = ARRAY('2,3')
        TRACE(.A[1,2])
        A[1,2] = 5
        A[2,3] = 6
        OUTPUT = 'end'
END
SNO
cat > "$D/two_d.want" <<'TXT'
****4*******  A<1,2> = 5
end
TXT
cat > "$D/three_d.sno" <<'SNO'
        &TRACE = 100
        A = ARRAY('2,2,2')
        TRACE(.A[2,1,2])
        A[2,1,2] = 'x'
        A[1,1,1] = 'y'
        OUTPUT = 'end'
END
SNO
cat > "$D/three_d.want" <<'TXT'
****4*******  A<2,1,2> = 'x'
end
TXT
cat > "$D/explicit_bounds.sno" <<'SNO'
        &TRACE = 100
        A = ARRAY('0:1,3:5')
        TRACE(.A[1,4])
        A[1,4] = 'z'
        A[0,3] = 'w'
        OUTPUT = 'end'
END
SNO
cat > "$D/explicit_bounds.want" <<'TXT'
****4*******  A<1,4> = 'z'
end
TXT
cat > "$D/two_cells.sno" <<'SNO'
        &TRACE = 100
        A = ARRAY('2,2')
        TRACE(.A[1,1])
        TRACE(.A[2,2], 'VALUE', 'tg')
        A[1,1] = 1
        A[2,2] = 2
        A[1,2] = 3
        OUTPUT = 'end'
END
SNO
cat > "$D/two_cells.want" <<'TXT'
****5*******  A<1,1> = 1
****6*******  A<2,2> = 2
end
TXT
cat > "$D/untrace.sno" <<'SNO'
        &TRACE = 100
        A = ARRAY('2,2')
        TRACE(.A[1,1])
        A[1,1] = 1
        STOPTR(.A[1,1])
        A[1,1] = 2
        OUTPUT = 'end'
END
SNO
cat > "$D/untrace.want" <<'TXT'
****4*******  A<1,1> = 1
end
TXT
cat > "$D/named_cell.sno" <<'SNO'
        &TRACE = 100
        A = ARRAY('2,3')
        TRACE(.A[1,2], 'VALUE')
        A[1,2] = 5
        OUTPUT = A[1,2]
END
SNO
cat > "$D/named_cell.want" <<'TXT'
****4*******  A<1,2> = 5
5
TXT
names="two_d three_d explicit_bounds two_cells untrace named_cell"
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2>/dev/null && gcc "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
for p in $names; do
    ( cd "$D" && timeout -k 5 10 "$SBL" -bf $p.sno < /dev/null 2>/dev/null > $p.sbl )
    cmp -s "$D/$p.want" "$D/$p.sbl" || refuse "sbl -bf does not answer $p as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/$p.sbl")]"
done
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
for p in $names; do
    ( cd "$D" && timeout -k 5 30 "$B/scrip" $p.sno < /dev/null > $p.m3 2>/dev/null )
    ( cd "$D" && m4bin $p && timeout -k 5 30 ./$p.bin < /dev/null > $p.m4 2>/dev/null )
    for m in m3 m4; do
        if [ -f "$D/$p.$m" ] && cmp -s "$D/$p.want" "$D/$p.$m"; then arm "$p $m" ok
        else arm "$p $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/$p.$m")] want [$(tr '\n' '|' < "$D/$p.want")]"; fi
    done
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): the VALUE trace of a multi-dimensional array element fires and spells A<i,j> like sbl -bf -- both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1

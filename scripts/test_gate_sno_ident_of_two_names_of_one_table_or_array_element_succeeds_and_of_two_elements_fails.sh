#!/usr/bin/env bash
# test_gate_sno_ident_of_two_names_of_one_table_or_array_element_succeeds_and_of_two_elements_fails.sh
# THE DEFECT (row snobol4-ident-of-two-names-of-one-table-or-array-element-fails): IDENT(.t['k'], .t['k']) and IDENT(.a[1], .a[1]) FAILED in SCRIP, both modes, where sbl -bf succeeds: each
# evaluation of .t['k'] allocates its own element-name cell (VCELL_t), and c_descr_identical compared two such names by the cell's ADDRESS. THE CURE: two element names are identical when they name the same cell --
# an array or record cell by its address, a table cell by the table and an identical key, a substring name by its variable, position and length (vcell_same in values.c). DIFFER of two names of different
# elements, of the same key in two tables, and IDENT of an array element with a table element stay as they were.
# Every expected output is cut from sbl -bf and pinned: a program sbl no longer answers as pinned is a REFUSAL, never a green. Both modes.
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
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/names.sno" <<'SNO'
        t = TABLE()
        t['k'] = 1
        t['j'] = 2
        a = ARRAY(3)
        b = ARRAY('2,2')
        OUTPUT = IDENT(.t['k'], .t['k']) 'table-same'
        OUTPUT = DIFFER(.t['k'], .t['j']) 'table-diff-key'
        OUTPUT = IDENT(.a[1], .a[1]) 'array-same'
        OUTPUT = DIFFER(.a[1], .a[2]) 'array-diff-idx'
        OUTPUT = IDENT(.b[1,2], .b[1,2]) 'two-d-same'
        OUTPUT = DIFFER(.b[1,2], .b[2,1]) 'two-d-diff'
        OUTPUT = IDENT(.ITEM(t,'k'), .t['k']) 'item-vs-sub'
        t2 = TABLE()
        t2['k'] = 1
        OUTPUT = DIFFER(.t['k'], .t2['k']) 'table-diff-table'
        OUTPUT = IDENT(.a[1], .a[1]) 'again'
        x = 1
        OUTPUT = IDENT(.x, .x) 'var-same'
        OUTPUT = DIFFER(.x, .y) 'var-diff'
        n1 = .t['k']
        n2 = .t['k']
        OUTPUT = IDENT(n1, n2) 'held-names-same'
        OUTPUT = IDENT(.a[1], .t['k']) 'array-vs-table'
        OUTPUT = 'end'
END
SNO
cat > "$D/names.want" <<'TXT'
table-same
table-diff-key
array-same
array-diff-idx
two-d-same
two-d-diff
item-vs-sub
table-diff-table
again
var-same
var-diff
held-names-same
end
TXT
names="names"
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
    echo "GATE PASS(0): IDENT of two names of one element succeeds and of two different elements fails, like sbl -bf -- both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1

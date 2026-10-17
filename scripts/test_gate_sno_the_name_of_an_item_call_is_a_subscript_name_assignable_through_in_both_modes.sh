#!/usr/bin/env bash
# test_gate_sno_the_name_of_an_item_call_is_a_subscript_name_assignable_through_in_both_modes.sh
#
# THE DEFECT (row snobol4-assigning-through-the-name-of-an-item-call-aborts-scrip): .ITEM(t, k) is the name operator over a function call, and the
# lowerer sent every function call but a DATA field accessor down the generic by-name path, which CALLED ITEM and handed back the element's VALUE.
# n = .ITEM(t, 'b') then held 1, not the name of t['b'], and $n = 6 died in rt_assign_var ('lvalue is not a variable') -- as did a user function
# that NRETURNs .ITEM(t, x) (scrip --transpile spells every t[x] ITEM(t, x), so SCRIPtix's h() fell on it). sbl treats .ITEM(c, k...) as .c[k...]:
# the name of the element, assignable through, DATATYPE NAME. THE CURE: the TT_NAME arm lowers .ITEM(c, k...) through sx_subscript_lv, as it does .c[k...].
# NOT HERE: IDENT of two names of one element, and . ITEM(...) as a capture target -- separate rows.
# The expected output is cut from sbl -bf at run time and pinned: a line sbl no longer prints is a REFUSAL, never a green. Both modes.
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
cat > "$D/a.sno" <<'SNO'
        DEFINE('h(x)')                  :(h_end)
h       h = .ITEM(t, x)                 :(NRETURN)
h_end   t = TABLE()
        t['b'] = 1
        h('b') = 5
        OUTPUT = 'via h ' t['b']
        h('b') = h('b') + 10
        OUTPUT = 'bump ' t['b']
        n = .ITEM(t, 'b')
        OUTPUT = 'kind ' DATATYPE(n)
        $n = 6
        OUTPUT = 'via name ' t['b']
        $n = $n + 1
        OUTPUT = 'read-back ' $n ' ' $.ITEM(t, 'b')
        n = .ITEM(t, 'fresh')
        $n = 'made'
        OUTPUT = 'new key ' t['fresh']
        a = ARRAY(2)
        m = .ITEM(a, 1)
        $m = 7
        OUTPUT = 'array ' a[1]
        a2 = ARRAY('2,2', 0)
        m = .ITEM(a2, 2, 1)
        $m = 9
        OUTPUT = 'two-d ' a2[2,1] ' ' DATATYPE(m)
END
SNO
cat > "$D/a.want" <<'TXT'
via h 5
bump 15
kind NAME
via name 6
read-back 7 7
new key made
array 7
two-d 9 NAME
TXT
( cd "$D" && timeout -k 5 10 "$SBL" -bf a.sno < /dev/null 2>/dev/null > a.sbl )
cmp -s "$D/a.want" "$D/a.sbl" || refuse "sbl -bf does not answer a as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/a.sbl")]"
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2>/dev/null && gcc "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
( cd "$D" && timeout -k 5 30 "$B/scrip" a.sno < /dev/null > a.m3 2>/dev/null )
( cd "$D" && m4bin a && timeout -k 5 30 ./a.bin < /dev/null > a.m4 2>/dev/null )
for m in m3 m4; do
    if [ -f "$D/a.$m" ] && cmp -s "$D/a.want" "$D/a.$m"; then arm "a $m (NRETURN .ITEM, name of a table and array element, 2-D, read-back)" ok
    else arm "a $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/a.$m")] want [$(tr '\n' '|' < "$D/a.want")]"; fi
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): .ITEM(c, k...) is the name of the element -- assignable through a user function's NRETURN, \$n and \$.ITEM, DATATYPE NAME -- both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1

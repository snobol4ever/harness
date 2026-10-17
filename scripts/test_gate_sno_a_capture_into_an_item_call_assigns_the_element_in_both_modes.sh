#!/usr/bin/env bash
# test_gate_sno_a_capture_into_an_item_call_assigns_the_element_in_both_modes.sh
#
# THE DEFECT (row snobol4-a-pattern-capture-whose-target-is-an-item-call-aborts-the-emitter-with-unresolved-match-assign-save-references): a conditional
# or immediate capture whose target is an ITEM(c, k...) call -- 'abc' ? LEN(2) . ITEM(t, 'c') -- was not a "supported" static capture, so the pattern
# was built at run time with the NAME of the element folded into the capture node's target STRING, which an element has none of: the node carried an
# empty target and the runtime pattern compiler aborted in bb_emit_end ('n0_match_assign_save_beta' unresolved), both modes. sbl -bf assigns the element.
# THE CURE: an ITEM capture target is the deferred NAME thunk (EXPRNM$n, the form every other computed capture target takes) over .ITEM(c, k...), which
# the thunk body lowers through the TT_NAME arm (sx_subscript_lv); sno_pat_supported admits it, so the static and the run-time-built pattern both work.
# SECOND ARM (row snobol4-a-deferred-capture-target-over-an-item-call-star-item-assigns-nothing-where-sbl-assigns-the-element): the DEFER spelling
# . *ITEM(c, k) / $ *ITEM(c, k) assigned nothing -- its thunk was collected without the NAME flag, so the strict capture refused it as a VALUE. Same thunk now.
# NOT HERE: the t['c'] spelling of a capture target (FATAL at lower time) -- a separate row.
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
        t = TABLE()
        a = ARRAY(3)
        a2 = ARRAY('2,2', 0)
        'abc' ? LEN(2) . ITEM(t, 'c')
        OUTPUT = 'cond ' t['c']
        'xyz' ? LEN(1) $ ITEM(a, 2)
        OUTPUT = 'imm ' a[2]
        'pqrs' ? LEN(2) . ITEM(a2, 2, 1) LEN(1) . ITEM(a2, 1, 2)
        OUTPUT = 'two-d ' a2[2,1] ' ' a2[1,2]
        'abc' ? LEN(5) . ITEM(t, 'never')
        OUTPUT = 'failed match leaves ' DATATYPE(t['never'])
        k = 'dyn'
        'hello' ? 'h' LEN(3) . ITEM(t, k) 'o'
        OUTPUT = 'computed key ' t['dyn']
        p = LEN(2) . ITEM(t, 'built')
        'wxyz' ? p
        OUTPUT = 'built pattern ' t['built']
        DEFINE('grab(s)')               :(grab_end)
grab    s ? SPAN('abcdefghijklmnopqrstuvwxyz') . ITEM(t, 'word')  :F(FRETURN)
        grab = t['word']                :(RETURN)
grab_end
        OUTPUT = 'in function ' grab('abc123')
        'ab' ? ARBNO(LEN(1) $ ITEM(a, 3)) RPOS(0)
        OUTPUT = 'arbno ' a[3]
END
SNO
cat > "$D/b.sno" <<'SNO'
        t = TABLE()
        a = ARRAY(3)
        'abc' ? LEN(2) . *ITEM(t, 'c')
        OUTPUT = 'cond ' t['c']
        'xyz' ? LEN(1) $ *ITEM(a, 2)
        OUTPUT = 'imm ' a[2]
        k = 'dyn'
        'hello' ? 'h' LEN(3) . *ITEM(t, k) 'o'
        OUTPUT = 'computed key ' t['dyn']
END
SNO
cat > "$D/b.want" <<'TXT'
cond ab
imm x
computed key ell
TXT
cat > "$D/a.want" <<'TXT'
cond ab
imm x
two-d pq r
failed match leaves STRING
computed key ell
built pattern wx
in function abc
arbno b
TXT
( cd "$D" && timeout -k 5 10 "$SBL" -bf a.sno < /dev/null 2>/dev/null > a.sbl )
( cd "$D" && timeout -k 5 10 "$SBL" -bf b.sno < /dev/null 2>/dev/null > b.sbl )
for x in a b; do cmp -s "$D/$x.want" "$D/$x.sbl" || refuse "sbl -bf does not answer $x as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/$x.sbl")]"; done
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2>/dev/null && gcc "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
( cd "$D" && timeout -k 5 30 "$B/scrip" a.sno < /dev/null > a.m3 2>/dev/null )
( cd "$D" && m4bin a && timeout -k 5 30 ./a.bin < /dev/null > a.m4 2>/dev/null )
( cd "$D" && timeout -k 5 30 "$B/scrip" b.sno < /dev/null > b.m3 2>/dev/null )
( cd "$D" && m4bin b && timeout -k 5 30 ./b.bin < /dev/null > b.m4 2>/dev/null )
for m in m3 m4; do
    if [ -f "$D/a.$m" ] && cmp -s "$D/a.want" "$D/a.$m"; then arm "a $m (. and \$ into ITEM of a table, array and 2-D array; computed key; pattern held in a variable; in a function; under ARBNO)" ok
    else arm "a $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/a.$m")] want [$(tr '\n' '|' < "$D/a.want")]"; fi
    if [ -f "$D/b.$m" ] && cmp -s "$D/b.want" "$D/b.$m"; then arm "b $m (. *ITEM(c, k) and \$ *ITEM(c, k), the deferred spelling, computed key)" ok
    else arm "b $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/b.$m")] want [$(tr '\n' '|' < "$D/b.want")]"; fi
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): a capture into an ITEM(c, k...) call assigns the element in both modes -- every pinned line equals sbl -bf; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1

#!/usr/bin/env bash
# test_gate_sno_convert_to_string_fails_for_a_value_that_is_not_text_as_spitbol_does.sh
#
# THE DEFECT (row snobol4-convert-of-an-array-pattern-or-table-to-string-returns-an-image-where-spitbol-fails): CONVERT(x, 'STRING') FAILS in SPITBOL for an ARRAY, a TABLE, a pattern, a CODE object, an
# EXPRESSION and a DATA record, and succeeds for a string, an integer, a real, a NAME and the null string; SCRIP answered an image for the six that fail (ARRAY('1:2'), TABLE(11,10), PATTERN, CODE, EXPRESSION,
# the record's type name). THE CURE: bn_convert's STRING arm fails for DT_A, DT_T, DT_P, DT_C, DT_E, DT_X and a record instance. The expected output is cut from sbl -bf at run time (14 cases, the
# INTEGER/REAL/ARRAY conversions of the same values as controls); a run sbl does not answer is a REFUSAL. Both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
[ -x "$SBL" ] || refuse "the SNOBOL4 oracle $SBL is absent -- the expected answers cannot be cut"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/a.sno" <<'SNO'
        DATA('REC(F1)')
        r = REC(1)
        x = 5
        c = CODE(' OUTPUT = 1')
        e = *x
        n = 0
nxt     n = n + 1
        :($('C' n))
C1      v = CONVERT(ARRAY(2), 'STRING')         :S(y)F(f)
C2      v = CONVERT(LEN(1), 'STRING')           :S(y)F(f)
C3      v = CONVERT(TABLE(), 'STRING')          :S(y)F(f)
C4      v = CONVERT(12, 'STRING')               :S(y)F(f)
C5      v = CONVERT(1.5, 'STRING')              :S(y)F(f)
C6      v = CONVERT('ab', 'STRING')             :S(y)F(f)
C7      v = CONVERT(.x, 'STRING')               :S(y)F(f)
C8      v = CONVERT(r, 'STRING')                :S(y)F(f)
C9      v = CONVERT(c, 'STRING')                :S(y)F(f)
C10     v = CONVERT(e, 'STRING')                :S(y)F(f)
C11     v = CONVERT(, 'STRING')                 :S(y)F(f)
C12     v = CONVERT(ARRAY(2), 'INTEGER')        :S(y)F(f)
C13     v = CONVERT(LEN(1), 'REAL')             :S(y)F(f)
C14     v = CONVERT(TABLE(), 'ARRAY')           :S(y)F(f)
C15     :(END)
y       OUTPUT = n ' S [' v ']'                 :(nxt)
f       OUTPUT = n ' F'                         :(nxt)
END
SNO
( cd "$D" && timeout -k 5 10 "$SBL" -bf a.sno < /dev/null 2>/dev/null > a.want )
grep -qx "1 F" "$D/a.want" && grep -qx "4 S \[12\]" "$D/a.want" || refuse "sbl -bf does not answer the CONVERT witness as pinned: [$(tr '\n' '|' < "$D/a.want")]"
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2>/dev/null && gcc -no-pie "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
( cd "$D" && timeout -k 5 30 "$B/scrip" a.sno < /dev/null > a.m3 2>/dev/null )
( cd "$D" && m4bin a && timeout -k 5 30 ./a.bin < /dev/null > a.m4 2>/dev/null )
for m in m3 m4; do
    if [ -f "$D/a.$m" ] && cmp -s "$D/a.want" "$D/a.$m"; then arm "a $m (CONVERT to STRING of 11 value kinds, three controls)" ok
    else arm "a $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/a.$m")] want [$(tr '\n' '|' < "$D/a.want")]"; fi
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): CONVERT(x, 'STRING') fails for an array, table, pattern, code, expression and record and succeeds for text, numbers and names, as sbl -bf does, both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1

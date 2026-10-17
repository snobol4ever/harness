#!/usr/bin/env bash
# test_gate_sno_an_array_or_table_as_a_pattern_operand_raises_the_operand_errors_of_spitbol_in_both_modes.sh
#
# THE DEFECT (row snobol4-an-array-or-table-as-a-pattern-operand-is-an-error-in-spitbol-where-scrip-matches-or-builds): an ARRAY or TABLE used as an operand of a pattern operation is an
# error in SPITBOL, each operator with its own number -- the right operand of a match is ERROR 240, an alternation's right/left operand 5/6, a concatenation's left/right operand 8/9
# (both operators associate to the RIGHT: in 'a' | a | 'b' and 'a' a 'b' the aggregate is a LEFT operand, so 6 and 8) -- and SCRIP failed the match, built a pattern around the aggregate
# and concatenated it away. THE CURE: every pattern operand variable is validated where its value is snapshotted for the match (and where the value-context pattern is built) by
# SNO$PATCK, which raises the operand's number for a DT_A, DT_T or record value and passes anything else through; the lowerer threads the operand's position (root 240, sequence 8/9,
# alternation 6/5) down the pattern tree. The expected output is cut from sbl -bf at run time; a run sbl does not answer is a REFUSAL. Both modes.
# SECOND LANDING (row snobol4-an-array-or-table-under-arbno-fence-deferral-and-the-capture-operators-...): the aggregate under ARBNO is ERROR 61, FENCE 259, a * deferral 46, a conditional
# capture's pattern 30 and an immediate capture's 25.
# NOT HERE: a value-context concatenation chain 'a' a 'b' (SCRIP numbers it 9, sbl 8: SCRIP's tree is left-nested).
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
[ -x "$SBL" ] || refuse "the SNOBOL4 oracle $SBL is absent -- the expected errors cannot be cut"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/a.sno" <<'SNO'
        &ERRLIMIT = 1000
        t = TABLE()
        a = ARRAY(3)
        p = LEN(1)
        i = 0
nxt     i = i + 1
        SETEXIT(.errh)
        :($('C' i))
C1      '0' ? t                         :(ok)
C2      'ab' ? a                        :(ok)
C3      x = LEN(2) | a                  :(ok)
C4      x = a | LEN(2)                  :(ok)
C5      a[1] ? t 'a'                    :(ok)
C6      'ab' ? 'a' | a                  :(ok)
C7      'ab' ? a | 'a'                  :(ok)
C8      'ab' ? 'a' | a | 'b'            :(ok)
C9      'ab' ? a | 'a' | 'b'            :(ok)
C10     'ab' ? 'a' | 'b' | a            :(ok)
C11     'ab' ? 'a' a 'b'                :(ok)
C12     'ab' ? a 'a' 'b'                :(ok)
C13     'ab' ? 'a' 'b' a                :(ok)
C14     x = ('a' ? a)                   :(ok)
C15     x = ('a' ? t | 'a')             :(ok)
C16     'ab' ? p t                      :(ok)
C17     'ab' ? p 'b'                    :(ok)
C18     'ab' ? p | 'b'                  :(ok)
C19     x = p | 'b'                     :(ok)
C20     x = 'ab' ? p                    :(ok)
C21     'ab' ? ARBNO(t)                 :(ok)
C22     'ab' ? FENCE(t)                 :(ok)
C23     'ab' ? *t                       :(ok)
C24     'ab' ? t . x                    :(ok)
C25     'ab' ? a $ x                    :(ok)
C26     x = ('ab' ? t . y)              :(ok)
C27     :(END)
ok      OUTPUT = i ' ok'                :(nxt)
errh    OUTPUT = i ' ERROR ' &ERRTYPE   :(nxt)
END
SNO
cat > "$D/b.sno" <<'SNO'
        &ERRLIMIT = 1000
        t = TABLE()
        a = ARRAY(3)
loop    line = INPUT                    :F(END)
        SETEXIT('errh')
        x = EVAL(line)                  :S(ok)
        OUTPUT = 'FAIL'                 :(loop)
ok      OUTPUT = DATATYPE(x)            :(loop)
errh    OUTPUT = 'ERROR ' &ERRTYPE      :(loop)
END
SNO
printf "%s\n" "'0' ? t" "'ab' ? a" "LEN(2) | a" "a | LEN(2)" "a[1] ? t 'a'" "'a' | a | 'b'" "'a' | 'b' | a" "'a' ? 'a' | a" "'ab' ? ARBNO(t)" "'ab' ? FENCE(t)" "'ab' ? *t" "'ab' ? t . x" "'ab' ? a $ x" "LEN(1) | 'b'" > "$D/b.in"
( cd "$D" && timeout -k 5 10 "$SBL" -bf a.sno < /dev/null 2>/dev/null > a.want )
( cd "$D" && timeout -k 5 10 "$SBL" -bf b.sno < b.in 2>/dev/null > b.want )
grep -q "ERROR 240" "$D/a.want" || refuse "sbl -bf does not raise ERROR 240 for the match operand: [$(tr '\n' '|' < "$D/a.want")]"
grep -q "ERROR 240" "$D/b.want" || refuse "sbl -bf does not raise ERROR 240 through EVAL: [$(tr '\n' '|' < "$D/b.want")]"
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2>/dev/null && gcc -no-pie "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
( cd "$D" && timeout -k 5 30 "$B/scrip" a.sno < /dev/null > a.m3 2>/dev/null )
( cd "$D" && m4bin a && timeout -k 5 30 ./a.bin < /dev/null > a.m4 2>/dev/null )
( cd "$D" && timeout -k 5 30 "$B/scrip" b.sno < b.in > b.m3 2>/dev/null )
( cd "$D" && m4bin b && timeout -k 5 30 ./b.bin < b.in > b.m4 2>/dev/null )
for m in m3 m4; do
    if [ -f "$D/a.$m" ] && cmp -s "$D/a.want" "$D/a.$m"; then arm "a $m (statement forms: match 240, alternation 5/6, concatenation 8/9, right association, value match, pattern variable control)" ok
    else arm "a $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/a.$m")] want [$(tr '\n' '|' < "$D/a.want")]"; fi
    if [ -f "$D/b.$m" ] && cmp -s "$D/b.want" "$D/b.$m"; then arm "b $m (the same through EVAL under SETEXIT)" ok
    else arm "b $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/b.$m")] want [$(tr '\n' '|' < "$D/b.want")]"; fi
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): an ARRAY or TABLE as a pattern operand raises the operand error SPITBOL raises -- 240, 5, 6, 8, 9, 61, 259, 46, 30, 25 -- as a statement and through EVAL, both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1

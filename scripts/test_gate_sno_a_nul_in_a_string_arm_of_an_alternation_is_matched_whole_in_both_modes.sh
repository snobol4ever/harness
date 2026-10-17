#!/usr/bin/env bash
# test_gate_sno_a_nul_in_a_string_arm_of_an_alternation_is_matched_whole_in_both_modes.sh
#
# THE DEFECT (row snobol4-a-string-alternation-arm-holding-a-nul-is-cut-at-the-nul): 'z' ? (&ALPHABET | 2) and 'z' ? (al | 2) (al = &ALPHABET, 256 characters from CHAR(0)) matched the null string in SCRIP
# where sbl -bf fails: a string arm of a value-built alternation became a TT_QLIT in the runtime pattern tree, a C string cut at the first NUL. THE CURE: rcp_of carries a string whose bytes
# hold a NUL as a deferred variable (NULS$n holding the descriptor, whose slen is authoritative), the way it carries an opaque pattern. The expected output is cut from sbl -bf at run time;
# a run sbl does not answer is a REFUSAL. Both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
        &ERRLIMIT = 1000
        al = &ALPHABET
        s = 'ab' CHAR(0) 'cd'
        u = 'ab' CHAR(0) 'zz'
        t1 = 'ab' CHAR(0) 'cd'
        n = 0
nxt     n = n + 1
        :($('C' n))
C1      'z' ? (&ALPHABET | 2)           :S(y)F(f)
C2      'z' ? (&ALPHABET 1 | 2)         :S(y)F(f)
C3      'z' ? (al | 2)                  :S(y)F(f)
C4      t1 ? (s | 2)                    :S(y)F(f)
C5      t1 ? (u | 'x')                  :S(y)F(f)
C6      t1 ? (u | s)                    :S(y)F(f)
C7      t1 ? (s)                        :S(y)F(f)
C8      t1 ? ('x' | s) RPOS(0)          :S(y)F(f)
C9      t1 ? ('ab' | s) RPOS(0)         :S(y)F(f)
C10     x = &ALPHABET | 'q'
        'q' ? x                         :S(y)F(f)
C11     'z' ? (&UCASE | 2)              :S(y)F(f)
C12     :(END)
y       OUTPUT = n ' matched'           :(nxt)
f       OUTPUT = n ' failed'            :(nxt)
END
SNO
cat > "$D/b.sno" <<'SNO'
loop    line = INPUT                    :F(END)
        x = EVAL(line)                  :S(ok)
        OUTPUT = 'FAIL'                 :(loop)
ok      OUTPUT = DATATYPE(x) ' ' SIZE(x) :(loop)
END
SNO
printf "%s\n" "'z' ? (&ALPHABET | 2)" "'z' ? (&ALPHABET 1 | 2)" "'z' ? (&UCASE | 2)" > "$D/b.in"
( cd "$D" && timeout -k 5 10 "$SBL" -bf a.sno < /dev/null 2>/dev/null > a.want )
( cd "$D" && timeout -k 5 10 "$SBL" -bf b.sno < b.in 2>/dev/null > b.want )
grep -q "^1 failed" "$D/a.want" || refuse "sbl -bf does not fail 'z' ? (&ALPHABET | 2): [$(tr '\n' '|' < "$D/a.want")]"
[ "$(head -1 "$D/b.want")" = "FAIL" ] || refuse "sbl -bf does not fail through EVAL: [$(tr '\n' '|' < "$D/b.want")]"
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2>/dev/null && gcc -no-pie "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
( cd "$D" && timeout -k 5 30 "$B/scrip" a.sno < /dev/null > a.m3 2>/dev/null )
( cd "$D" && m4bin a && timeout -k 5 30 ./a.bin < /dev/null > a.m4 2>/dev/null )
( cd "$D" && timeout -k 5 30 "$B/scrip" b.sno < b.in > b.m3 2>/dev/null )
( cd "$D" && m4bin b && timeout -k 5 30 ./b.bin < b.in > b.m4 2>/dev/null )
for m in m3 m4; do
    if [ -f "$D/a.$m" ] && cmp -s "$D/a.want" "$D/a.$m"; then arm "a $m (NUL arms: keyword, variable, sequence, mid-string NUL, built alternation)" ok
    else arm "a $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/a.$m")] want [$(tr '\n' '|' < "$D/a.want")]"; fi
    if [ -f "$D/b.$m" ] && cmp -s "$D/b.want" "$D/b.$m"; then arm "b $m (the three EVAL lines of the row)" ok
    else arm "b $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/b.$m")] want [$(tr '\n' '|' < "$D/b.want")]"; fi
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): a string arm of an alternation holding a NUL is matched whole, as sbl -bf matches it, as a statement and through EVAL, both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1

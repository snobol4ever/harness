#!/usr/bin/env bash
# test_gate_sno_any_notany_span_break_breakx_of_the_null_string_or_a_pattern_raise_spitbols_error.sh
#
# THE DEFECT (the ceo's row snobol4-any-notany-span-break-breakx-of-the-null-string-are-errors-in-spitbol-where-scrip-builds-a-pattern,
# CEO-1419; about 19,000 of infinite_snobol4's exhaustive differences): ANY, NOTANY, SPAN, BREAK and BREAKX of the null string
# or of a pattern are errors in sbl -- 59, 151, 188, 69, 70, "<fn> argument is not a string or expression" -- at compile time
# when the argument is a constant, at run time otherwise; SCRIP built a pattern from '' and matched with it.
# THE CURE, three roads of one check (pat_cset_arg_ok in src/runtime/pattern_match.c, which coerces through rt_coerce_str_d
# with the function's code as both the type and the null code; a deferred argument passes): (1) the value-context
# constructors (core.c _PAT_ANY_ .. _PAT_BREAKX_, by_name_dispatch.c rt_sno_pbk_d) raise and fail; (2) a computed argument
# inside a match (the IR_COERCE_STRING of sno_mkpat_emit) raises and takes its omega -- rt_coerce_str_d now answers whether it
# raised, so the box concedes instead of building on, and an armed SETEXIT trap is taken; (3) the compile-time
# pre-evaluation (sno_pe_walk, the cfo's ddf5c1a60) refuses a null or pattern constant argument as sbl does.
# NOT HERE: a DEFERRED argument that evaluates to the null string at match time is sbl's 43/49/56/44/45 ("evaluated argument
# is not a string"), its own row; and mode 4 crashes in rt_pat_prim_str_take on a deferred ANY after any BREAK or SPAN was
# built, its own row -- so the deferred controls below run before any BREAK.
#
# Five programs, every answer cut from sbl -bf at run time and confirmed: a pinned line sbl no longer prints is a REFUSAL,
# never a green. Both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
cat > "$D/t.sno" <<'SNO'
        &ERRLIMIT = 20
        S = ''
        SETEXIT('H')
        X = ANY(S)
        SETEXIT('H')
        X = NOTANY(S)
        SETEXIT('H')
        X = SPAN(S)
        SETEXIT('H')
        X = BREAK(S)
        SETEXIT('H')
        X = BREAKX(S)
        SETEXIT('H')
        'abc' ? NOTANY(S)
        SETEXIT('H')
        'abc' ? SPAN(S) . Y
        SETEXIT('H')
        X = BREAK(S S)
        N = 5
        OUTPUT = ('a5' ? ANY(N)) ' integer'
        OUTPUT = ('xyz' ? NOTANY('x') . W) W ' constant'
        V = 'c'
        OUTPUT = ('abc' ? BREAK(V) . W) W ' variable'
        OUTPUT = 'end'                                   :(END)
H       OUTPUT = 'trap ' &ERRTYPE ' ' &ERRTEXT           :(CONTINUE)
END
SNO
cat > "$D/t.want" <<'TXT'
trap 59 any argument is not a string or expression
trap 151 notany argument is not a string or expression
trap 188 span argument is not a string or expression
trap 69 break argument is not a string or expression
trap 70 breakx argument is not a string or expression
trap 151 notany argument is not a string or expression
trap 188 span argument is not a string or expression
trap 69 break argument is not a string or expression
5 integer
yy constant
abab variable
end
TXT
cat > "$D/e.sno" <<'SNO'
        &TRIM = 1
L       LINE = INPUT                                     :F(END)
        &ERRLIMIT = 1000
        SETEXIT('H')
        R = EVAL(LINE)                                   :S(OK)
        OUTPUT = 'FAIL'                                  :(L)
OK      OUTPUT = IDENT(DATATYPE(R), 'STRING') 'STRING ' R :S(L)
        OUTPUT = DATATYPE(R)                             :(L)
H       OUTPUT = 'ERROR ' &ERRTYPE                       :(L)
END
SNO
cat > "$D/e.in" <<'TXT'
'abc' ? ANY(*'b')
'abc' ? BREAK(*'c')
ANY('')
NOTANY('')
SPAN('')
BREAK('')
BREAKX('')
'a' ? SPAN('')
*+-BREAK('')
&ALPHABET ?2.0 *-(NOTANY(''))
ANY('') - &ANCHOR -LEN(1) ? ')'
'abc' * -ANY('')
ANY('ab')
'abc' ? BREAK('c')
'a5' ? ANY(5)
BREAK(LEN(1))
TXT
printf 'STRING b\nSTRING ab\nERROR 59\nERROR 151\nERROR 188\nERROR 69\nERROR 70\nERROR 188\nERROR 69\nERROR 151\nERROR 59\nERROR 59\nPATTERN\nSTRING ab\nSTRING 5\nERROR 69\n' > "$D/e.want"
printf "        OUTPUT = 'before'\n        X = SPAN('')\n        OUTPUT = 'after'\nEND\n" > "$D/c1.sno"
printf "        OUTPUT = 'before'\n        X = 'abc' ? NOTANY(LEN(1))\n        OUTPUT = 'after'\nEND\n" > "$D/c2.sno"
printf "        S = ''\n        OUTPUT = 'before'\n        X = BREAK(S)\n        OUTPUT = 'after'\nEND\n" > "$D/f1.sno"
( cd "$D" && timeout -k 5 10 "$SBL" -bf t.sno < /dev/null > t.sbl 2>/dev/null )
cmp -s "$D/t.want" "$D/t.sbl" || refuse "sbl -bf does not answer t as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/t.sbl")]"
( cd "$D" && timeout -k 5 10 "$SBL" -bf e.sno < e.in > e.sbl 2>/dev/null )
cmp -s "$D/e.want" "$D/e.sbl" || refuse "sbl -bf does not answer e as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/e.sbl")]"
for w in c1:188 c2:151; do
    f=${w%%:*}; c=${w#*:}
    ( cd "$D" && timeout -k 5 10 "$SBL" -bf $f.sno < /dev/null > $f.sbl 2>&1 )
    grep -q "ERROR $c --" "$D/$f.sbl" && ! grep -q '^before$' "$D/$f.sbl" || refuse "sbl -bf no longer refuses $f at compile time with $c: [$(tr '\n' '|' < "$D/$f.sbl" | cut -c1-300)]"
done
( cd "$D" && timeout -k 5 10 "$SBL" -bf f1.sno < /dev/null > f1.sbl 2>/dev/null )
[ "$(head -1 "$D/f1.sbl")" = before ] && grep -q 'ERROR 069 --' "$D/f1.sbl" && ! grep -q '^after$' "$D/f1.sbl" \
    || refuse "sbl -bf no longer stops f1 at error 69: [$(tr '\n' '|' < "$D/f1.sbl" | cut -c1-300)]"
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2> "$1.m4c" && gcc -no-pie "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
( cd "$D" && timeout -k 5 30 "$B/scrip" t.sno < /dev/null > t.m3 2>/dev/null )
( cd "$D" && m4bin t && timeout -k 5 30 ./t.bin < /dev/null > t.m4 2>/dev/null )
( cd "$D" && timeout -k 5 30 "$B/scrip" e.sno < e.in > e.m3 2>/dev/null )
( cd "$D" && m4bin e && timeout -k 5 30 ./e.bin < e.in > e.m4 2>/dev/null )
for p in t e; do for m in m3 m4; do
    if [ -f "$D/$p.$m" ] && cmp -s "$D/$p.want" "$D/$p.$m"; then arm "$p $m" ok; else arm "$p $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/$p.$m")] want [$(tr '\n' '|' < "$D/$p.want")]"; fi
done; done
for w in c1:188 c2:151; do
    f=${w%%:*}; c=${w#*:}
    ( cd "$D" && timeout -k 5 30 "$B/scrip" $f.sno < /dev/null > $f.m3 2> $f.m3e; echo $? > $f.m3rc )
    if [ "$(cat "$D/$f.m3rc")" != 0 ] && [ ! -s "$D/$f.m3" ] && grep -q "error $c:" "$D/$f.m3e"; then arm "$f m3" ok
    else arm "$f m3" "rc=$(cat "$D/$f.m3rc") out=[$(tr '\n' '|' < "$D/$f.m3")] err=[$(tr '\n' '|' < "$D/$f.m3e")], want a compile-time error $c and no output"; fi
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile $f.sno < /dev/null > $f.s 2> $f.m4e; echo $? > $f.m4rc )
    if [ "$(cat "$D/$f.m4rc")" != 0 ] && grep -q "error $c:" "$D/$f.m4e"; then arm "$f m4" ok
    else arm "$f m4" "compile rc=$(cat "$D/$f.m4rc") err=[$(tr '\n' '|' < "$D/$f.m4e")], want error $c and no code"; fi
done
( cd "$D" && timeout -k 5 30 "$B/scrip" f1.sno < /dev/null > f1.m3 2> f1.m3e; echo $? > f1.m3rc )
( cd "$D" && { m4bin f1 && timeout -k 5 30 ./f1.bin < /dev/null > f1.m4 2> f1.m4e; echo $? > f1.m4rc; } )
for m in m3 m4; do
    if [ "$(cat "$D/f1.${m}rc" 2>/dev/null)" != 0 ] && [ "$(cat "$D/f1.$m" 2>/dev/null)" = before ] && grep -q 'error 69:' "$D/f1.${m}e" 2>/dev/null; then arm "f1 $m" ok
    else arm "f1 $m" "rc=$(cat "$D/f1.${m}rc" 2>/dev/null) out=[$(tr '\n' '|' < "$D/f1.$m" 2>/dev/null)] err=[$(tr '\n' '|' < "$D/f1.${m}e" 2>/dev/null)], want before then error 69"; fi
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): ANY, NOTANY, SPAN, BREAK and BREAKX of the null string or of a pattern raise sbl's error -- trapped, under EVAL, at compile time and fatal -- both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1

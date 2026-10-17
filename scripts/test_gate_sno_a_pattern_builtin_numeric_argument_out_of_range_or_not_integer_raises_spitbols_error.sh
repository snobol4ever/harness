#!/usr/bin/env bash
# test_gate_sno_a_pattern_builtin_numeric_argument_out_of_range_or_not_integer_raises_spitbols_error.sh
#
# THE DEFECT (row snobol4-pattern-builtins-and-char-take-out-of-range-arguments-where-spitbol-raises-their-errors): LEN, POS, RPOS, TAB and
# RTAB built a PATTERN from an argument sbl refuses -- a negative or non-integer one -- and REVERSE reversed a pattern's image. sbl raises at
# CONSTRUCTION: LEN 120/121, POS 162/163, RTAB 181/182, TAB 183/184, RPOS 185/186 (not integer / negative or too large), REVERSE of a pattern or
# array 177. THE CURE: a stored pattern's integer arguments are coerced where the pattern is built (the lowerer's mkpat chain gained the
# IR_COERCE_INTEGER the cset arguments already had), rt_coerce_int_d reports a raise so the box fails the statement under &ERRLIMIT, and
# REVERS_fn refuses a pattern, array, table, code or expression. NOT HERE: the 2^24 "too large" bound of the by-name constructors (pat_num_arg_ok)
# is exercised by APPLY only; CHAR(-1) is 282 already.
# Every answer is cut from sbl -bf at run time and pinned: a pinned line sbl no longer prints is a REFUSAL, never a green. Both modes.
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
        &ERRLIMIT = 50
        SETEXIT('H')
        P = 'unset'
        N = 'x'
        SETEXIT('H')
        P = LEN(N)
        OUTPUT = 'len-x ' DATATYPE(P)
        P = 'unset'
        N = -2
        SETEXIT('H')
        P = LEN(N)
        OUTPUT = 'len-neg ' DATATYPE(P)
        P = 'unset'
        SETEXIT('H')
        P = POS(N)
        OUTPUT = 'pos-neg ' DATATYPE(P)
        P = 'unset'
        SETEXIT('H')
        P = RPOS(N)
        OUTPUT = 'rpos-neg ' DATATYPE(P)
        P = 'unset'
        SETEXIT('H')
        P = TAB(N)
        OUTPUT = 'tab-neg ' DATATYPE(P)
        P = 'unset'
        SETEXIT('H')
        P = RTAB(N)
        OUTPUT = 'rtab-neg ' DATATYPE(P)
        P = 'unset'
        N = 'x'
        SETEXIT('H')
        P = POS(N)
        OUTPUT = 'pos-x ' DATATYPE(P)
        P = 'unset'
        SETEXIT('H')
        P = RPOS(N) 'a'
        OUTPUT = 'rpos-x ' DATATYPE(P)
        P = 'unset'
        N = -2
        SETEXIT('H')
        P = ARBNO(LEN(N))
        OUTPUT = 'arbno-len-neg ' DATATYPE(P)
        P = 'unset'
        SETEXIT('H')
        P = LEN(N + 5) 'a'
        OUTPUT = 'len-ok ' DATATYPE(P)
        N = 3.7
        SETEXIT('H')
        P = LEN(N)
        OUTPUT = 'len-real ' DATATYPE(P)
        N = '4'
        SETEXIT('H')
        P = TAB(N)
        OUTPUT = 'tab-str ' DATATYPE(P)
        N =
        SETEXIT('H')
        P = POS(N)
        OUTPUT = 'pos-null ' DATATYPE(P)
        OUTPUT = 'end'                                   :(END)
H       OUTPUT = 'trap ' &ERRTYPE                        :(CONTINUE)
END
SNO
printf '%s\n' 'trap 120' 'len-x STRING' 'trap 121' 'len-neg STRING' 'trap 163' 'pos-neg STRING' 'trap 186' 'rpos-neg STRING' 'trap 184' 'tab-neg STRING' \
    'trap 182' 'rtab-neg STRING' 'trap 162' 'pos-x STRING' 'trap 185' 'rpos-x STRING' 'trap 121' 'arbno-len-neg STRING' 'len-ok PATTERN' 'len-real PATTERN' \
    'tab-str PATTERN' 'pos-null PATTERN' 'end' > "$D/a.want"
cat > "$D/e.sno" <<'SNO'
        &TRIM = 1
L       LINE = INPUT                                     :F(END)
        &ERRLIMIT = 1000
        SETEXIT('H')
        R = EVAL(LINE)                                   :S(OK)
        OUTPUT = 'FAIL'                                  :(L)
OK      OUTPUT = DATATYPE(R)                             :(L)
H       OUTPUT = 'ERROR ' &ERRTYPE                       :(L)
END
SNO
cat > "$D/e.tsv" <<'TXT'
LEN(-1)	ERROR 121
LEN('x')	ERROR 120
POS(-1)	ERROR 163
POS('x')	ERROR 162
TAB(-1)	ERROR 184
TAB('x')	ERROR 183
RTAB(-1)	ERROR 182
RTAB('x')	ERROR 181
RPOS(-1)	ERROR 186
RPOS('x')	ERROR 185
REVERSE(POS(0))	ERROR 177
REVERSE(ARRAY(2))	ERROR 177
LEN(1)	PATTERN
LEN(1.5)	PATTERN
REVERSE('abc')	STRING
REVERSE(12)	STRING
TXT
for p in a; do
    ( cd "$D" && timeout -k 5 10 "$SBL" -bf $p.sno < /dev/null 2>/dev/null | grep -v '^$' | grep -v '^[0-9]' | grep -E '^(trap|len|pos|rpos|tab|rtab|arbno|end)' > $p.sbl )
    cmp -s "$D/$p.want" "$D/$p.sbl" || refuse "sbl -bf does not answer $p as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/$p.sbl")]"
done
while IFS="$(printf '\t')" read -r x want; do
    printf '%s\n' "$x" > "$D/one.in"; o=$(cd "$D" && timeout -k 5 10 "$SBL" -bf e.sno < one.in 2>/dev/null)
    [ "$o" = "$want" ] || refuse "sbl -bf answers [$x] with [$o], pinned [$want]"
done < "$D/e.tsv"
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2>/dev/null && gcc "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
( cd "$D" && timeout -k 5 30 "$B/scrip" a.sno < /dev/null > a.m3 2>/dev/null )
( cd "$D" && m4bin a && timeout -k 5 30 ./a.bin < /dev/null > a.m4 2>/dev/null )
for m in m3 m4; do
    if [ -f "$D/a.$m" ] && cmp -s "$D/a.want" "$D/a.$m"; then arm "a $m (14 statements under &ERRLIMIT)" ok
    else arm "a $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/a.$m")] want [$(tr '\n' '|' < "$D/a.want")]"; fi
done
( cd "$D" && m4bin e )
e3=""; e4=""
while IFS="$(printf '\t')" read -r x want; do
    printf '%s\n' "$x" > "$D/one.in"
    o3=$(cd "$D" && timeout -k 5 10 "$B/scrip" e.sno < one.in 2>/dev/null); [ "$o3" = "$want" ] || e3="$e3 [$x: $o3]"
    o4=$(cd "$D" && timeout -k 5 10 ./e.bin < one.in 2>/dev/null); [ "$o4" = "$want" ] || e4="$e4 [$x: $o4]"
done < "$D/e.tsv"
[ -z "$e3" ] && arm "e m3 (16 EVAL lines, one process each)" ok || arm "e m3" "$e3"
[ -z "$e4" ] && arm "e m4 (16 EVAL lines, one process each)" ok || arm "e m4" "$e4"
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): LEN/POS/RPOS/TAB/RTAB raise sbl's 120-121/162-163/185-186/183-184/181-182 at construction and REVERSE of a pattern or array raises 177 -- both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1

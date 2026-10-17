#!/usr/bin/env bash
# test_gate_sno_a_deferred_cset_argument_that_evaluates_to_null_or_a_pattern_raises_spitbols_error.sh
#
# THE DEFECT (row snobol4-a-deferred-cset-argument-that-evaluates-to-null-or-a-pattern-is-an-error-in-sbl-where-scrip-fails-the-
# match): ANY, NOTANY, SPAN, BREAK and BREAKX evaluate a DEFERRED argument (*X) at match time, and in sbl a value that is the
# null string or a pattern is an error -- 43, 49, 56, 44, 45, "<fn> evaluated argument is not a string" (sbl.min p_and/p_nad/
# p_spd/p_bkd/p_bxd through evals and patst) -- that ends the match; SCRIP failed the match quietly (NOTANY matched).
# THE CURE: each box's take (rt_pat_prim_str_take) carries its code pair, coerces through rt_coerce_str_d and fails when it
# raised; ANY and NOTANY evaluate the argument before the cursor test, as sbl does (an error at the end of the subject too);
# the error ENDS THE MATCH, as sbl's does -- MATCH_BEGIN's retry and MATCH_END's success both fail while a SETEXIT exit is
# pending (rtccb[25], the slot MATCH_DEFER already reads), and a raise that left none pending (an &ERRLIMIT count, or
# SETEXIT('CONTINUE')) arms the CONTINUE trampoline there, so the statement's own exit test resumes its failure edge. Without
# that, every scan position re-raised: &ERRLIMIT drained per position and a later trap died fatal.
# NOT HERE: mode 4 dies in rt_pat_prim_str_take on a deferred ANY/NOTANY after a BREAK or SPAN was built (its own row,
# snobol4-mode-4-crashes-on-a-deferred-any-after-a-break-or-span-was-built), so no program below puts one after the other, and
# the EVAL lines run one process each.
#
# Every answer cut from sbl -bf at run time and pinned: a pinned line sbl no longer prints is a REFUSAL, never a green.
# Both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
        &ERRLIMIT = 20
        S = ''
        SETEXIT('H')
        'abc' ? ANY(*S)
        SETEXIT('H')
        'abc' ? NOTANY(*S)
        SETEXIT('H')
        'abc' ? SPAN(*S) . X
        SETEXIT('H')
        'abc' ? BREAK(*S)
        SETEXIT('H')
        'abc' ? BREAKX(*S)
        SETEXIT('H')
        'abc' ? SPAN(*LEN(1))
        OUTPUT = 'end'                                   :(END)
H       OUTPUT = 'trap ' &ERRTYPE ' ' &ERRTEXT           :(CONTINUE)
END
SNO
printf '%s\n' 'trap 43 any evaluated argument is not a string' 'trap 49 notany evaluated argument is not a string' \
    'trap 56 span evaluated argument is not a string' 'trap 44 break evaluated argument is not a string' \
    'trap 45 breakx evaluated argument is not a string' 'trap 56 span evaluated argument is not a string' 'end' > "$D/a.want"
cat > "$D/b.sno" <<'SNO'
        N = 0
        DEFINE('F()')                                    :(FE)
F       N = N + 1
        F = 'x'                                          :(RETURN)
FE      '' ? ANY(*F())
        OUTPUT = 'count ' N
        'ab' ? ANY(*F()) ANY(*F())
        OUTPUT = 'count ' N
        V = 'b'
        OUTPUT = ('abc' ? ANY(*V)) ' control'
        OUTPUT = ('abc' ? NOTANY(*'a')) ' notany control'
END
SNO
printf 'count 1\ncount 4\nb control\nb notany control\n' > "$D/b.want"
cat > "$D/c.sno" <<'SNO'
        &ERRLIMIT = 1
        S = ''
        'abc' ? ANY(*S)
        OUTPUT = 'after ' &ERRLIMIT ' ' &ERRTYPE
END
SNO
printf 'after 0 43\n' > "$D/c.want"
cat > "$D/d.sno" <<'SNO'
        &ERRLIMIT = 3
        S = ''
        'abc' ? (ANY(*S) | 'a') . X                      :S(Y)
        OUTPUT = 'failed ' &ERRLIMIT ' [' X ']'          :(Z)
Y       OUTPUT = 'matched [' X ']'
Z       OUTPUT = 'end'
END
SNO
printf 'failed 2 []\nend\n' > "$D/d.want"
cat > "$D/s.sno" <<'SNO'
        &ERRLIMIT = 5
        S = ''
        SETEXIT('CONTINUE')
        'abc' ? ANY(*S)                                  :S(Y)F(N)
Y       OUTPUT = 'matched'                               :(Z)
N       OUTPUT = 'failed ' &ERRLIMIT ' ' &ERRTYPE
Z       'abc' ? SPAN(*S) 'q'
        OUTPUT = 'next ' &ERRLIMIT
END
SNO
printf 'failed 4 43\nnext 3\n' > "$D/s.want"
cat > "$D/t.sno" <<'SNO'
        &ERRLIMIT = 20
        S = ''
        SETEXIT('H')
        'abc' ? (ANY(*S) | 'a') . X
        OUTPUT = 'after1 [' X ']'
        SETEXIT('H')
        'abc' ? ('z' | NOTANY(*S) | 'b') . Y
        OUTPUT = 'after2 [' Y ']'
        OUTPUT = 'end'                                   :(END)
H       OUTPUT = 'trap ' &ERRTYPE                        :(CONTINUE)
END
SNO
printf 'trap 43\nafter1 []\ntrap 49\nafter2 []\nend\n' > "$D/t.want"
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
'xyz' ? ANY(*'')	ERROR 43
'xyz' ? NOTANY(*'')	ERROR 49
'xyz' ? SPAN(*'')	ERROR 56
'xyz' ? BREAK(*'')	ERROR 44
'xyz' ? BREAKX(*'')	ERROR 45
'xyz' ? SPAN(*LEN(1))	ERROR 56
'' ? ANY(*'')	ERROR 43
'' ? NOTANY(*'')	ERROR 49
'x' ? 'x' ANY(*'')	ERROR 43
'' ? ANY(*'a')	FAIL
'xyz' ? ANY(*'y')	STRING
TXT
printf "        S = ''\n        OUTPUT = 'before'\n        'abc' ? SPAN(*S)\n        OUTPUT = 'after'\nEND\n" > "$D/f.sno"
for p in a b c d s t; do
    ( cd "$D" && timeout -k 5 10 "$SBL" -bf $p.sno < /dev/null > $p.sbl 2>/dev/null )
    cmp -s "$D/$p.want" "$D/$p.sbl" || refuse "sbl -bf does not answer $p as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/$p.sbl")]"
done
while IFS="$(printf '\t')" read -r x want; do
    printf '%s\n' "$x" > "$D/one.in"; o=$(cd "$D" && timeout -k 5 10 "$SBL" -bf e.sno < one.in 2>/dev/null)
    [ "$o" = "$want" ] || refuse "sbl -bf answers [$x] with [$o], pinned [$want]"
done < "$D/e.tsv"
( cd "$D" && timeout -k 5 10 "$SBL" -bf f.sno < /dev/null > f.sbl 2>/dev/null )
[ "$(head -1 "$D/f.sbl")" = before ] && grep -q 'ERROR 056 --' "$D/f.sbl" && ! grep -q '^after$' "$D/f.sbl" \
    || refuse "sbl -bf no longer stops f at error 56: [$(tr '\n' '|' < "$D/f.sbl" | cut -c1-300)]"
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2>/dev/null && gcc -no-pie "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
for p in a b c d s t; do
    ( cd "$D" && timeout -k 5 30 "$B/scrip" $p.sno < /dev/null > $p.m3 2>/dev/null )
    ( cd "$D" && m4bin $p && timeout -k 5 30 ./$p.bin < /dev/null > $p.m4 2>/dev/null )
    for m in m3 m4; do
        if [ -f "$D/$p.$m" ] && cmp -s "$D/$p.want" "$D/$p.$m"; then arm "$p $m" ok
        else arm "$p $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/$p.$m")] want [$(tr '\n' '|' < "$D/$p.want")]"; fi
    done
done
( cd "$D" && m4bin e )
e3=""; e4=""
while IFS="$(printf '\t')" read -r x want; do
    printf '%s\n' "$x" > "$D/one.in"
    o3=$(cd "$D" && timeout -k 5 10 "$B/scrip" e.sno < one.in 2>/dev/null); [ "$o3" = "$want" ] || e3="$e3 [$x: $o3]"
    o4=$(cd "$D" && timeout -k 5 10 ./e.bin < one.in 2>/dev/null); [ "$o4" = "$want" ] || e4="$e4 [$x: $o4]"
done < "$D/e.tsv"
[ -z "$e3" ] && arm "e m3 (11 EVAL lines, one process each)" ok || arm "e m3" "$e3"
[ -z "$e4" ] && arm "e m4 (11 EVAL lines, one process each)" ok || arm "e m4" "$e4"
( cd "$D" && timeout -k 5 30 "$B/scrip" f.sno < /dev/null > f.m3 2> f.m3e; echo $? > f.m3rc )
( cd "$D" && { m4bin f && timeout -k 5 30 ./f.bin < /dev/null > f.m4 2> f.m4e; echo $? > f.m4rc; } )
for m in m3 m4; do
    if [ "$(cat "$D/f.${m}rc" 2>/dev/null)" != 0 ] && [ "$(cat "$D/f.$m" 2>/dev/null)" = before ] && grep -q 'error 56:' "$D/f.${m}e" 2>/dev/null; then arm "f $m" ok
    else arm "f $m" "rc=$(cat "$D/f.${m}rc" 2>/dev/null) out=[$(tr '\n' '|' < "$D/f.$m" 2>/dev/null)] err=[$(tr '\n' '|' < "$D/f.${m}e" 2>/dev/null)], want before then error 56"; fi
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): a deferred ANY/NOTANY/SPAN/BREAK/BREAKX argument that evaluates to null or a pattern raises sbl's 43/49/56/44/45"
    echo "  and ends the match -- trapped, counted, CONTINUE'd, fatal, under EVAL -- both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1

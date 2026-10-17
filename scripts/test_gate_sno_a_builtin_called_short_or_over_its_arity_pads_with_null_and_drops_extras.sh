#!/usr/bin/env bash
# test_gate_sno_a_builtin_called_short_or_over_its_arity_pads_with_null_and_drops_extras.sh
#
# SPITBOL'S RULE: a system function has a fixed number of arguments (sbl.min declares it beside each entry: DUPL 2,
# LPAD 3, SIZE 1, APPLY and ITEM 999, that is variadic). A call with fewer is padded with the null string and a call
# with more evaluates the extras and drops them, so SIZE() is 0, DUPL('ab') is '', LPAD('a') is 'a', INTEGER() succeeds
# and INTEGER(2, 7) is INTEGER(2). CONVERT's second argument must be a non-null string (sbl.min s_cnv: gtstg, then the
# null test): CONVERT('1') is ERROR 074, as are a pattern or an array type; an integer, real or name type converts to its
# string and fails plainly as an unknown datatype name.
# WHAT SCRIP DID (the ceo's row snobol4-a-builtin-called-with-fewer-or-more-arguments-than-it-declares-fails-where-spitbol-
# pads-with-null-and-drops-extras, CEO-1422/1428): the by-id fast block of try_call_builtin_by_name_bl_s returned a body's
# -1 ("not mine") to a caller that reads any non-zero as handled, so SIZE() and friends FAILED; and a short or over call
# reached APPLY's registered body by a different road than the explicit-null call (INTEGER() failed, INTEGER(2, 7) was 2).
# THE CURE, AT THE NORMALIZATION, NEVER PER BUILTIN: the fast block falls through on a decline; register_fn keeps the
# declared maximum it used to discard; core_fn_arity_norm pads a call to a registered builtin body up to its minimum and
# truncates it to its maximum at both SNOBOL4 entries (c_rt_call_bid_sn4's leaf branch, rt_call_arr_bl_sn4), so a short
# or over call takes the same road as the full one. The registered maxima are sbl.min's counts (DATE 1, HOST 5, TABLE 3
# raised to them; APPLY and ITEM variadic). CONVERT raises 074 at the one body every such call ends in.
# NOT COVERED, AND WHY: CONVERT('1', 'integer') succeeds in SCRIP, which folds the type name, where sbl -bf fails it (no
# case folding) -- a case-folding class of its own. INPUT and OUTPUT keep SCRIP's fourth argument (sbl declares 3).
#
# Expectations are cut from sbl -bf AT RUN TIME, both modes; every arm grades its whole stdout. Operands are variables,
# because sbl folds a constant call at compile time. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- the expectations are cut from it at run time"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT

calls() {  # the calls, each reported through R(K, V)
cat <<'SNO'
RE      R(1, SIZE())
        R(2, SIZE(AB, A))
        R(3, DUPL(AB))
        R(4, DUPL(AB, N2, A))
        R(5, TRIM())
        R(6, TRIM(AB '  ', A))
        R(7, LPAD(A))
        R(8, LPAD(A, 3, '*', A))
        R(9, RPAD())
        R(10, REVERSE(AB, A))
        R(14, SUBSTR(S3, N2))
        R(15, INTEGER())
        R(16, INTEGER(N2, N7))
        R(17, IDENT())
        R(18, DIFFER(A))
        R(19, EQ())
        R(20, LGT(AB))
SNO
}
head_of() {  # $1 the &ERRLIMIT
cat <<SNO
        &ERRLIMIT = $1
        AB = 'ab'
        A = 'a'
        S3 = 'abc'
        N2 = 2
        N7 = 7
        DEFINE('R(K,V)')                                  :(RE)
R       OUTPUT = K '<' V '> ERRLIMIT=' &ERRLIMIT          :(RETURN)
SNO
}
{ head_of 0; calls; echo "        OUTPUT = 'end'"; echo "END"; } > "$D/leaf.sno"
{ head_of 50; calls; cat <<'SNO'
        R(11, REPLACE(S3))
        R(12, REPLACE(S3, A))
        R(13, SUBSTR(S3))
        R(21, REMDR(N7))
        R(22, CONVERT(N7))
        OUTPUT = 'end ERRLIMIT=' &ERRLIMIT
END
SNO
} > "$D/counted.sno"
cat > "$D/ev.sno" <<'SNO'
        &TRIM = 1
loop    line = INPUT                                            :F(END)
        &ERRLIMIT = 1000
        SETEXIT('errh')
        r = EVAL(line)                                          :S(ok)
        OUTPUT = 'FAIL'                                         :(loop)
ok      OUTPUT = DATATYPE(r) ' ' r                              :(loop)
errh    OUTPUT = 'ERROR ' &ERRTYPE                              :(loop)
END
SNO
printf "SIZE()\nSIZE(,)\nDUPL('ab')\nDUPL()\nTRIM()\nLPAD('a')\nRPAD('a')\nREVERSE()\nINTEGER()\nINTEGER(5, 6)\nCONVERT('1')\n" > "$D/ev.in"
cat > "$D/edge.sno" <<'SNO'
        DEFINE('F(A,B,C,D,E,G,H,I,J,K)')               :(FE)
F       F = A B C D E G H I J K                        :(RETURN)
FE      OUTPUT = '1<' APPLY('F', 1, 2, 3, 4, 5, 6, 7, 8, 9, 0) '>'
        OPSYN('MYSIZE', 'SIZE')
        OUTPUT = '2<' MYSIZE() '>'
        OUTPUT = '3<' MYSIZE('abc', 'x') '>'
        A = ARRAY('2,2')
        A[1,2] = 'q'
        OUTPUT = '6<' ITEM(A, 1, 2) '>'
        T = TABLE(10, 10)
        T['k'] = 'v'
        OUTPUT = '7<' T['k'] '>'
        OUTPUT = 'end'
END
SNO
cat > "$D/cnv.sno" <<'SNO'
        &ERRLIMIT = 20
        DEFINE('T(V,K)')                         :(TE)
T       L = &ERRLIMIT
        X = CONVERT('1', V)                      :S(TS)
        OUTPUT = K ' FAIL ' (L - &ERRLIMIT) ' counted'  :(RETURN)
TS      OUTPUT = K ' OK [' X ']'                 :(RETURN)
TE      T('', 'null')
        T(12, 'int')
        T(LEN(1), 'pattern')
        T(ARRAY(2), 'array')
        T('FOO', 'unknown')
        T(.Q, 'name')
        T(2.5, 'real')
        T('INTEGER', 'upper')
END
SNO
ARMS="leaf counted ev edge cnv"
inp() { [ -f "$D/$1.in" ] && echo "$D/$1.in" || echo /dev/null; }
run_scrip() {  # $1 name $2 mode -> stdout
    if [ "$2" = m3 ]; then (cd "$D" && timeout -k 5 30 "$B/scrip" "$1.sno" < "$(inp "$1")" 2>/dev/null)
    else "$B/scrip" --compile -o "$D/$1.s" "$D/$1.sno" </dev/null >/dev/null 2>&1 \
           && gcc -no-pie -o "$D/$1.bin" "$D/$1.s" -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" 2>/dev/null \
           || refuse "could not build the m4 arm of $1 -- a toolchain failure, not a verdict"
         (cd "$D" && timeout -k 5 30 "./$1.bin" < "$(inp "$1")" 2>/dev/null); fi
}
for a in $ARMS; do (cd "$D" && timeout -k 5 30 "$SBL" -bf "$a.sno" < "$(inp "$a")" > "$a.sbl" 2>/dev/null); done
grep -qx "1<0> ERRLIMIT=0" "$D/leaf.sbl" && grep -qx "16<> ERRLIMIT=50" "$D/counted.sbl" || refuse "the oracle no longer pads SIZE() or drops INTEGER's extra -- re-read sbl"
grep -qx "null FAIL 1 counted" "$D/cnv.sbl" && grep -qx "ERROR 74" "$D/ev.sbl" || refuse "the oracle's CONVERT no longer raises 074 on a null type -- re-read sbl.min s_cnv"
[ "$(wc -l < "$D/ev.sbl")" = "$(wc -l < "$D/ev.in")" ] || refuse "the oracle answered $(wc -l < "$D/ev.sbl") of $(wc -l < "$D/ev.in") EVAL lines"
fails=0; arms=0
for m in m3 m4; do
    for a in $ARMS; do
        arms=$((arms+1)); run_scrip "$a" "$m" > "$D/$a.$m"
        if cmp -s "$D/$a.sbl" "$D/$a.$m"; then printf '  ok    %s %-7s %s lines, as sbl\n' "$m" "$a" "$(wc -l < "$D/$a.sbl")"
        else printf '  FAIL  %s %-7s\n' "$m" "$a"; diff "$D/$a.sbl" "$D/$a.$m" | head -6 | sed 's/^/          /'; fails=$((fails+1)); fi
    done
done
[ "$fails" -eq 0 ] || { echo "⛔ GATE FAILED: $fails of $arms arm(s) red."
    echo "   leaf/counted/ev: a short or over call no longer normalized (core_fn_arity_norm, the two SNOBOL4 entries in by_name_dispatch.c)"
    echo "   or a body's decline read as FAIL (the by-id fast block); edge: a variadic or alias arity; cnv: _CONVERT_'s 074."; exit 1; }
echo "✅ GATE OK: $arms arm(s) -- a builtin called short or over its arity is padded with null and its extras dropped (both entries and EVAL), CONVERT raises 074 on a non-string type, both modes"
exit 0

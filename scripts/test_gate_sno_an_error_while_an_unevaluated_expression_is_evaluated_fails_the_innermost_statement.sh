#!/usr/bin/env bash
# test_gate_sno_an_error_while_an_unevaluated_expression_is_evaluated_fails_the_innermost_statement.sh
#
# SPITBOL'S STAGE RULE (sbl.min, read by the cfo 2026-09-27 for CEO-1322): evalx (line 20940) sets stage=stgee
# whenever an unevaluated expression is evaluated at execution time -- a deferred capture target (. *X, $ *X), a
# deferred pattern element (*X), a deferred argument of a pattern primitive (LEN(*X)), EVAL of an expression.
# The error section sends every stgee error to err04 (line 29354), which pops to the NEARER of the innermost
# program-defined function call and the evaluation itself, and with &ERRLIMIT 0 takes exfal: THAT STATEMENT FAILS,
# &ERRLIMIT is untouched, &ERRTYPE/&ERRTEXT are set.  With &ERRLIMIT nonzero it is the ordinary err07 path.
# THE STAGE IS ONE GLOBAL TOGGLE, and three quirks follow from that, every one measured with sbl -bf here:
#   (1) ANY evalx exit resets it -- an inner *LEN(1) match completing inside the function makes a later error fatal;
#   (2) a PLAIN-VARIABLE deferred expression (*PV, an seblk) never touches it, entering or leaving;
#   (3) every execute-time COMPILE resets it (gtexp/gtcod: EVAL of a non-expression, CODE, CONVERT to EXPRESSION),
#       so EVAL('1'), EVAL(1), CODE(..) and CONVERT(..,'EXPRESSION') inside the function make a later error fatal.
# A direct call is fatal as ever.  SCRIP carries the stage in g_error's -3 (the error-conversion mode word, beside the
# EVAL guard's -1 and the fold probe's -2): set at the four deferred opens (dcap, capo, defer, prim) and EXPVAL,
# cleared at their lands, cleared by EVAL/CODE/CONVE, and read by core_runtime_error as "return; the statement fails".
#
# FOUND BY hq_snocone (bisected to 7ad35d97a/125a8f162): six Prolog sources crashed the bootstrap parser census with
# error 28 inside epsilon . *Shift('TT_ILIT', compute_radix(10, p_int)) where sbl keeps the 19-digit prefix.
#
# Expectations are cut from sbl -bf AT RUN TIME (no frozen copy to go stale).  Each arm grades three things per mode:
# stdout up to the error, FATAL versus CLEAN, and the fatal line.  rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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

cat > "$D/defs.inc" <<'SNO'
        DEFINE('CR(RAW)N,D')
        DEFINE('SH(T,V)')
        DEFINE('PE(RAW)')
        DEFINE('LNF()')
        DEFINE('CRP(RAW,K)N,D,X')                          :(ENDDEFS)
CR      N = 0
CR1     RAW LEN(1) . D =                                   :F(CR2)
        N = ((N * 10) + D)                                 :(CR1)
CR2     CR = N                                             :(RETURN)
SH      OUTPUT = 'SH ' T ' ' V
        SH = .DUMMY                                        :(NRETURN)
PE      PE = CR(RAW)                                       :(RETURN)
LNF     LNF = CR('1234567890123456789012345') - 1234567890123456780  :(RETURN)
CRP     IDENT(K,'Q')                                       :S(CRPQ)
        IDENT(K,'V')                                       :S(CRPV)
        IDENT(K,'E')                                       :S(CRPE)
        IDENT(K,'I')                                       :S(CRPI)
        IDENT(K,'C')                                       :S(CRPC)
        IDENT(K,'X')                                       :S(CRPX)F(CRP0)
CRPQ    'ab' ? *LEN(1)                                     :(CRP0)
CRPV    'ab' ? *PV                                         :(CRP0)
CRPE    X = EVAL('1')                                      :(CRP0)
CRPI    X = EVAL(1)                                        :(CRP0)
CRPC    X = CODE('ZZ OUTPUT = 1')                          :(CRP0)
CRPX    X = CONVERT('A + 1','EXPRESSION')                  :(CRP0)
CRP0    N = 0
CRP1    RAW LEN(1) . D =                                   :F(CRP2)
        N = ((N * 10) + D)                                 :(CRP1)
CRP2    CRP = N                                            :(RETURN)
ENDDEFS B = '1234567890123456789012345'
        BIG = 99999999999
        PV = LEN(1)
SNO
mk() { { cat "$D/defs.inc"; cat; printf '        OUTPUT = %s\nEND\n' "'END OF $1'"; } > "$D/$1.sno"; }
mk soft <<'SNO'
        'x' ? ('x' . *SH('COND', CR(B)))                   :F(XA)
        OUTPUT = 'A: conditional target soft, type=' &ERRTYPE ' text=' &ERRTEXT
XA      'x' ? ('x' $ *SH('IMM', CR(B)))                    :F(XB)
        OUTPUT = 'B: immediate target soft'
XB      '1234567890123456789' ? *PE(B)                     :F(XC)
        OUTPUT = 'C: deferred pattern element soft'
XC      'x' ? ('x' . *SH('DIRECT', BIG * BIG))             :S(XD)
        OUTPUT = 'D: an error in the expression itself fails the match'
XD      &ERRLIMIT = 10
        'x' ? ('x' . *SH('ERRLIM', CR(B)))                 :F(XE)
        OUTPUT = 'E: errlimit=' &ERRLIMIT
XE      &ERRLIMIT = 0
        'x' ? ('x' . *SH('SEBLK', CRP(B,'V')))             :F(XF)
        OUTPUT = 'F: a plain-variable element leaves the stage set'
XF      'abcdefghijk' ? LEN(*LNF()) . V                    :F(XG)
        OUTPUT = 'G: deferred primitive argument soft, V=' V
XG
SNO
mk direct <<'SNO'
        'x' ? ('x' . *SH('COND', CR(B)))
        OUTPUT = 'the stage is reset after the target'
        X = CR(B)
SNO
for k in Q E I C X; do mk "reset$k" <<SNO
        'x' ? ('x' . *SH('$k', CRP(B,'$k')))
SNO
done
mk failedeval <<'SNO'
        'x' ? *(BIG * BIG)                                 :S(Y)
        OUTPUT = 'the failed evaluation reset the stage'
Y       X = CR(B)
SNO

run_sbl() {  # -> $1.sbl.out (stdout before the error), $1.sbl.fatal (FATAL/CLEAN), $1.sbl.line
    (cd "$D" && timeout -k 5 20 "$SBL" -bf "$1.sno" </dev/null > "$1.sbl.raw" 2>/dev/null)
    if grep -q "^$1.sno([0-9]*) : ERROR [0-9]" "$D/$1.sbl.raw"; then
        echo FATAL > "$D/$1.sbl.fatal"; grep -o "^$1.sno([0-9]*) : ERROR" "$D/$1.sbl.raw" | head -1 | tr -dc '0-9' > "$D/$1.sbl.line"
        sed -n "/^$1.sno([0-9]*) : ERROR/q;p" "$D/$1.sbl.raw" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$D/$1.sbl.out"
    else echo CLEAN > "$D/$1.sbl.fatal"; : > "$D/$1.sbl.line"; cp "$D/$1.sbl.raw" "$D/$1.sbl.out"; fi
}
run_scrip() {  # $1 name $2 mode -> $1.$2.out/.err/.fatal/.line
    local n="$1" m="$2" rc
    if [ "$m" = m3 ]; then (cd "$D" && timeout -k 5 20 "$B/scrip" --stlimit "$n.sno" </dev/null > "$n.$m.out" 2> "$n.$m.err"); rc=$?
    else "$B/scrip" --compile --stlimit -o "$D/$n.s" "$D/$n.sno" </dev/null >/dev/null 2>&1 \
           && as -o "$D/$n.o" "$D/$n.s" 2>/dev/null \
           && gcc -o "$D/$n.bin" "$D/$n.o" "$B/out/libscrip_rt.so" -lm -Wl,-rpath,"$B/out" 2>/dev/null \
           || refuse "could not build the m4 arm of $n -- a toolchain failure, not a verdict"
         (cd "$D" && timeout -k 5 20 "./$n.bin" </dev/null > "$n.$m.out" 2> "$n.$m.err"); rc=$?; fi
    [ "$rc" -ge 124 ] && refuse "$n $m timed out or died of a signal (rc=$rc) -- neither verdict"
    if [ "$rc" -ne 0 ]; then echo FATAL > "$D/$n.$m.fatal"; grep -o "$n\.sno:[0-9]*" "$D/$n.$m.err" | head -1 | sed 's/.*://' | tr -dc '0-9' > "$D/$n.$m.line"
    else echo CLEAN > "$D/$n.$m.fatal"; : > "$D/$n.$m.line"; fi
}

fails=0; arms=0
for n in soft direct resetQ resetE resetI resetC resetX failedeval; do
    run_sbl "$n"
    for m in m3 m4; do
        run_scrip "$n" "$m"; arms=$((arms+1))
        why=""
        cmp -s "$D/$n.sbl.fatal" "$D/$n.$m.fatal" || why="$why sbl=$(cat "$D/$n.sbl.fatal") scrip=$(cat "$D/$n.$m.fatal")"
        cmp -s "$D/$n.sbl.line" "$D/$n.$m.line"   || why="$why fatal-line sbl=$(cat "$D/$n.sbl.line") scrip=$(cat "$D/$n.$m.line")"
        cmp -s "$D/$n.sbl.out" "$D/$n.$m.out"     || why="$why stdout-differs"
        if [ -z "$why" ]; then printf '  ok    %-10s %s: %s%s\n' "$n" "$m" "$(cat "$D/$n.sbl.fatal")" "$( [ -s "$D/$n.sbl.line" ] && printf ' at line %s' "$(cat "$D/$n.sbl.line")")"
        else printf '  FAIL  %-10s %s:%s\n' "$n" "$m" "$why"; diff "$D/$n.sbl.out" "$D/$n.$m.out" | head -6 | sed 's/^/          /'; head -2 "$D/$n.$m.err" | sed 's/^/          stderr: /'; fails=$((fails+1)); fi
    done
done
grep -q "^E: errlimit=4$" "$D/soft.sbl.out" || refuse "the oracle's soft program did not print its errlimit control line -- the witness is not measuring"
[ "$(cat "$D/resetQ.sbl.fatal")" = FATAL ] || refuse "the oracle no longer resets the stage on an inner evalx exit -- re-read sbl before trusting this gate"
[ "$fails" -eq 0 ] || { echo "⛔ GATE FAILED: $fails of $arms arm(s) red."
    echo "   A soft arm red with 'scrip=FATAL' is the stage not set at that open (or core_runtime_error not reading -3);"
    echo "   a reset arm red with 'scrip=CLEAN' is a land or a compile that no longer clears it."; exit 1; }
echo "✅ GATE OK: $arms arm(s) -- an error while an unevaluated expression is evaluated fails the innermost statement, and every reset sbl makes, SCRIP makes, both modes"
exit 0

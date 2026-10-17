#!/usr/bin/env bash
# test_gate_sno_a_return_trace_callback_prints_the_deferred_banner_with_the_callers_statement_number.sh
#
# THE DEFECT (row snobol4-after-a-return-trace-callback-sbl-prints-the-functions-return-banner-with-the-callers-statement-number): with &FTRACE on and a RETURN or FUNCTION trace
# callback on F, sbl prints F's own RETURN / FRETURN / NRETURN banner AFTER the callback with the CALLER's statement number ('****8 RETURN F = 1', the statement that called F), and
# with the function's call level (' i' when F runs inside G); SCRIP formatted the banner at the event with F's last statement number (****6) and a level one too low (the function
# level was lowered for the callback before the banner string was cut). THE CURE: the DEFINE shim passes the caller's saved &STNO (its own frame unit) to rt_trace_return_hook_p and
# rt_trace_fail_hook_p; a deferred banner of a RETURN event uses it; the banner is cut before the function level is lowered.
# The expected output is cut from sbl -bf at run time (SCRIP_SNO_STMTKW=1, as the graders run): a run sbl does not answer is a REFUSAL, never a green. Both modes.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
[ -x "$SBL" ] || refuse "the SNOBOL4 oracle $SBL is absent -- the expected banners cannot be cut"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
export SCRIP_SNO_STMTKW=1
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
mk() {
    printf '        &TRACE = 100\n        &FTRACE = 100000\n        DEFINE(%s)\t:(S)\nCB      OUTPUT = %s\t:(RETURN)\nS       DEFINE(%s)\t:(S2)\n%s\nS2      TRACE(%s)\n        X = F(1)\n        OUTPUT = %s\nEND\n' \
        "'CB(NAME,TAG)'" "'cb ' NAME ' ' TAG" "'F(A)'" "$2" "'F', 'RETURN', 'tg', .CB" "'done'" > "$D/$1.sno"
}
mk ret 'F       F = A	:(RETURN)'
mk fret 'F       F = A	:(FRETURN)'
mk nret 'F       F = .A	:(NRETURN)'
cat > "$D/nest.sno" <<'SNO'
        &TRACE = 100
        &FTRACE = 100000
        DEFINE('CB(NAME,TAG)')	:(S)
CB      OUTPUT = 'cb ' NAME ' ' TAG	:(RETURN)
S       DEFINE('F(A)')	:(S1)
F       F = A
        F = F + 1	:(RETURN)
S1      DEFINE('G(A)')	:(S2)
G       G = F(A) + 1	:(RETURN)
S2      TRACE('F', 'FUNCTION', 'tg', .CB)
        X = G(1)
        OUTPUT = X
        TRACE('F')
        Y = G(2)
END
SNO
m4bin() { timeout -k 5 60 "$B/scrip" --compile "$1.sno" < /dev/null > "$1.s" 2>/dev/null && gcc "$1.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$1.bin" 2>/dev/null; }
red=0; n=0
arm() { n=$((n + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
for p in ret fret nret nest; do
    ( cd "$D" && timeout -k 5 10 "$SBL" -bf "$p.sno" < /dev/null > "$p.want" 2>/dev/null )
    [ -s "$D/$p.want" ] || refuse "sbl -bf gave no answer for $p"
    ( cd "$D" && timeout -k 5 30 "$B/scrip" "$p.sno" < /dev/null > "$p.m3" 2>/dev/null )
    ( cd "$D" && m4bin "$p" && timeout -k 5 30 "./$p.bin" < /dev/null > "$p.m4" 2>/dev/null )
    for m in m3 m4; do
        if [ -f "$D/$p.$m" ] && cmp -s "$D/$p.want" "$D/$p.$m"; then arm "$p $m" ok
        else arm "$p $m" "got [$(tr '\n' '|' 2>/dev/null < "$D/$p.$m")] want [$(tr '\n' '|' < "$D/$p.want")]"; fi
    done
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): a RETURN, FRETURN or NRETURN callback leaves the deferred banner with the caller's statement number and the call level, as sbl -bf prints it, both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1

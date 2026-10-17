#!/usr/bin/env bash
# test_gate_sno_unary_caret_is_an_undefined_operator_error_29.sh
#
# THE DEFECT (the cto 2026-10-02, ceo CEO-1419 row snobol4-unary-caret-is-an-undefined-operator-error-29-where-scrip-passes-the-
# operand-or-exits, found by Lon's infinite_snobol4: about 34,000 differences): unary ^ is an undefined operator in SPITBOL,
# error 29 -- and it cannot be OPSYN'd (sbl: error 156). SCRIP ran it as a binary power with a null right operand: ^1 was 1,
# REM ^1 a PATTERN, 1.1 ^&INPUT the string 1.11, and 0 ^0 raised error 204, which the program died of.
# THE CAUSE: rt_call_arr_impl's one-argument arm (by_name_dispatch.c) raises 29 for the undefined unary operators / % # | ! =
# unless an OPSYN defined them, and ^ was missing from that list, so it fell through to the binary arm na(a, NULL, BINOP_POW).
# THE CURE: ^ joins the list, and sn4_unary_op_key gives it its own key (unary^), so a binary OPSYN of ^ can never answer for
# the unary operator.
#
# Each arm grades one line against sbl -bf cut AT RUN TIME, both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
cat > "$D/ev.sno" <<'SNO'
        &TRIM = 1
loop    line = INPUT                                            :F(END)
        &ERRLIMIT = 1000
        SETEXIT('errh')
        r = EVAL(line)                                          :S(ok)
        OUTPUT = 'FAIL'                                         :(loop)
ok      OUTPUT = DATATYPE(r)                                    :(loop)
errh    OUTPUT = 'ERROR ' &ERRTYPE                              :(loop)
END
SNO
cat > "$D/lines.txt" <<'TXT'
REM ^1
POS(1) ^2
&CASE /&BAL
1.1 ^&INPUT
0 ^0
'' ^0
^1
2 ^3
'a' ^'b'
2 ^ 3
!1
TXT
cat > "$D/st.sno" <<'SNO'
        &ERRLIMIT = 10
        SETEXIT('h')
        X = ^1
        OUTPUT = 'not reached ' X                 :(n2)
h       OUTPUT = 'trapped ' &ERRTYPE
n2      SETEXIT('h2')
        Y = 0 ^0
        OUTPUT = 'not reached ' Y                 :(n3)
h2      OUTPUT = 'trapped ' &ERRTYPE
n3      OPSYN('^', 'DUPL', 2)
        SETEXIT('h3')
        r = EVAL("^'x'")
        OUTPUT = 'not trapped ' r                 :(END)
h3      OUTPUT = 'trapped ' &ERRTYPE
END
SNO
N=$(wc -l < "$D/lines.txt")
( cd "$D" && timeout -k 5 30 "$SBL" -bf ev.sno < lines.txt > want 2>/dev/null; timeout -k 5 30 "$SBL" -bf st.sno < /dev/null > st.want 2>/dev/null )
[ "$(wc -l < "$D/want")" = "$N" ] && [ -s "$D/st.want" ] || refuse "sbl -bf gave no expectation to grade against"
( cd "$D" && timeout -k 5 30 "$B/scrip" ev.sno < lines.txt > m3 2>/dev/null; timeout -k 5 30 "$B/scrip" st.sno < /dev/null > st.m3 2>/dev/null )
( cd "$D" && for p in ev st; do timeout -k 5 120 "$B/scrip" --compile $p.sno < /dev/null > $p.s 2>/dev/null && gcc -no-pie $p.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o $p.bin 2>/dev/null || exit 2; done ) || refuse "mode 4 did not build"
( cd "$D" && timeout -k 5 30 ./ev.bin < lines.txt > m4 2>/dev/null; timeout -k 5 30 ./st.bin < /dev/null > st.m4 2>/dev/null )
red=0; i=0
while IFS= read -r t; do
    i=$((i + 1)); w=$(sed -n "${i}p" "$D/want")
    for m in m3 m4; do g=$(sed -n "${i}p" "$D/$m")
        if [ "$g" = "$w" ]; then echo "  ok   $m  $t  ->  $w"; else echo "  FAIL $m  $t  ->  got '${g:-<none: the run died>}' want '$w'"; red=$((red + 1)); fi
    done
done < "$D/lines.txt"
for m in m3 m4; do
    if cmp -s "$D/st.want" "$D/st.$m"; then echo "  ok   $m  st.sno (static ^1 and 0 ^0 under SETEXIT, unary ^ after a binary OPSYN)"; else echo "  FAIL $m  st.sno: got [$(tr '\n' '|' < "$D/st.$m")] want [$(tr '\n' '|' < "$D/st.want")]"; red=$((red + 1)); fi
done
T=$(( (N + 1) * 2 ))
if [ $red -eq 0 ]; then echo "GATE PASS(0): unary ^ is an undefined operator, error 29, $T arm(s)"; exit 0; fi
echo "GATE FAIL(1): $red of $T arm(s) diverge from sbl -bf"; exit 1

#!/usr/bin/env bash
# test_gate_sno_convert_reads_a_numeric_string_as_spitbol_gtnum_does.sh -- CONVERT(S,'INTEGER'), CONVERT(S,'REAL') and
# CONVERT(S,'NUMERIC') read a string the way SPITBOL's gtnum reads it, through every door a SNOBOL4 program can call CONVERT by,
# and a pattern built with a CONVERT of the null string is built.
#
# ⛔ THE DEFECT (cfo 2026-09-26, row snobol4-parser-icon-on-bench-icnint-loop-dies-error-246-..., hq_snocone's find; ruled CEO-1292).
# The self-hosted parser_icon died ERROR 246 on EVERY Icon source holding an expression statement (bench_icnint_loop.icn was the
# witness; `procedure main() 1 end` is enough) in m3 and m4 at -s4096m, where sbl parses it at -s64m. The stack scan at the fault
# showed one 60 KB cycle repeating to the guard page -- an unbounded recursion, not a deep one. The chain, each link measured:
#   (1) parser_icon.sc builds Expr11 with `real_pat . rval assign(.t_imm, CONVERT(rval, 'REAL'))` -- the CONVERT runs when the
#       pattern is BUILT, while rval is still unset;
#   (2) SPITBOL: CONVERT('', 'REAL') is 0. (gtnum: a null string is zero). SCRIP: FAIL -- so the whole `Expr11 = ...` statement
#       failed and Expr11 stayed the null string;
#   (3) every expression level (*Expr11 -> ... -> *Expr) then matched the null string, so StmtBody matched null, and
#       `Procbody = ( ProcbodyEnd | StmtBody *Procbody )` recursed without consuming a character until the stack ran out.
# Replacing that one CONVERT call with (rval + 0.0) in a scratch copy made m3 parse the benchmark byte-identical to sbl.
#
# ⭐ THE CURE IS SPITBOL'S OWN CONVERTER, TRANSCRIBED, NOT A NEW RULE: rt_sno_cnv_num (src/runtime/core/core.c) is gtnum / gtint /
# gtrea of sbl.min (22758 ff.) label for label, with the x64 build's flags read from /home/resources/x64 (.caht: a tab is a blank;
# .culc: e E d D are exponent letters; reals on) and its arithmetic read from sbl.asm (SSE doubles, mxcsr 0x9fc0 = flush-to-zero,
# so every step's subnormal result is zero; `rti` is cvttsd2si compared against 0x80000000, so a real truncating to exactly
# 2147483648 FAILS and an out-of-range one is -9223372036854775808 -- the oracle's quirks, kept because the oracle is the law).
# SCRIP had THREE spellings of this conversion (core.c _CONVERT_, by_name_dispatch.c bn_convert, and its L_bidjmp copy), each
# built on strtoll/strtod, and each differed from the oracle: '' and blanks FAILED (sbl 0), '12 ' FAILED as INTEGER, '0x10' was
# 16 and 'inf'/'nan' converted (sbl FAIL), '1.5D2' FAILED (sbl 150.), '- ' FAILED (sbl 0), '1e-310' kept a subnormal (sbl 0.).
# All three now call the one function.
#
# THE DOORS (measured under gdb on the cure, 2026-09-26): a direct CONVERT(S,T) enters bn_convert; APPLY('CONVERT',...) and
# EVAL('CONVERT(...)') enter the L_bidjmp block; in m4 an OPSYN alias enters _CONVERT_ through APPLY_fn (on the parent that door
# alone answered INTEGER 0 for '', through to_int, while the other three FAILED); CONVERT(S,'NUMERIC') falls through both
# dispatcher copies to _CONVERT_. Every row of the fixture goes through all four spellings, for each of the three targets.
#
# THE ARMS (the expectation is cut from sbl -bf AT RUN TIME, never frozen here):
#   1  m3: the fixture's output equals sbl's byte for byte (76 rows x INTEGER/REAL/NUMERIC x four doors, plus the construction)
#   2  m4: the same, from the --compile binary
#   3  CONSTRUCTION: `P = ('a' | ('b' CONVERT(UNSETVAR, 'REAL')) | 'c')` completes and P matches 'c' -- parser_icon's own shape
# FAIL-ONCE (2026-09-26, this gate run inside a worktree of the parent 30705fc7b): rc=1, four arms red -- m3 differed from sbl
# on 64 of 230 lines and m4 on 91, and both printed "construction: the pattern statement FAILED, P is left unassigned".
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, the oracle's output is not the fixture's shape).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_convert_reads_a_numeric_string_as_spitbol_gtnum_does
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/w.sno" <<'SNO'
        &ERRLIMIT = 1000
        DEFINE('CV(S,T)R,X')
        DEFINE('ROW(L,S)')
        OPSYN('CNVA', 'CONVERT')                        :(MAIN)
CV      X = CONVERT(S, T)                               :F(CV1)
        R = DATATYPE(X) ' ' X                           :(CV2)
CV1     R = 'FAIL'
CV2     X = APPLY('CONVERT', S, T)                      :F(CV3)
        R = R ' | ' DATATYPE(X) ' ' X                   :(CV4)
CV3     R = R ' | FAIL'
CV4     X = EVAL('CONVERT(S, T)')                       :F(CV5)
        R = R ' | ' DATATYPE(X) ' ' X                   :(CV6)
CV5     R = R ' | FAIL'
CV6     X = CNVA(S, T)                                  :F(CV7)
        R = R ' | ' DATATYPE(X) ' ' X                   :(CV8)
CV7     R = R ' | FAIL'
CV8     CV = R                                          :(RETURN)
ROW     OUTPUT = RPAD(L, 12) ' I: ' CV(S, 'INTEGER')
        OUTPUT = RPAD(L, 12) ' R: ' CV(S, 'REAL')
        OUTPUT = RPAD(L, 12) ' N: ' CV(S, 'NUMERIC')    :(RETURN)
MAIN    ROW('null', '')
        ROW('blank1', ' ')
        ROW('blank3', '   ')
        ROW('tab', CHAR(9))
        ROW('sp12', ' 12')
        ROW('12sp', '12 ')
        ROW('sp12sp', ' 12 ')
        ROW('12tab', '12' CHAR(9))
        ROW('tab7', CHAR(9) '7')
        ROW('plus5', '+5')
        ROW('minus5', '-5')
        ROW('1.5', '1.5')
        ROW('sp1.5sp', ' 1.5 ')
        ROW('1.', '1.')
        ROW('.5', '.5')
        ROW('-.5', '-.5')
        ROW('+.5', '+.5')
        ROW('1e3', '1e3')
        ROW('1E3', '1E3')
        ROW('1.5e2', '1.5e2')
        ROW('1.5D2', '1.5D2')
        ROW('1d2', '1d2')
        ROW('5.e1', '5.e1')
        ROW('1e-2', '1e-2')
        ROW('1E+03', '1E+03')
        ROW('1e', '1e')
        ROW('1esp', '1e ')
        ROW('1e+sp', '1e+ ')
        ROW('sp1e2sp', ' 1e2 ')
        ROW('1e2x', '1e2 x')
        ROW('00012', '00012')
        ROW('-0', '-0')
        ROW('-0.0', '-0.0')
        ROW('abc', 'abc')
        ROW('12abc', '12abc')
        ROW('1sp2', '1 2')
        ROW('-sp5', '- 5')
        ROW('plus', '+')
        ROW('minus', '-')
        ROW('sp-', ' -')
        ROW('-sp', '- ')
        ROW('sp-sp', ' - ')
        ROW('+sp', '+ ')
        ROW('.', '.')
        ROW('-.', '-.')
        ROW('.e1', '.e1')
        ROW('1.5.', '1.5.')
        ROW('0x10', '0x10')
        ROW('inf', 'inf')
        ROW('nan', 'nan')
        ROW('1,5', '1,5')
        ROW('12nul', '12' CHAR(0))
        ROW('2^31+.5', '2147483648.5')
        ROW('2^31', '2147483648')
        ROW('2^31-.1', '2147483647.9')
        ROW('-2^31-.5', '-2147483648.5')
        ROW('1e30', '1e30')
        ROW('-1e30', '-1e30')
        ROW('20nines', '99999999999999999999')
        ROW('20nines.', '99999999999999999999.')
        ROW('2^63-1', '9223372036854775807')
        ROW('2^63', '9223372036854775808')
        ROW('-2^63', '-9223372036854775808')
        ROW('2^63+1', '9223372036854775809')
        ROW('1e-300', '1e-300')
        ROW('1e-310', '1e-310')
        ROW('1e308', '1e308')
        ROW('1e309', '1e309')
        ROW('dblmax', '1.7976931348623157E+308')
        ROW('0.1', '0.1')
        ROW('30digits.', '123456789012345678901234567890.')
        ROW('real2^31+.5', 2147483648.5)
        ROW('real-2^31-.5', -2147483648.5)
        ROW('real1e30', 1.0E30)
        ROW('int12', 12)
        ROW('real1.5', 1.5)
        P = ('a' | ('b' CONVERT(UNSETVAR, 'REAL')) | 'c')  :F(PF)
        OUTPUT = 'construction: the pattern statement completes, P is ' DATATYPE(P)   :(PT)
PF      OUTPUT = 'construction: the pattern statement FAILED, P is left unassigned'
PT      'c' ? POS(0) P RPOS(0)                           :F(PT1)
        OUTPUT = 'construction: P matches c'             :(END)
PT1     OUTPUT = 'construction: P does not match c'
END
SNO
( cd "$T" && timeout -k 5 30 "$SBL" -bf w.sno ) < /dev/null > "$T/w.sbl" 2>&1
n=$(wc -l < "$T/w.sbl")
[ "$n" = 230 ] || refuse "the oracle printed $n lines, not the fixture's 230 -- the oracle moved or failed, so there is nothing to grade against"
grep -qx 'construction: the pattern statement completes, P is PATTERN' "$T/w.sbl" || refuse "the oracle did not build the construction pattern -- not the oracle this gate was written against"
grep -qx 'construction: P matches c' "$T/w.sbl" || refuse "the oracle's construction pattern does not match 'c' -- not the oracle this gate was written against"
( cd "$T" && timeout -k 5 30 "$SCRIP" w.sno ) < /dev/null > "$T/w.m3" 2>&1
"$SCRIP" --compile -o "$T/w.s" "$T/w.sno" < /dev/null > /dev/null 2>&1 && as -o "$T/w.o" "$T/w.s" 2>/dev/null \
  && gcc -o "$T/w.bin" "$T/w.o" "$RT_DIR/libscrip_rt.so" -Wl,-rpath,"$RT_DIR" -lm 2>/dev/null \
  || refuse "could not build the m4 arm -- a toolchain failure, not a verdict"
( cd "$T" && timeout -k 5 30 ./w.bin ) < /dev/null > "$T/w.m4" 2>&1
red=0
for m in m3 m4; do
    if cmp -s "$T/w.sbl" "$T/w.$m"; then
        echo "  ok    $m: CONVERT to INTEGER, REAL and NUMERIC equals sbl -bf on all 230 lines, four doors each"
    else
        red=$((red+1)); echo "  RED   $m: $(diff "$T/w.sbl" "$T/w.$m" | grep -c '^>') of 230 line(s) differ from sbl -bf; the first:"
        diff "$T/w.sbl" "$T/w.$m" | head -8 | sed 's/^/          /'
    fi
    if grep -qx 'construction: P matches c' "$T/w.$m"; then echo "  ok    $m: a pattern built with CONVERT of the null string is built and matches"
    else red=$((red+1)); echo "  RED   $m: $(grep '^construction:' "$T/w.$m" | head -1)"; fi
done
[ "$red" -eq 0 ] || { echo "⛔ GATE FAILED [$NAME]: $red arm(s) red"; exit 1; }
echo "✅ GATE OK [$NAME]: CONVERT reads a numeric string as SPITBOL's gtnum does, m3 and m4, every door"
exit 0

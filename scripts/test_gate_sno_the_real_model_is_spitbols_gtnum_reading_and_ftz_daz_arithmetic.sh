#!/usr/bin/env bash
# test_gate_sno_the_real_model_is_spitbols_gtnum_reading_and_ftz_daz_arithmetic.sh -- SCRIP's SNOBOL4 real model IS SPITBOL's (ceo
# CEO-1352 ruling 2, 2026-09-28: "not IEEE by choice"; RULES.md section Oracles, one oracle one feature set; X64T is SPITBOL's own deck).
# The two halves land TOGETHER because half the model is worse than none (measured: gtnum alone took X64T math_diff 15376/0 -> 15364/12).
#   (i)  READING: a real literal (the SNOBOL4 lexer's T_REAL, the Snocone parser's sc_real_literal) and EVAL/REAL() of a numeric string
#        (rt_str_to_real) read the decimal digits the way SPITBOL's gtnum does (sbl.min 22758 ff.): the mantissa accumulated as a real,
#        scaled by 1e10 steps and one power-of-ten entry, every step flushed as under the x64 build's mxcsr 0x9fc0 (int.asm:195) -- so
#        2.0E-324..3.0E-324 read 0. and 1.797693134862316E+308 reads finite. rt_gtn_real (core.c) over rt_gtn_str; strtod only where
#        gtnum refuses the text.
#   (ii) ARITHMETIC: the lowering for the SNOBOL4 family (lower_sno_stage2: SNOBOL4, Snocone, Rebus) emits ONE call at program entry,
#        IR_CALL "$fp_model_spitbol" -> rt_fp_model_spitbol, which sets MXCSR FTZ|DAZ in BOTH modes (never in core_lib_init, so no
#        other frontend's process is touched): a subnormal result flushes to 0 and a subnormal operand (a numeric STRING coerced by the
#        shared to_real, which stays strtod) reads as 0 in arithmetic and comparison, exactly as sbl.
#   (iii) THE OPTIMIZER: const_fold runs before the program does, in the compiler's own IEEE mode, so it does not fold a real operation
#        whose operand or result is subnormal (cf_subnormal) -- the run computes it under the program's model instead.
# THE ARMS (every expectation is cut from sbl -bf AT RUN TIME, never frozen here):
#   1  m3: the reading fixture equals sbl byte for byte          2  m4: the same, from the --compile binary
#   3  EVAL('3.0E-324') is 0. and EVAL('1.797693134862316E+308') is finite (math_limits1/3/4's witness), m3
#   4  m3 and 5  m4: the ARITHMETIC fixture (a subnormal quotient, a subnormal string coerced into - and LT, a foldable constant
#      quotient, and four of the twelve math_diff checks that went red under half the model) equals sbl byte for byte
#   6  Snocone m3 and m4: the arithmetic witness written in Snocone equals sbl on its --transpile form
#   7  CONTAINMENT: an Icon program's subnormal quotient is NOT flushed (iconx prints it; SCRIP m3 must too) -- the model is the
#      SNOBOL4 family's, not the process's
# FAIL-ONCE (MEASURED 2026-09-28 on SCRIP afb76a6c8 + this change): with the "$fp_model_spitbol" call removed from lower_snobol4.c, arms 4
#   5 6 read red (quot 0.999999999999997e-310, the coerced string 0.263083649990258e-309); with const_fold's cf_subnormal guard removed
#   (prologue kept), arms 4 5 read red on the folded line alone (fold 0.999999999999997e-310: the compiler folded it in its own IEEE
#   mode); with the gtnum reading stashed, arms 1 2 3 read red (the shelved gate's own measurement on a041c3c9b).
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, the oracle's output is not the fixture's shape).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
GATE_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
. "$HERE/lib_oracle_flags.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_oracle_flags.sh unavailable"; exit 2; }
O="$(sbl_correctness_bin)" || exit 2
[ -x "$O" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no oracle at $O"; exit 2; }
T="$(mktemp -d)" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
red=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  RED  $1 -- $3"; red=$((red+1)); fi; }
cat > "$T/fx.sno" <<'EOF'
	OUTPUT = 'lit 1 ' 1.0E-310
	OUTPUT = 'lit 2 ' 2.2250738585072014E-308
	OUTPUT = 'lit 3 ' 0.1
	OUTPUT = 'lit 4 ' 123.456
	OUTPUT = 'lit 5 ' 1.5E300
	OUTPUT = 'lit 6 ' 6.02E23
	OUTPUT = 'lit 7 ' 1.797693134862316E+308
	OUTPUT = 'lit 8 ' 3.14159265358979
	N = 0
LOOP	N = N + 1
	S = IDENT(N, 1) '1.0E-310'
	S = IDENT(N, 2) '4.9E-324'
	S = IDENT(N, 3) '2.470328230E-324'
	S = IDENT(N, 4) '3.000000000E-324'
	S = IDENT(N, 5) '2.2250738585072014E-308'
	S = IDENT(N, 6) '1.797693134862316E+308'
	S = IDENT(N, 7) '1.797693134862317E+308'
	S = IDENT(N, 8) '-1.797693134862316E+308'
	S = IDENT(N, 9) '0.30000000000000004'
	S = IDENT(N, 10) '123456789012345678901.5'
	S = IDENT(N, 11) '1.0E-300'
	S = IDENT(N, 12) ' 2.5'
	OUTPUT = 'eval ' N ' ' EVAL(S)	:S(NEXT)
	OUTPUT = 'eval ' N ' FAILS'
NEXT	LT(N, 12)	:S(LOOP)
END
EOF
( cd "$T" && timeout -k 5 30 "$O" -bf fx.sno < /dev/null > ora 2>/dev/null ) || { echo "GATE UNPROVEN(2) [$GATE_NAME]: sbl -bf did not run the fixture"; exit 2; }
grep -qx 'eval 4 0.' "$T/ora" && grep -qx 'eval 7 FAILS' "$T/ora" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: sbl no longer reads 3.0E-324 as 0. or ...317 as an overflow -- the premise moved"; exit 2; }
( cd "$T" && timeout -k 5 30 "$ROOT/scrip" fx.sno < /dev/null > m3 2>m3.err ); r3=$?
cmp -s "$T/ora" "$T/m3" && arm "1 m3 == sbl ($(wc -l < "$T/ora") lines)" ok || arm 1 red "rc=$r3; $(diff "$T/ora" "$T/m3" | grep '^[<>]' | head -4 | tr '\n' ' ')"
( cd "$T" && timeout -k 5 60 "$ROOT/scrip" --compile fx.sno < /dev/null > fx.s 2>/dev/null && gcc -c fx.s -o fx.o 2>/dev/null && gcc fx.o -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o fx.bin 2>/dev/null ) \
  || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the m4 build of the fixture failed"; exit 2; }
( cd "$T" && timeout -k 5 30 ./fx.bin < /dev/null > m4 2>m4.err ); r4=$?
cmp -s "$T/ora" "$T/m4" && arm "2 m4 == sbl" ok || arm 2 red "rc=$r4; $(diff "$T/ora" "$T/m4" | grep '^[<>]' | head -4 | tr '\n' ' ')"
{ grep -qx 'eval 4 0.' "$T/m3" && grep -qx 'eval 6 0.179769313486232e+309' "$T/m3"; } && arm "3 EVAL('3.0E-324') is 0. and ...316 is finite (math_limits' witness)" ok || arm 3 red "$(grep -E '^eval (4|6) ' "$T/m3" | tr '\n' ' ')"
cat > "$T/ar.sno" <<'EOF'
	X = 1.0E-300
	Q = X / 1.0E10
	OUTPUT = 'quot ' Q
	OUTPUT = 'fold ' 1.0E-300 / 1.0E10
	S = '2.6308364999025777e-310' - 0.
	OUTPUT = 'coerce ' S
	OUTPUT = 'lt ' LT('1.0E-320', '1.0E-315') 'held'
	E = EVAL('2.6308364999025777e-310 - 1.5746769247801558e-310')
	D = E - '1.0561595751224219e-310'
	OUTPUT = 'md1 ' (LE(D, 1.0E-12 * '1.0561595751224219e-310') 'pass', 'FAIL')
	E = EVAL('-2.6308364999025777e-310 - -1.5746769247801558e-310')
	D = -(E - '-1.0561595751224219e-310')
	OUTPUT = 'md2 ' (LE(D, 1.0E-12 * '1.0561595751224219e-310') 'pass', 'FAIL')
	OUTPUT = 'big ' 1.0E300 * 10.0
	OUTPUT = 'norm ' 2.2250738585072014E-308 * 1.0
END
EOF
( cd "$T" && timeout -k 5 30 "$O" -bf ar.sno < /dev/null > aora 2>/dev/null ) || { echo "GATE UNPROVEN(2) [$GATE_NAME]: sbl -bf did not run the arithmetic fixture"; exit 2; }
grep -qx 'quot 0.' "$T/aora" && grep -qx 'md1 pass' "$T/aora" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: sbl no longer flushes a subnormal quotient or fails its own math_diff check -- the premise moved"; exit 2; }
( cd "$T" && timeout -k 5 30 "$ROOT/scrip" ar.sno < /dev/null > am3 2>am3.err ); r3=$?
cmp -s "$T/aora" "$T/am3" && arm "4 m3 arithmetic == sbl ($(wc -l < "$T/aora") lines: flushed quotient, folded quotient, DAZ on a coerced string, math_diff checks)" ok || arm 4 red "rc=$r3; $(diff "$T/aora" "$T/am3" | grep '^[<>]' | head -4 | tr '\n' ' ')"
( cd "$T" && timeout -k 5 60 "$ROOT/scrip" --compile ar.sno < /dev/null > ar.s 2>/dev/null && gcc -c ar.s -o ar.o 2>/dev/null && gcc ar.o -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o ar.bin 2>/dev/null ) \
  || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the m4 build of the arithmetic fixture failed"; exit 2; }
( cd "$T" && timeout -k 5 30 ./ar.bin < /dev/null > am4 2>am4.err ); r4=$?
cmp -s "$T/aora" "$T/am4" && arm "5 m4 arithmetic == sbl" ok || arm 5 red "rc=$r4; $(diff "$T/aora" "$T/am4" | grep '^[<>]' | head -4 | tr '\n' ' ')"
cat > "$T/sc.sc" <<'EOF'
x = 1.0E-300; q = x / 1.0E10; OUTPUT = 'quot ' q;
OUTPUT = 'lit ' 2.5E-310;
s = '2.6308364999025777e-310' - 0.; OUTPUT = 'coerce ' s;
EOF
"$ROOT/scrip" --transpile "$T/sc.sc" > "$T/sc.sno" 2>/dev/null || { echo "GATE UNPROVEN(2) [$GATE_NAME]: scrip --transpile refused the Snocone witness"; exit 2; }
( cd "$T" && timeout -k 5 30 "$O" -bf sc.sno < /dev/null > scora 2>/dev/null ) || { echo "GATE UNPROVEN(2) [$GATE_NAME]: sbl -bf did not run the transpiled Snocone witness"; exit 2; }
[ "$(wc -l < "$T/scora")" = 3 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the oracle's Snocone reading is not three lines"; exit 2; }
( cd "$T" && timeout -k 5 30 "$ROOT/scrip" sc.sc < /dev/null > scm3 2>/dev/null )
( cd "$T" && timeout -k 5 60 "$ROOT/scrip" --compile sc.sc < /dev/null > sc.s 2>/dev/null && gcc -c sc.s -o sc.o 2>/dev/null && gcc sc.o -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o sc.bin 2>/dev/null ) \
  || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the m4 build of the Snocone witness failed"; exit 2; }
( cd "$T" && timeout -k 5 30 ./sc.bin < /dev/null > scm4 2>/dev/null )
{ cmp -s "$T/scora" "$T/scm3" && cmp -s "$T/scora" "$T/scm4"; } && arm "6 Snocone m3+m4 == sbl on the transpiled form" ok || arm 6 red "m3: $(tr '\n' '|' < "$T/scm3") m4: $(tr '\n' '|' < "$T/scm4") sbl: $(tr '\n' '|' < "$T/scora")"
IT="$(icont_bin 2>/dev/null)"; IX="$(iconx_bin 2>/dev/null)"
[ -x "$IT" ] && [ -x "$IX" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no Icon oracle for the containment arm"; exit 2; }
printf 'procedure main()\n   write(1.0e-300 / 1.0e10);\nend\n' > "$T/c.icn"
( cd "$T" && "$IT" -s c.icn >/dev/null 2>&1 && timeout -k 5 30 "$IX" c > cora 2>/dev/null ) || { echo "GATE UNPROVEN(2) [$GATE_NAME]: iconx did not run the containment witness"; exit 2; }
grep -q 'e-310' "$T/cora" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: iconx no longer prints the subnormal quotient -- the containment premise moved"; exit 2; }
( cd "$T" && timeout -k 5 30 "$ROOT/scrip" c.icn < /dev/null > cm3 2>/dev/null )
cmp -s "$T/cora" "$T/cm3" && arm "7 containment: Icon's subnormal quotient is not flushed (== iconx: $(cat "$T/cora"))" ok || arm 7 red "iconx: $(cat "$T/cora") SCRIP m3: $(cat "$T/cm3")"
if [ "$red" = 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: $n arms"; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $red of $n arms red"; exit 1

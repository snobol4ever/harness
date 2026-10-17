#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the instrumentation switch (--stlimit): Icon &trace rides the call/return hooks that are off by default since SCRIP 2026-09-24 (Lon: monitor hooks behind the switch)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_subscript_index_is_checked_and_the_account_is_written.sh -- hq_U 2026-09-10, NONET row
# "the &error := -1 conversion class", under the cfo's errors row.
#
# WHAT IT PINS. Every integer-taking path of IR_SUBSCRIPT -- string, cset, list, SNOBOL4 array, and both
# section forms -- used to hand its index straight to to_int(), which turns "q" into 0 and answers. Three
# outcomes, all wrong, and they get worse from left to right: `"abcdef"[2:"q"]` SUCCEEDED with "bcdef";
# `"abcdef"["q"]` FAILED with no account, so &errornumber/&errortext/&errorvalue reported the LAST error that
# bothered to write one; and with no &error armed at all the program did not stop, where icont raises a fatal
# 101. The cure asks core_icn_int_operand_ok_d BEFORE converting, so the box CONCEDES on the ω edge and the
# account is written by the same call that decides the concede -- there is no path that fails silently.
#
# ⭐ WHY EVERY ROW RESETS THE ACCOUNT (errorclear(); &error := -1). &errornumber survives until the next
# converted error, so a row whose expression fails WITHOUT raising reads back the PREVIOUS row's number and
# scores as a pass. Cutting this want from icont without the reset produced a want in which rows 08, 10 and
# 11 "carried" 101 -- three false greens, and two of them are shapes where icont deliberately raises nothing.
# The reset is what makes n=- an observable, and n=- is the assertion in three of the twenty rows.
# ⛔ Rows 08/10/11 (a record field name that does not exist, and an out-of-range string or list index) are
# PLAIN FAILURES in Icon with NO error at all. A gate that raised 101 there would be as wrong as the defect.
#
# NOT CURED HERE, AND DELIBERATELY OUT OF THE WANT: `s[i+:n]` / `s[i-:n]` with a non-numeric bound. Its end is
# computed by an IR_BINOP the Icon lowerer synthesises WITHOUT the IR_COERCE_NUMERIC that every user-written
# binop gets, so rt_add coerces "q" to 0 and this box is handed a perfectly numeric 2. icont reports 102 from
# that addition. The cure is in src/lower/lower_icon.c -- the language HQ's lane -- and has its own row.
#
# SHARED NODE: IR_SUBSCRIPT is lowered by lower_icon.c (3 sites) and lower_snobol4.c (4). Every guard is
# behind core_icn_active(), and arm s1 is the control: SPITBOL array/table/DATA subscripting, a numeric-string
# subscript read AND written, a 2-D array and SUBSTR, all still byte-equal to `sbl -bf`.
#
# WANTS ARE CUT FROM THE ORACLES, NOT TYPED: r1/r2 from Arizona icont/iconx, s1 from `sbl -bf`.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
graded=0; fail=0
cat > "$T/r1.icn" <<'ICN'
record pt(x,y)
procedure main()
   local L, T, C, r;
   L := [10,20,30,40,50];
   T := table(); T["q"] := 7; T[3.5] := 8;
   C := 'abcdef';
   r := pt(1,2);
   errorclear(); &error := -1;
   write("01 str sub    ", image("abcdef"["q"]) | ("FAIL n=" || (&errornumber | "-") || " v=" || (image(&errorvalue) | "-")));
   errorclear(); &error := -1;
   write("02 str sub nul", image("abcdef"[&null]) | ("FAIL n=" || (&errornumber | "-") || " v=" || (image(&errorvalue) | "-")));
   errorclear(); &error := -1;
   write("03 lst sub    ", image(L["q"]) | ("FAIL n=" || (&errornumber | "-") || " v=" || (image(&errorvalue) | "-")));
   errorclear(); &error := -1;
   write("04 str sec hi ", image("abcdef"[2:"q"]) | ("FAIL n=" || (&errornumber | "-") || " v=" || (image(&errorvalue) | "-")));
   errorclear(); &error := -1;
   write("05 str sec lo ", image("abcdef"["q":3]) | ("FAIL n=" || (&errornumber | "-") || " v=" || (image(&errorvalue) | "-")));
   errorclear(); &error := -1;
   write("06 lst sec    ", image(L[2:"q"]) | ("FAIL n=" || (&errornumber | "-") || " v=" || (image(&errorvalue) | "-")));
   errorclear(); &error := -1;
   write("07 cset sub   ", image(C["q"]) | ("FAIL n=" || (&errornumber | "-") || " v=" || (image(&errorvalue) | "-")));
   errorclear(); &error := -1;
   write("08 rec bad nam", image(r["q"]) | ("FAIL n=" || (&errornumber | "-") || " v=" || (image(&errorvalue) | "-")));
   errorclear(); &error := -1;
   write("09 rec sub nul", image(r[&null]) | ("FAIL n=" || (&errornumber | "-") || " v=" || (image(&errorvalue) | "-")));
   errorclear(); &error := -1;
   write("10 str sub oob", image("abcdef"[9]) | ("FAIL n=" || (&errornumber | "-") || " v=" || (image(&errorvalue) | "-")));
   errorclear(); &error := -1;
   write("11 lst sub oob", image(L[9]) | ("FAIL n=" || (&errornumber | "-") || " v=" || (image(&errorvalue) | "-")));
   errorclear(); &error := -1;
   write("12 tbl key str", image(T["q"]) | ("FAIL n=" || (&errornumber | "-") || " v=" || (image(&errorvalue) | "-")));
   errorclear(); &error := -1;
   write("13 tbl key rel", image(T[3.5]) | ("FAIL n=" || (&errornumber | "-") || " v=" || (image(&errorvalue) | "-")));
   errorclear(); &error := -1;
   write("14 lst sec asg", image(L["q":2]) | ("FAIL n=" || (&errornumber | "-") || " v=" || (image(&errorvalue) | "-")));
   errorclear(); &error := -1;
   write("15 str ok     ", image("abcdef"[2]), image("abcdef"[-1]), image("abcdef"["3"]), image("abcdef"[2.0]));
   write("16 sec ok     ", image("abcdef"[2:4]), image("abcdef"[-2:0]), image("abcdef"["2":"4"]));
   write("17 lst ok     ", image(L[2]), image(L[-1]), image(L["3"]));
   write("18 lst sec ok ", image(L[2:4]));
   write("19 rec ok     ", image(r["x"]), image(r[1]), image(r[2]));
   write("20 acct clean ", (&errornumber | "none"));
end
ICN
cat > "$T/r1.want" <<'WANT'
01 str sub    FAIL n=101 v="q"
02 str sub nulFAIL n=101 v=&null
03 lst sub    FAIL n=101 v="q"
04 str sec hi FAIL n=101 v="q"
05 str sec lo FAIL n=101 v="q"
06 lst sec    FAIL n=101 v="q"
07 cset sub   FAIL n=101 v="q"
08 rec bad namFAIL n=- v=-
09 rec sub nulFAIL n=101 v=&null
10 str sub oobFAIL n=- v=-
11 lst sub oobFAIL n=- v=-
12 tbl key str7
13 tbl key rel8
14 lst sec asgFAIL n=101 v="q"
15 str ok     "b""f""c""b"
16 sec ok     "bc""ef""bc"
17 lst ok     205030
18 lst sec ok list_2(2)
19 rec ok     112
20 acct clean none
WANT
cat > "$T/r2.icn" <<'ICN'
procedure main()
   write(image("abcdef"[2:4]));
   write("about to fail");
   write(image("abcdef"["q"]));
   write("not reached");
end
ICN
cat > "$T/r2.want" <<'WANT'
"bc"
about to fail

Run-time error 101
File r2.icn; Line 4
integer expected or out of range
offending value: "q"
Traceback:
main()
{"abcdef"["q"]} from line 4 in r2.icn
WANT
icn_arm() {
  local n="$1" wantrc="$2"
  graded=$((graded + 1))
  ( cd "$T" && timeout -k 5 60 "$SCRIP" "$n.icn" </dev/null > "$n.m3" 2>&1 ); local rc3=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$n.m3" > "$T/$n.m3.r" && mv "$T/$n.m3.r" "$T/$n.m3"
  if [ "$rc3" = "$wantrc" ] && cmp -s "$T/$n.m3" "$T/$n.want"; then echo "  PASS  m3 $n"; else echo "  FAIL  m3 $n rc=$rc3 want rc=$wantrc"; diff "$T/$n.want" "$T/$n.m3" | head -10 | sed 's/^/        /'; fail=1; fi
  graded=$((graded + 1))
  if ( cd "$T" && "$SCRIP" --compile "$n.icn" > "$n.s" 2>/dev/null && gcc -c "$n.s" -o "$n.o" 2>/dev/null && gcc "$n.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$n.bin" 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 60 "./$n.bin" </dev/null > "$n.m4" 2>&1 ); local rc4=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$n.m4" > "$T/$n.m4.r" && mv "$T/$n.m4.r" "$T/$n.m4"
    if [ "$rc4" = "$wantrc" ] && cmp -s "$T/$n.m4" "$T/$n.want"; then echo "  PASS  m4 $n"; else echo "  FAIL  m4 $n rc=$rc4 want rc=$wantrc"; diff "$T/$n.want" "$T/$n.m4" | head -10 | sed 's/^/        /'; fail=1; fi
  else echo "  FAIL  m4 $n: no binary"; fail=1; fi
}
icn_arm r1 0
icn_arm r2 1
cat > "$T/s1.sno" <<'SNO'
	A = ARRAY(5)
	A[2] = 'two'
	OUTPUT = A[2]
	OUTPUT = A['3'] ':numeric-string-subscript-still-works'
	A['3'] = 'three'
	OUTPUT = A[3]
	T = TABLE()
	T['k'] = 'v'
	OUTPUT = T['k']
	DATA('PT(X,Y)')
	P = PT(1,2)
	OUTPUT = X(P) Y(P)
	B = ARRAY('1:3,1:3')
	B[2,2] = 'mid'
	OUTPUT = B[2,2]
	S = 'ABCDEF'
	OUTPUT = SUBSTR(S,2,3)
END
SNO
cat > "$T/s1.want" <<'WANT'
two
:numeric-string-subscript-still-works
three
v
12
mid
BCD
WANT
graded=$((graded + 1))
( cd "$T" && timeout -k 5 60 "$SCRIP" s1.sno </dev/null > s1.out 2>&1 )
if cmp -s "$T/s1.out" "$T/s1.want"; then echo "  PASS  snobol4 control arm: array/table/DATA subscripting is byte-equal to sbl -bf"; else echo "  FAIL  snobol4 control arm -- the Icon index check reached SNOBOL4"; diff "$T/s1.want" "$T/s1.out" | head -8 | sed 's/^/        /'; fail=1; fi
[ "$graded" -gt 0 ] || { echo "⛔ REFUSE(2): graded 0 witnesses"; exit 2; }
if [ "$fail" = 0 ]; then echo "✅ PASS: $graded/$graded arms -- a non-numeric subscript or section bound concedes, writes its own 101, and is fatal with no &error armed; a plain out-of-range index still raises nothing; SNOBOL4 subscripting untouched"; exit 0; fi
echo "⛔ FAIL: $graded arms graded -- see the FAIL rows: an index check went missing, wrote the wrong account, raised where Icon raises nothing, or reached SNOBOL4"; exit 1

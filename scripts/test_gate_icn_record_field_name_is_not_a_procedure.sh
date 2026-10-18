#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_record_field_name_is_not_a_procedure.sh -- hq_C 2026-09-10, NONET row icon-jcon-errors.
#
# WHAT IT PINS, AND WHY THE SNOBOL4 ARM IS NOT DECORATION. rt_builtin_is_known() answers YES for any live
# record FIELD name, and it is right to: SNOBOL4's DATA('PT(A,B)') really does mint A(X) and B(X) as callable
# field-accessor functions, and A(X) = 9 really does assign through one. ICON HAS NO SUCH FUNCTION -- a field
# is reached only as r.a -- so the same YES made every field name answer proc() as "function <name>", and a
# string in call position naming one (errors.icn line 38, `"a"(1,2,3)`, under `record array(a,b,c,d,e,f,g)`)
# was judged INVOCABLE by icn_call_value_name_invocable, fell through to the by-name dispatcher, and raised
# its 106 carrying NV_GET("a") -- &null -- where icont carries the string "a" that named the callee.
# ⭐ THE SHAPE TO REMEMBER: the offending value of a failed call is the CALLEE EXPRESSION'S OWN VALUE, so
# `t(t)` on an unassigned t correctly reports &null and `"a"(...)` must report "a". Both reach the dispatcher
# as a bare `const char *`, which cannot tell a variable's name from a string that IS the callee -- so the
# distinction has to survive further up, in whether proc() calls the name invocable at all.
# ⛔ A one-witness probe CANNOT see this: with no record declared in the file, `"a"(1,2,3)` is already right.
# The declaration is the ingredient, and it sits 37 lines away from the expression that goes wrong.
#
# WANTS ARE CUT FROM THE ORACLES, NOT TYPED: arm r1 from Arizona icont/iconx (lib_oracle_flags.sh paths),
# arm s1 from `sbl -bf`. Both arms of r1 (m3 and m4) must equal icont byte for byte.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/r1.icn" <<'ICN'
record array(a,b,c,d,e,f,g)
record pt(x,y)
procedure main()
   local r, q;
   &error := 200;
   write("01 proc a 3   ", image(proc("a",3)) | "fails");
   write("02 proc a 0   ", image(proc("a",0)) | "fails");
   write("03 proc a     ", image(proc("a")) | "fails");
   write("04 proc y 1   ", image(proc("y",1)) | "fails");
   write("05 proc zz 3  ", image(proc("zz",3)) | "fails");
   write("06 call a     ", image("a"(1,2,3)) | ("ERR " || &errornumber || " val=" || image(&errorvalue)));
   write("07 call zz    ", image("zz"(1,2,3)) | ("ERR " || &errornumber || " val=" || image(&errorvalue)));
   r := array(1,2,3,4,5,6,7); q := pt(8,9);
   write("08 fields     ", r.a, r.g, q.x, q.y);
   r.a := 99;
   write("09 assign     ", r.a);
   write("10 ctor       ", image(array), " ", image(array(1,2,3,4,5,6,7)));
   write("11 gen        ", image(!q));
end
ICN
cat > "$T/r1.want" <<'WANT'
01 proc a 3   fails
02 proc a 0   fails
03 proc a     fails
04 proc y 1   fails
05 proc zz 3  fails
06 call a     ERR 106 val="a"
07 call zz    ERR 106 val="zz"
08 fields     1789
09 assign     99
10 ctor       record constructor array record array_2(7)
11 gen        8
WANT
fail=0
( cd "$T" && timeout -k 5 60 "$SCRIP" r1.icn </dev/null > r1.m3 2>&1 ); rc3=$?
if [ "$rc3" = 0 ] && cmp -s "$T/r1.m3" "$T/r1.want"; then echo "  PASS  m3 r1"; else echo "  FAIL  m3 r1 rc=$rc3"; diff "$T/r1.want" "$T/r1.m3" | head -8 | sed 's/^/        /'; fail=1; fi
if ( cd "$T" && "$SCRIP" --compile r1.icn > r1.s 2>/dev/null && gcc -c r1.s -o r1.o 2>/dev/null && gcc r1.o -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o r1.bin 2>/dev/null ); then
  ( cd "$T" && timeout -k 5 60 ./r1.bin </dev/null > r1.m4 2>&1 ); rc4=$?
  if [ "$rc4" = 0 ] && cmp -s "$T/r1.m4" "$T/r1.want"; then echo "  PASS  m4 r1"; else echo "  FAIL  m4 r1 rc=$rc4"; diff "$T/r1.want" "$T/r1.m4" | head -8 | sed 's/^/        /'; fail=1; fi
else echo "  FAIL  m4 r1: no binary"; fail=1; fi
cat > "$T/s1.sno" <<'SNO'
	DATA('PT(A,B)')
	X = PT(3,4)
	OUTPUT = A(X)
	OUTPUT = B(X)
	A(X) = 9
	OUTPUT = A(X)
END
SNO
printf '3\n4\n9\n' > "$T/s1.want"
( cd "$T" && timeout -k 5 60 "$SCRIP" s1.sno </dev/null > s1.out 2>&1 )
if cmp -s "$T/s1.out" "$T/s1.want"; then echo "  PASS  snobol4 control arm: DATA field accessors are still callable and still assignable"; else echo "  FAIL  snobol4 control arm -- the Icon-side suppression reached SNOBOL4"; diff "$T/s1.want" "$T/s1.out" | head -6 | sed 's/^/        /'; fail=1; fi
if [ "$fail" = 0 ]; then echo "✅ PASS: an Icon record field name is not a procedure -- proc() refuses it, a string call on one raises 106 carrying the STRING, field access and the constructor are untouched, and SNOBOL4's DATA accessors still work"; exit 0; fi
echo "⛔ FAIL: see the FAIL rows -- a record field name answered proc(), or the suppression reached SNOBOL4's DATA accessors"; exit 1

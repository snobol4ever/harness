#!/usr/bin/env bash
# test_gate_sno_a_builtin_integer_argument_that_is_not_an_integer_is_the_spitbol_fatal_error.sh -- DUPL, SUBSTR, LPAD, RPAD and CHAR given an argument that is not an integer (and CHAR a code outside 0..255) raise the SPITBOL fatal error, both modes.
#
# # ⛔ THE DEFECT (the coo's telegram 2026-10-08 on SCRIP cfcfaf46d, witness  Y = DUPL("a", "b")  :S(A)F(B)): sbl -bf stops with  ERROR 090 -- dupl second argument is not integer ; SCRIP FAILED the statement silently (rc 0), and
#   for SUBSTR's third argument, LPAD, RPAD and CHAR it went further and SUCCEEDED, reading the text as 0. The class, measured against sbl one call at a time: DUPL 2nd arg 090, SUBSTR 2nd arg 193 and 3rd arg 192, LPAD 2nd arg 145,
#   RPAD 2nd arg 179, CHAR argument 281 (not integer) and 282 (outside 0..255). An argument that CONVERTS (integer, real, a numeric string, the null string) is no error in either engine and the controls hold it.
#   THE CURE: DUPL_fn, SUBSTR_fn, SUBSTR_bytes_fn, lpad_fn, rpad_fn and BCHAR_fn (string_builtins.c, the one body behind the registered builtins, the by-name road and the compiled call) test is_numeric_like and raise the error.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME): each program in m3 and in m4; every statement runs under SETEXIT, so a raised error prints its &ERRTYPE and the next statement runs
#   1-2  THE ERRORS: a literal and a variable non-integer argument to each of the five builtins, a NAME argument, CHAR below 0 and above 255 -- RED on the parent
#   3-4  CONTROLS: integer, real, numeric-string and null arguments, and the boundary CHAR(0) CHAR(255) -- they raise nothing in sbl and nothing here
#   5    A LITERAL non-integer to LPAD, RPAD or CHAR, or CHAR(256) / CHAR(-1), is a COMPILE-time error to sbl (the program never runs): SCRIP refuses non-zero and runs nothing
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_builtin_integer_argument_that_is_not_an_integer_is_the_spitbol_fatal_error
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
mkprog() { local out="$1" n=0 e; shift
    { cat <<'EOS'
        &ERRLIMIT = 1000
        SETEXIT('errh')
        v = 'b'; nm = .z; i = 3; r = 2.5; ns = '3'; nu = ''; big = 300; neg = -1
        k = 0
        :(go)
errh    SETEXIT('errh')
        OUTPUT = k ' ERROR ' &ERRTYPE                           :(CONTINUE)
go
EOS
      while IFS= read -r e; do n=$((n + 1))
          printf "        k = %d\n        y = %s                                   :S(s%d)F(f%d)\ns%d     OUTPUT = k ' SUCCESS ' y                      :(n%d)\nf%d     OUTPUT = k ' FAIL'\nn%d\n" "$n" "$e" "$n" "$n" "$n" "$n" "$n" "$n"
      done
      printf "END\n"; } > "$out"; }
cat > "$T/err.txt" <<'EOS'
DUPL('a', 'b')
DUPL('a', v)
DUPL('a', nm)
SUBSTR('abc', 'x', 1)
SUBSTR('abc', v, 1)
SUBSTR('abc', 1, 'x')
SUBSTR('abc', 1, v)
SUBSTR('abc', nm, 1)
LPAD('a', v)
LPAD('a', nm)
RPAD('a', v)
RPAD('a', nm)
CHAR(v)
CHAR(nm)
CHAR(neg)
CHAR(big)
EOS
cat > "$T/ctl.txt" <<'EOS'
DUPL('a', 3)
DUPL('a', i)
DUPL('a', ns)
DUPL('a', ' 3')
DUPL('a', r)
DUPL('a', nu)
DUPL('a', -1)
SUBSTR('abc', 2, 1)
SUBSTR('abc', ns, i)
SUBSTR('abc', nu, 1)
SUBSTR('abc', 1, nu)
SUBSTR('abc', r, 1)
LPAD('a', 3)
LPAD('a', ns)
LPAD('a', nu)
LPAD('a', r)
RPAD('a', 3)
RPAD('a', ns)
RPAD('a', nu)
RPAD('a', r)
CHAR(65)
CHAR(ns)
CHAR(nu)
CHAR(0)
CHAR(255)
CHAR(r)
EOS
mkprog "$T/err.sno" < "$T/err.txt"
mkprog "$T/ctl.sno" < "$T/ctl.txt"
want() { timeout -k 5 30 "$SBL" -bf "$T/$1.sno" < /dev/null > "$T/$1.want" 2>/dev/null; [ -s "$T/$1.want" ] || refuse "sbl -bf produced no output for $1 -- the oracle's answer moved"; }
want err; want ctl
grep -q "^1 ERROR 90\$" "$T/err.want" || refuse "sbl -bf no longer answers DUPL(a,b) with ERROR 90 -- the oracle answer moved: $(head -3 "$T/err.want" | tr "\n" "|")"
grep -q ' ERROR ' "$T/ctl.want" && refuse "sbl -bf now raises an error on a control argument -- the controls moved"
fail=0; pass=0
arm() { local n="$1" what="$2" ok="$3"
    if [ "$ok" = 1 ]; then pass=$((pass + 1)); echo "  arm $n PASS  $what"; else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; fi; }
same_m3() { timeout -k 5 60 "$SCRIP" -d131072k -s4096k "$T/$1.sno" < /dev/null > "$T/$1.m3" 2>&1
    cmp -s "$T/$1.want" "$T/$1.m3" || { diff "$T/$1.want" "$T/$1.m3" | head -8 | cut -c1-160 | sed 's/^/      /'; return 1; }; }
same_m4() { timeout -k 5 120 "$SCRIP" --compile -o "$T/$1.s" "$T/$1.sno" < /dev/null > /dev/null 2>&1 \
        && gcc -no-pie "$T/$1.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/$1.bin" 2>/dev/null || { echo "      COMPILE-FAILED"; return 1; }
    timeout -k 5 60 "$T/$1.bin" -d131072k -s4096k -- < /dev/null > "$T/$1.m4" 2>&1
    cmp -s "$T/$1.want" "$T/$1.m4" || { diff "$T/$1.want" "$T/$1.m4" | head -8 | cut -c1-160 | sed 's/^/      /'; return 1; }; }
n=0
for spec in "err|THE ERRORS: DUPL SUBSTR LPAD RPAD CHAR given a non-integer, a NAME, a code outside 0..255" "ctl|CONTROLS: integer, real, numeric-string and null arguments, CHAR(0) CHAR(255)"; do
    p="${spec%%|*}"; w="${spec#*|}"
    n=$((n + 1)); same_m3 "$p" && arm $n "m3 $w" 1 || arm $n "m3 $w" 0
    n=$((n + 1)); same_m4 "$p" && arm $n "m4 $w" 1 || arm $n "m4 $w" 0
done
n=$((n + 1)); ok=1
while IFS= read -r e; do
    printf "        OUTPUT = 'ran'\n        y = %s\n        OUTPUT = 'ran after'\nEND\n" "$e" > "$T/lit.sno"
    (cd "$T" && timeout -k 5 30 "$SBL" -bf -o=lit.lst lit.sno < /dev/null 2>&1 | grep -q 'ERROR') || refuse "sbl -bf no longer refuses  $e  at compile time -- the oracle's answer moved"
    (cd "$T" && timeout -k 5 30 "$SBL" -bf -o=lit.lst lit.sno < /dev/null 2>&1 | grep -q '^ran') && refuse "sbl -bf now runs the program with  $e  -- the oracle's answer moved"
    out="$(timeout -k 5 30 "$SCRIP" "$T/lit.sno" < /dev/null 2>&1)"; rc=$?
    { [ "$rc" -ne 0 ] && ! printf '%s' "$out" | grep -q '^ran'; } || { ok=0; echo "      $e: rc=$rc out=$(printf '%s' "$out" | head -2 | tr '\n' ' ' | cut -c1-100)"; }
done <<'EOS'
LPAD('a', 'x')
RPAD('a', 'x')
CHAR('x')
CHAR(256)
CHAR(-1)
EOS
arm $n "a literal non-integer to LPAD RPAD CHAR, and a literal CHAR code outside 0..255, is refused at compile (sbl: compile-time ERROR), nothing runs" "$ok"
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- a non-integer integer argument of DUPL SUBSTR LPAD RPAD CHAR is the SPITBOL fatal error, both modes"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1

#!/usr/bin/env bash
# test_gate_sno_a_define_used_as_a_value_rebinds_the_function_as_a_statement_define_does.sh -- a DEFINE that is part of an expression
# (t = DEFINE('f(y)','f2'), IDENT(DEFINE(...)), SIZE(DEFINE(...))) rebinds the function's entry label and prototype when it executes,
# exactly as the same DEFINE written as a whole statement does and as SPITBOL answers it, in both modes.
#
# ⛔ THE DEFECT (row snobol4-eight-run-time-errors-diag1-expects-are-not-raised; csnobol4_suite/diag1, the fourth cause behind its drift in
#   &STCOUNT). Three gaps in lower_snobol4.c, one mechanism -- SCRIP knew only the DEFINEs that stand alone as a statement:
#   (a) the pre-scan that records prototypes walked each statement's SUBJECT, never its replacement field, so a DEFINE in
#       'test = DIFFER(DEFINE(...)) stars' or 't = DEFINE(...)' was not seen as another prototype of an already-defined function;
#   (b) the expression lowering then took it for "already defined" and replaced it with the null string -- a silent no-op, so calls kept
#       running the first definition's body (diag1 ran the 9-statement fact, sbl the 6-statement fact3 it had redefined);
#   (c) the entry labels of expression DEFINEs were not registered as entry points, so a rebind to one could not resolve (mode 4 raised
#       error 22).
#   THE CURE: the pre-scan also walks the replacement field for DEFINEs and registers their prototype AND entry label; the expression
#   lowering of a literal-prototype DEFINE with an entry emits the same IR_DEFINE bind (entry + prototype) the statement path emits, then
#   the null value.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4: one function redefined three times through t = DEFINE(...), IDENT(DEFINE(...)), SIZE(DEFINE(...)) and DEFINE with no entry,
#        the redefinitions changing the formals and the locals                                                             -- RED on base
#   3-4  CONTROL m3 / m4: the same redefinitions written as whole statements, and a function defined once                      -- already green
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_define_used_as_a_value_rebinds_the_function_as_a_statement_define_does
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/rd.sno" <<'EOF'
        DEFINE('f(x)')                          :(go1)
f       f = 'orig ' x                           :(RETURN)
go1     OUTPUT = f(1)
        T = DEFINE('f(y)','f2')                 :(go2)
f2      f = 'redef ' y                          :(RETURN)
go2     OUTPUT = f(2)
        OUTPUT = IDENT(DEFINE('f(z)w','f3')) 'nested'
        :(go3)
f3      w = z ; f = 'third ' w                  :(RETURN)
go3     OUTPUT = f(3)
        OUTPUT = SIZE(DEFINE('f(x)')) ' size'
        OUTPUT = f(4)
        T = DEFINE('f(y)','f2')
        OUTPUT = f(5)
        DEFINE('f(x)','f')
        OUTPUT = f(6)
END
EOF
cat > "$T/ct.sno" <<'EOF'
        DEFINE('g(x)')                          :(go1)
g       g = 'orig ' x                           :(RETURN)
go1     OUTPUT = g(1)
        DEFINE('g(y)','g2')                     :(go2)
g2      g = 'redef ' y                          :(RETURN)
go2     OUTPUT = g(2)
        DEFINE('g(x)','g')
        OUTPUT = g(3)
        DEFINE('h(n)')                          :(hend)
h       h = EQ(n,1) 1                           :S(RETURN)
        h = n * h(n - 1)                        :(RETURN)
hend    OUTPUT = h(5)
END
EOF
want() { timeout -k 5 30 "$SBL" -bf "$T/$1.sno" < /dev/null > "$T/$1.want" 2>/dev/null; [ -s "$T/$1.want" ] || refuse "sbl -bf produced no output for $1 -- the oracle's answer moved"; }
want rd; want ct
[ "$(sed -n 2p "$T/rd.want")" = "redef 2" ] || refuse "sbl -bf no longer rebinds a function through an expression DEFINE as cut (line 2: $(sed -n 2p "$T/rd.want"))"
fail=0; pass=0
arm() { local n="$1" what="$2" got="$3" w="$4"
    if cmp -s "$w" "$got"; then pass=$((pass + 1)); echo "  arm $n PASS  $what"
    else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; diff "$w" "$got" | head -8 | sed 's/^/      /'; fi; }
m3() { timeout -k 5 30 "$SCRIP" "$T/$1.sno" < /dev/null > "$T/$1.m3" 2>/dev/null; }
m4() { : > "$T/$1.m4"
       if timeout -k 5 120 "$SCRIP" --compile -o "$T/$1.s" "$T/$1.sno" < /dev/null > /dev/null 2>&1 \
          && gcc -no-pie "$T/$1.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/$1.bin" 2>/dev/null
       then timeout -k 5 30 "$T/$1.bin" < /dev/null > "$T/$1.m4" 2>/dev/null; else echo COMPILE-FAILED > "$T/$1.m4"; fi; }
m3 rd; arm 1 "m3: a DEFINE used as a value rebinds entry and prototype" "$T/rd.m3" "$T/rd.want"
m4 rd; arm 2 "m4: the same" "$T/rd.m4" "$T/rd.want"
m3 ct; arm 3 "CONTROL m3: whole-statement redefinitions and a function defined once" "$T/ct.m3" "$T/ct.want"
m4 ct; arm 4 "CONTROL m4: the same" "$T/ct.m4" "$T/ct.want"
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- a DEFINE used as a value rebinds the function, both modes"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1

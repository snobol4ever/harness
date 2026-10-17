#!/usr/bin/env bash
# test_gate_sno_convert_takes_its_datatype_name_exactly_as_spitbol_does.sh -- CONVERT's second argument is a datatype name, and under
# sbl -bf (SNOBOL4 is case-sensitive, RULES.md ABSOLUTE RULES) a lower-case or mixed-case name is no datatype name: CONVERT('1', 'integer')
# FAILS, CONVERT('1', 'INTEGER') converts, in both modes, statically (a literal and a variable holding the name) and inside EVAL alike,
# as SPITBOL answers it.
#
# ⛔ THE DEFECT (row snobol4-convert-folds-a-lower-case-datatype-name-where-spitbol-fails-it; found by the cfo on the arity row 0edc85c92,
#   measured and rowed by the ceo). Two dispatch sites upper-cased the type name before comparing it to INTEGER, REAL and STRING:
#   bn_convert and the inline BID_CONVERT arm, both in src/runtime/by_name_dispatch.c. The core _CONVERT_ beside them already compared
#   exactly, so the answer depended on which road a call took, and 'integer' converted on both. SCRIP's other datatype-name inputs are
#   not folded: DATATYPE only returns names, and ARRAY, TABLE and PATTERN reach _CONVERT_'s strcmp.
# THE CURE (src/runtime/by_name_dispatch.c): both sites compare the name as written.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4 STATIC: 'integer', 'real', 'string', 'Integer' and a variable holding 'integer' fail; upper case converts  -- RED on base
#   3-4  m3 / m4 EVAL: the same, EVALed                                                                                   -- RED on base
#   5-6  CONTROL m3 / m4: shapes base already answers -- upper-case INTEGER, REAL, STRING; ARRAY, TABLE and PATTERN conversions;
#        CONVERT of an unconvertible value; a non-string type name (error 074, trapped)
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_convert_takes_its_datatype_name_exactly_as_spitbol_does
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/st.sno" <<'EOF'
        OUTPUT = 'integer: ' CONVERT('1', 'integer')                     :S(A) F(Fa)
Fa      OUTPUT = 'integer: fails'
A       OUTPUT = 'real: ' CONVERT('1', 'real')                          :S(B) F(Fb)
Fb      OUTPUT = 'real: fails'
B       OUTPUT = 'string: ' CONVERT(1, 'string')                        :S(C) F(Fc)
Fc      OUTPUT = 'string: fails'
C       OUTPUT = 'Integer: ' CONVERT('1', 'Integer')                    :S(D) F(Fd)
Fd      OUTPUT = 'Integer: fails'
D       t = 'integer'
        OUTPUT = 'variable: ' CONVERT('1', t)                           :S(E) F(Fe)
Fe      OUTPUT = 'variable: fails'
E       OUTPUT = 'INTEGER: ' CONVERT('1', 'INTEGER')                    :S(F) F(Ff)
Ff      OUTPUT = 'INTEGER: fails'
F       OUTPUT = 'REAL: ' CONVERT('1', 'REAL')                          :S(G) F(Fg)
Fg      OUTPUT = 'REAL: fails'
G       OUTPUT = 'STRING: ' DATATYPE(CONVERT(1, 'STRING'))              :S(END) F(Fh)
Fh      OUTPUT = 'STRING: fails'
END
EOF
cat > "$T/ct.sno" <<'EOF'
        OUTPUT = 'upper integer: ' CONVERT('12', 'INTEGER')
        OUTPUT = 'upper real: ' CONVERT('12', 'REAL')
        OUTPUT = 'upper string: ' DATATYPE(CONVERT(12, 'STRING'))
        a = ARRAY(2, 'x')
        OUTPUT = 'array: ' DATATYPE(CONVERT(a, 'ARRAY'))
        tb = TABLE()
        tb['k'] = 'v'
        OUTPUT = 'table to array: ' DATATYPE(CONVERT(tb, 'ARRAY'))
        OUTPUT = 'pattern: ' DATATYPE(CONVERT('abc', 'PATTERN'))
        OUTPUT = 'unconvertible: ' CONVERT('abc', 'INTEGER')            :S(END) F(Fu)
Fu      OUTPUT = 'unconvertible: fails'
END
EOF
cat > "$T/ev.sno" <<'EOF'
        &TRIM = 1
loop    line = INPUT                                    :F(END)
        r = EVAL(line)                                  :S(ok)
        OUTPUT = 'FAIL'                                 :(loop)
ok      OUTPUT = DATATYPE(r) ' [' r ']'                 :(loop)
END
EOF
cat > "$T/ev.in" <<'EOF'
CONVERT('1', 'integer')
CONVERT('1', 'INTEGER')
CONVERT('1', 'string')
CONVERT('1', 'STRING')
CONVERT('1.5', 'real')
CONVERT('1.5', 'REAL')
CONVERT('1', 'Integer')
EOF
want() { timeout -k 5 30 "$SBL" -bf "$T/$1.sno" < "$2" > "$T/$1.want" 2>/dev/null; [ -s "$T/$1.want" ] || refuse "sbl -bf produced no output for $1 -- the oracle's answer moved"; }
want st /dev/null; want ct /dev/null; want ev "$T/ev.in"
grep -q '^integer: fails$' "$T/st.want" && grep -q '^INTEGER: 1$' "$T/st.want" || refuse "sbl -bf no longer fails a lower-case datatype name"
fail=0; pass=0
arm() { local n="$1" what="$2" got="$3" w="$4"
    if cmp -s "$w" "$got"; then pass=$((pass + 1)); echo "  arm $n PASS  $what"
    else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; diff "$w" "$got" | head -8 | sed 's/^/      /'; fi; }
m3() { timeout -k 5 30 "$SCRIP" "$T/$1.sno" < "$2" > "$T/$1.m3" 2>/dev/null; }
m4() { : > "$T/$1.m4"
       if timeout -k 5 120 "$SCRIP" --compile -o "$T/$1.s" "$T/$1.sno" < /dev/null > /dev/null 2>&1 \
          && gcc -no-pie "$T/$1.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/$1.bin" 2>/dev/null
       then timeout -k 5 30 "$T/$1.bin" < "$2" > "$T/$1.m4" 2>/dev/null; else echo COMPILE-FAILED > "$T/$1.m4"; fi; }
m3 st /dev/null; arm 1 "m3 static: a lower or mixed-case datatype name fails, upper case converts" "$T/st.m3" "$T/st.want"
m4 st /dev/null; arm 2 "m4 static: the same" "$T/st.m4" "$T/st.want"
m3 ev "$T/ev.in"; arm 3 "m3 EVAL: the same, EVALed" "$T/ev.m3" "$T/ev.want"
m4 ev "$T/ev.in"; arm 4 "m4 EVAL: the same" "$T/ev.m4" "$T/ev.want"
m3 ct /dev/null; arm 5 "CONTROL m3: upper-case INTEGER/REAL/STRING, ARRAY, TABLE, PATTERN, an unconvertible value" "$T/ct.m3" "$T/ct.want"
m4 ct /dev/null; arm 6 "CONTROL m4: the same" "$T/ct.m4" "$T/ct.want"
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- CONVERT takes its datatype name exactly as written, both modes, static and EVAL"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1

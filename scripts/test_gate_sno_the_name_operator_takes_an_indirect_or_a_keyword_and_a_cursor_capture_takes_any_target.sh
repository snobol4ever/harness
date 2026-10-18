#!/usr/bin/env bash
# test_gate_sno_the_name_operator_takes_an_indirect_or_a_keyword_and_a_cursor_capture_takes_any_target.sh -- the name operator takes an indirect reference (n = .$x) and a keyword (k = .&ANCHOR, a NAME whose store reaches the
# keyword), and the cursor capture @T and the conditional/immediate captures take a deferred target (@*V, @*$('CUR' N)) and a keyword target
# ($ &STLIMIT, . &STLIMIT), in both modes, as SPITBOL answers them.
#
# THE DEFECT (rows snobol4-the-name-operator-over-an-indirect-variable-is-refused-by-the-lowerer, ceo CEO-1486, Lon: "So 'a' . $x must work so that
#   is a bug"; and Flake indirect-integer-and-keyword + pattern-assignment-targets): the lowerer refused .$x and .&KW with FATAL "name operator
#   over this form is outside the landed subset", and @ with a target that was not a plain variable ("@ cursor-position capture target is not a
#   simple variable"); a keyword capture target was refused too. A NAME of a keyword stored into a variable named "&ANCHOR" and never reached
#   the keyword.
# THE CURE: TT_NAME lowers .$x to the value of x (a NAME) and .&KW to a NAME "&KW"; NV_SET_fn / NV_GET_fn route a name beginning with '&&' (the keyword NAME's spelling; a string $('&ANCHOR') is the plain variable of that name, as sbl -bf has it) that
#   is a SNOBOL4 keyword to the keyword table; sno_cursor_target resolves an @ target as the captures do (a variable, '*' + a registered
#   expression for a deferred one) and rt_at_cursor evaluates the '*' expression by name; sno_capt_name names a keyword target.
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4 the combined program: .$x, .$'b', .&STLIMIT, $K = 777, .&ANCHOR, @*V, @*$('CUR' N), $ &STLIMIT, . &STLIMIT, a deferred @ in a stored pattern
#   3-4  CONTROL m3 / m4: .x, an array element name, @C, . D, $ E -- shapes base already answers
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_the_name_operator_takes_an_indirect_or_a_keyword_and_a_cursor_capture_takes_any_target
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/st.sno" <<'EOF'
        x = 'a'
        n = .$x
        OUTPUT = DATATYPE(n)
        $n = 5
        OUTPUT = a
        m = .$'b'
        $m = 'bee'
        OUTPUT = b
        K = .&STLIMIT
        OUTPUT = DATATYPE(K)
        $K = 777
        OUTPUT = &STLIMIT
        OUTPUT = $K
        K = .&ANCHOR
        $K = 1
        OUTPUT = &ANCHOR
        &ANCHOR = 0
        V = .P
        'ABCDE' ('BC' @*V)              :S(YES)F(NO)
YES     OUTPUT = 'P=' P ' V=' V         :(T)
NO      OUTPUT = 'NOMATCH'
T       N = 2
        'ABCDE' 'CD' @*$('CUR' N)
        OUTPUT = 'CUR2=' CUR2
        '12345' LEN(3) $ &STLIMIT
        OUTPUT = &STLIMIT
        '54321' LEN(2) . &STLIMIT
        OUTPUT = &STLIMIT
        p = 'AB' @*Q
        'XABY' p
        OUTPUT = 'Q=' Q
END
EOF
cat > "$T/ct.sno" <<'EOF'
        x = 'a'
        y = .x
        OUTPUT = DATATYPE(y)
        $y = 'set'
        OUTPUT = a
        A = ARRAY(2)
        z = .A[1]
        $z = 'el'
        OUTPUT = A[1]
        'ABCDE' ('BC' @C)
        OUTPUT = C
        'hello' LEN(2) . D
        OUTPUT = D
        'hello' LEN(3) $ E
        OUTPUT = E
        &ANCHOR = 1
        $('&ANCHOR') = 'HELLO'
        OUTPUT = $('&ANCHOR') &ANCHOR
END
EOF
want() { timeout -k 5 30 "$SBL" -bf "$T/$1.sno" < /dev/null > "$T/$1.want" 2>/dev/null; [ -s "$T/$1.want" ] || refuse "sbl -bf produced no output for $1 -- the oracle's answer moved"; }
want st; want ct
head -1 "$T/st.want" | grep -q '^NAME$' && grep -q '^CUR2=4$' "$T/st.want" || refuse "sbl -bf no longer answers the program as cut (first line: $(head -1 "$T/st.want"))"
fail=0; pass=0
arm() { local n="$1" what="$2" got="$3" w="$4"
    if cmp -s "$w" "$got"; then pass=$((pass + 1)); echo "  arm $n PASS  $what"
    else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; diff "$w" "$got" | head -8 | sed 's/^/      /'; fi; }
m3() { timeout -k 5 30 "$SCRIP" "$T/$1.sno" < /dev/null > "$T/$1.m3" 2>/dev/null; }
m4() { : > "$T/$1.m4"
       if timeout -k 5 120 "$SCRIP" --compile -o "$T/$1.s" "$T/$1.sno" < /dev/null > /dev/null 2>&1 \
          && gcc -no-pie "$T/$1.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/$1.bin" 2>/dev/null
       then timeout -k 5 30 "$T/$1.bin" < /dev/null > "$T/$1.m4" 2>/dev/null; else echo COMPILE-FAILED > "$T/$1.m4"; fi; }
m3 st; arm 1 "m3: .\$x, .&KW stores, @*V, @*\$('CUR' N), keyword capture targets answer as sbl -bf does" "$T/st.m3" "$T/st.want"
m4 st; arm 2 "m4: the same" "$T/st.m4" "$T/st.want"
m3 ct; arm 3 "CONTROL m3: .x, an array element name, @C, . D, \$ E, a string \$('&ANCHOR') stays the plain variable" "$T/ct.m3" "$T/ct.want"
m4 ct; arm 4 "CONTROL m4: the same" "$T/ct.m4" "$T/ct.want"
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- the name operator takes .\$x and .&KW, the cursor and value captures take deferred and keyword targets, both modes"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1

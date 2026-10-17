#!/usr/bin/env bash
# test_gate_sno_a_bare_fence_as_an_alternation_arm_matches_null_and_seals_its_backtrack.sh -- a bare FENCE reached as an arm of an
# alternation matches the null string, and backtracking into it fails the WHOLE match (no later arm, no later start position), in both
# modes, statically compiled and inside EVAL alike, as SPITBOL answers it.
#
# ⛔ THE DEFECT (row snobol4-a-bare-fence-as-an-alternation-arm-recurses-until-the-stack-overflows, found by Lon's infinite_snobol4 at
#   expression 189 'z' ? ANY('xyz') POS(3) | FENCE). sno_pat_node lowered a bare FENCE (TT_FENCE, no argument) to NO node -- it returned
#   its own continuation. TT_ALT lowers each arm with the alternation box itself as that continuation, so the FENCE arm's entry WAS the
#   alternation (--dump-ir: MATCH_ALTERNATE [29,29,6,6] at slot 6): taking the arm re-entered the alternation, which re-tried every arm
#   at the same cursor, forever -- ERROR 246 (stack overflow) in both modes. sbl -bf matches the null string. A bare FENCE inside a
#   sequence (TT_SEQ builds its own IR_MATCH_FENCE0) and a whole-pattern FENCE never reached that return, so they always agreed.
# THE CURE: a bare FENCE reached as a standalone pattern node builds the IR_MATCH_FENCE0 (SNO_FENCE_LIT_BARE) box the sequence path
#   builds, its omega on the enclosing pat_seal as ABORT's is.
# MONITOR BRACKET (the row's witness, monitor_run.sh --oracle): step 1 agrees; step 2 spl reaches LABEL stno=2, scr has died inside
#   statement 1's match (ERROR 246). After the cure AGREE=6 DIVERGE=0 UNGRADED=0.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4 STATIC: the diverging shapes -- FENCE as the last, middle and only-matching arm, an arm whose backtrack must seal the
#        match, the generator's expression 189                                                                 -- RED on base
#   3-4  m3 / m4 EVAL: the same shapes, one per line, EVALed                                                    -- RED on base
#   5-6  CONTROL m3 / m4: shapes base already answers -- a whole-pattern FENCE, FENCE in a sequence, FENCE('') / ARB / ABORT / FLUSH
#        as the arm
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_bare_fence_as_an_alternation_arm_matches_null_and_seals_its_backtrack
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/st.sno" <<'EOF'
        'z' ? 'q' | FENCE                       :S(Y1)F(N1)
Y1      OUTPUT = 'last arm: yes'                :(T2)
N1      OUTPUT = 'last arm: no'
T2      'z' ? ('q' | FENCE) 'z'                 :S(Y2)F(N2)
Y2      OUTPUT = 'arm then z: yes'              :(T3)
N2      OUTPUT = 'arm then z: no'
T3      'ab' ? ('x' | FENCE | 'a') 'a'          :S(Y3)F(N3)
Y3      OUTPUT = 'middle arm: yes'              :(T4)
N3      OUTPUT = 'middle arm: no'
T4      'yz' ? ('q' | FENCE) 'z'                :S(Y4)F(N4)
Y4      OUTPUT = 'sealed backtrack: yes'        :(T5)
N4      OUTPUT = 'sealed backtrack: no'
T5      'ab' ? ('x' | FENCE | 'a') 'b'          :S(Y5)F(N5)
Y5      OUTPUT = 'sealed before a later arm: yes' :(T6)
N5      OUTPUT = 'sealed before a later arm: no'
T6      'z' ? ANY('xyz') POS(3) | FENCE         :S(Y6)F(N6)
Y6      OUTPUT = 'expression 189: yes'          :(T7)
N6      OUTPUT = 'expression 189: no'
T7      'abc' ? ('q' | FENCE) . X LEN(1) 'b'    :S(Y7)F(N7)
Y7      OUTPUT = 'captured arm: [' X ']'        :(END)
N7      OUTPUT = 'captured arm: no'
END
EOF
cat > "$T/ct.sno" <<'EOF'
        'z' ? FENCE                             :S(Y1)F(N1)
Y1      OUTPUT = 'whole fence: yes'             :(T2)
N1      OUTPUT = 'whole fence: no'
T2      'yz' ? 'q' FENCE | 'y'                  :S(Y2)F(N2)
Y2      OUTPUT = 'fence in a sequence: yes'     :(T3)
N2      OUTPUT = 'fence in a sequence: no'
T3      'z' ? 'q' | FENCE('')                   :S(Y3)F(N3)
Y3      OUTPUT = 'fence of null arm: yes'       :(T4)
N3      OUTPUT = 'fence of null arm: no'
T4      'z' ? 'q' | ARB                         :S(Y4)F(N4)
Y4      OUTPUT = 'arb arm: yes'                 :(T5)
N4      OUTPUT = 'arb arm: no'
T5      'z' ? 'q' | ABORT                       :S(Y5)F(N5)
Y5      OUTPUT = 'abort arm: yes'               :(T6)
N5      OUTPUT = 'abort arm: no'
T6      'z' ? ('q' | FLUSH) 'z'                 :S(Y6)F(N6)
Y6      OUTPUT = 'flush arm: yes'               :(END)
N6      OUTPUT = 'flush arm: no'
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
'z' ? 'q' | FENCE
'z' ? ('q' | FENCE) 'z'
'ab' ? ('x' | FENCE | 'a') 'a'
'yz' ? ('q' | FENCE) 'z'
'ab' ? ('x' | FENCE | 'a') 'b'
'z' ? ANY('xyz') POS(3) | FENCE
'z' ? ('q' | FENCE) | 'z'
'z' ? ARBNO('q' | FENCE) 'z'
EOF
want() { timeout -k 5 30 "$SBL" -bf "$T/$1.sno" < "$2" > "$T/$1.want" 2>/dev/null; [ -s "$T/$1.want" ] || refuse "sbl -bf produced no output for $1 -- the oracle's answer moved"; }
want st /dev/null; want ct /dev/null; want ev "$T/ev.in"
grep -q '^last arm: yes$' "$T/st.want" && grep -q '^sealed backtrack: no$' "$T/st.want" || refuse "sbl -bf no longer answers the static witness as cut (last arm: yes, sealed backtrack: no)"
fail=0; pass=0
arm() { local n="$1" what="$2" got="$3" w="$4"
    if cmp -s "$w" "$got"; then pass=$((pass + 1)); echo "  arm $n PASS  $what"
    else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; diff "$w" "$got" | head -8 | sed 's/^/      /'; fi; }
m3() { timeout -k 5 30 "$SCRIP" "$T/$1.sno" < "$2" > "$T/$1.m3" 2>/dev/null; }
m4() { rm -f "$T/$1.bin"; : > "$T/$1.m4"
       if timeout -k 5 120 "$SCRIP" --compile -o "$T/$1.s" "$T/$1.sno" < /dev/null > /dev/null 2>&1 \
          && gcc -no-pie "$T/$1.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/$1.bin" 2>/dev/null
       then timeout -k 5 30 "$T/$1.bin" < "$2" > "$T/$1.m4" 2>/dev/null; else echo COMPILE-FAILED > "$T/$1.m4"; fi; }
m3 st /dev/null; arm 1 "m3 static: a bare FENCE arm matches null and seals its backtrack" "$T/st.m3" "$T/st.want"
m4 st /dev/null; arm 2 "m4 static: the same" "$T/st.m4" "$T/st.want"
m3 ev "$T/ev.in"; arm 3 "m3 EVAL: the same shapes, EVALed" "$T/ev.m3" "$T/ev.want"
m4 ev "$T/ev.in"; arm 4 "m4 EVAL: the same" "$T/ev.m4" "$T/ev.want"
m3 ct /dev/null; arm 5 "CONTROL m3: whole-pattern FENCE, FENCE in a sequence, FENCE('')/ARB/ABORT/FLUSH arms" "$T/ct.m3" "$T/ct.want"
m4 ct /dev/null; arm 6 "CONTROL m4: the same" "$T/ct.m4" "$T/ct.want"
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- a bare FENCE as an alternation arm matches null and seals its backtrack, both modes, static and EVAL"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1

#!/usr/bin/env bash
# test_gate_sno_an_abort_inside_a_pattern_thunk_fails_the_match_without_a_crash.sh -- ABORT reached inside a pattern thunk (a deferred
# *ABORT, *((ABORT)), a stored p = ABORT or p = LEN(1) ABORT matched directly or through *p, the run-time-built pattern of EVAL) fails
# the whole match, in both modes, statically and inside EVAL alike, as SPITBOL answers it -- no SIGSEGV.
#
# ⛔ THE DEFECT (row snobol4-a-deferred-abort-in-a-pattern-crashes-scrip-where-spitbol-fails-the-match; found by the ceo's first
#   one-minute run of the SCRIPtix program, CEO-1441: '1' ? *ABORT and ']' ? *((ABORT)) &INPUT end every long run). zd_k gave
#   IR_MATCH_ABORT a 16-byte spine cell it never reads (every op off its zero list gets one; its sibling cut box FENCE0 is on it). In a
#   pattern thunk the seal is the thunk's own abort-exit marker -- a second IR_MATCH_ABORT, literal 1 -- and the user ABORT's omega edge
#   enters that marker's beta. The user box pushed its cell and popped it on its omega; the marker's beta, planned as if its own alpha
#   had pushed a cell on top of the user's, popped 32 bytes more, so the thunk's exit read its continuation from the wrong slot
#   (gdb: r14 = -2, the abort marker set, then jmp *rcx with rcx = 0). A statement-level seal is a wiring GOTO, never a box, which is
#   why plain '1' ? ABORT agreed; an ABORT under an alternation arm or after ARB sat in an unplanned run and agreed too.
# THE CURE (src/emitter/emit.cpp zd_k): IR_MATCH_ABORT holds no cell -- K = 0, as FENCE0. Reach: only lower_snobol4.c builds the op.
# MONITOR BRACKET ('1' ? *ABORT, monitor_run.sh --oracle): step 1 agrees; step 2 spl reaches LABEL stno=3 (the F branch), scr has
#   died inside statement 1's match.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4 STATIC: deferred, stored, stored-then-deferred ABORT, with a capture before it, n preset              -- RED on base
#   3-4  m3 / m4 EVAL: the same shapes and the ceo's ']' ? *((ABORT)) &INPUT, EVALed                              -- RED on base
#   5-6  CONTROL m3 / m4: shapes base already answers -- plain ABORT, LEN(1) ABORT and an ABORT arm in a statement, *FAIL
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_an_abort_inside_a_pattern_thunk_fails_the_match_without_a_crash
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/st.sno" <<'EOF'
        x = 'stale'
        '1' ? *ABORT                            :S(Y1)F(N1)
Y1      OUTPUT = 'deferred abort: yes'          :(T2)
N1      OUTPUT = 'deferred abort: no'
T2      p = ABORT
        '1' ? p                                 :S(Y2)F(N2)
Y2      OUTPUT = 'stored abort: yes'            :(T3)
N2      OUTPUT = 'stored abort: no'
T3      p = LEN(1) ABORT
        '1' ? *p                                :S(Y3)F(N3)
Y3      OUTPUT = 'stored len abort deferred: yes' :(T4)
N3      OUTPUT = 'stored len abort deferred: no'
T4      p = '1' . x ABORT
        '12' ? p                                :S(Y4)F(N4)
Y4      OUTPUT = 'capture then abort: yes [' x ']' :(T5)
N4      OUTPUT = 'capture then abort: no [' x ']'
T5      '12' ? (*ABORT | '12')                  :S(Y5)F(N5)
Y5      OUTPUT = 'deferred abort arm: yes'      :(END)
N5      OUTPUT = 'deferred abort arm: no'
END
EOF
cat > "$T/ct.sno" <<'EOF'
        '1' ? ABORT                             :S(Y1)F(N1)
Y1      OUTPUT = 'plain abort: yes'             :(T2)
N1      OUTPUT = 'plain abort: no'
T2      '1' ? LEN(1) ABORT                      :S(Y2)F(N2)
Y2      OUTPUT = 'len abort: yes'               :(T3)
N2      OUTPUT = 'len abort: no'
T3      '12' ? ('1' ABORT | '12')               :S(Y3)F(N3)
Y3      OUTPUT = 'abort arm: yes'               :(T4)
N3      OUTPUT = 'abort arm: no'
T4      '1' ? *FAIL                             :S(Y4)F(N4)
Y4      OUTPUT = 'deferred fail: yes'           :(END)
N4      OUTPUT = 'deferred fail: no'
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
'1' ? *ABORT
'1' ? *((ABORT))
'1' ? LEN(1) *ABORT
'1' ? BAL *ABORT
'1' ? ARB *ABORT
'12' ? (LEN(1) $ X *ABORT) | '1'
'abc' ? *(LEN(1) ABORT) | 'b'
']' ? *((ABORT)) &INPUT
'12' ? '1' | *ABORT
EOF
want() { timeout -k 5 30 "$SBL" -bf "$T/$1.sno" < "$2" > "$T/$1.want" 2>/dev/null; [ -s "$T/$1.want" ] || refuse "sbl -bf produced no output for $1 -- the oracle's answer moved"; }
want st /dev/null; want ct /dev/null; want ev "$T/ev.in"
grep -q '^deferred abort: no$' "$T/st.want" && grep -q '^stored abort: no$' "$T/st.want" || refuse "sbl -bf no longer fails a match that reaches ABORT"
fail=0; pass=0
arm() { local n="$1" what="$2" got="$3" w="$4"
    if cmp -s "$w" "$got"; then pass=$((pass + 1)); echo "  arm $n PASS  $what"
    else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; diff "$w" "$got" | head -8 | sed 's/^/      /'; fi; }
m3() { timeout -k 5 30 "$SCRIP" "$T/$1.sno" < "$2" > "$T/$1.m3" 2>/dev/null; }
m4() { : > "$T/$1.m4"
       if timeout -k 5 120 "$SCRIP" --compile -o "$T/$1.s" "$T/$1.sno" < /dev/null > /dev/null 2>&1 \
          && gcc -no-pie "$T/$1.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/$1.bin" 2>/dev/null
       then timeout -k 5 30 "$T/$1.bin" < "$2" > "$T/$1.m4" 2>/dev/null; else echo COMPILE-FAILED > "$T/$1.m4"; fi; }
m3 st /dev/null; arm 1 "m3 static: a deferred or stored ABORT fails the match" "$T/st.m3" "$T/st.want"
m4 st /dev/null; arm 2 "m4 static: the same" "$T/st.m4" "$T/st.want"
m3 ev "$T/ev.in"; arm 3 "m3 EVAL: the same shapes and *((ABORT)), EVALed" "$T/ev.m3" "$T/ev.want"
m4 ev "$T/ev.in"; arm 4 "m4 EVAL: the same" "$T/ev.m4" "$T/ev.want"
m3 ct /dev/null; arm 5 "CONTROL m3: plain ABORT, LEN(1) ABORT, an ABORT arm in a statement, *FAIL" "$T/ct.m3" "$T/ct.want"
m4 ct /dev/null; arm 6 "CONTROL m4: the same" "$T/ct.m4" "$T/ct.want"
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- ABORT inside a pattern thunk fails the match, both modes, static and EVAL"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1

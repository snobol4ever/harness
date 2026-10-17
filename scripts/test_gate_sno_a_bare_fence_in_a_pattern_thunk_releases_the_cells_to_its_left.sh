#!/usr/bin/env bash
# test_gate_sno_a_bare_fence_in_a_pattern_thunk_releases_the_cells_to_its_left.sh -- a bare FENCE inside a pattern thunk (a stored
# p = TAB(0) FENCE, *p, the run-time pattern 'ab' ? TAB(0) FENCE 0 builds) after a box that keeps a spine cell (TAB, RTAB, SPAN, BREAK,
# REM, BAL) commits it, so backtracking into the thunk fails the whole match cleanly, in both modes, statically and inside EVAL, as
# SPITBOL answers it -- no [ZGC-STALE] SIGSEGV.
#
# ⛔ THE DEFECT (row snobol4-tab-then-a-bare-fence-then-an-integer-in-a-pattern-touches-a-stale-gc-pointer; found by the ceo's one-minute
#   run of the SCRIPtix program, CEO-1441, batch 33: 'ab' ? (TAB(0)) FENCE 0). The integer forces a run-time concatenation, so TAB(0)
#   FENCE becomes the thunk PAT$0 matched through MATCH_DEFER. fence0_release_bytes found the fence only on a chain from a MATCH_BEGIN,
#   and a thunk has none, so the FENCE released nothing and TAB's 16-byte cell stayed on the spine at the thunk's gamma. Backtracking
#   into the thunk goes PAT$0_beta -> the abort-exit marker -> PAT$0_omega, which assumes no cell is left: it read the saved r12 and the
#   caller's continuation 16 bytes off (r12 = the header's constant 3) and the run touched a moved block.
# THE CURE (src/emitter/emit.cpp fence0_release_bytes): in a graph with no MATCH_BEGIN -- a pattern thunk -- the fence is looked for on
#   the forward chain from the graph's entry, so it releases the backtrack-only cells to its left as it does in a statement; the ZD plan
#   already subtracts that release (zout = zd + K - REL), so the thunk's gamma trampoline reads at the released depth.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4 STATIC: the row's witness, stored and deferred X FENCE over TAB, RTAB, SPAN, BREAK, REM, a capture over it  -- RED on base
#   3-4  m3 / m4 EVAL: the same shapes and the ceo's ('ab' ? (TAB(0)) FENCE 0), EVALed                         -- RED on base
#   5-6  CONTROL m3 / m4: shapes base already answers -- LEN(1) FENCE (no cell), TAB(0) FENCE 'x' in a statement, the thunk
#        matched through with nothing after it
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_bare_fence_in_a_pattern_thunk_releases_the_cells_to_its_left
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
        'ab' ? TAB(0) FENCE 0                   :S(Y1)F(N1)
Y1      OUTPUT = 'row witness: yes'             :(T2)
N1      OUTPUT = 'row witness: no'
T2      p = TAB(0) FENCE
        'ab' ? p 'x'                            :S(Y2)F(N2)
Y2      OUTPUT = 'stored tab fence: yes'        :(T3)
N2      OUTPUT = 'stored tab fence: no'
T3      p = SPAN('a') FENCE
        'abc' ? *p 'x'                          :S(Y3)F(N3)
Y3      OUTPUT = 'deferred span fence: yes'     :(T4)
N3      OUTPUT = 'deferred span fence: no'
T4      p = BREAK('b') FENCE
        'abc' ? *p 'x'                          :S(Y4)F(N4)
Y4      OUTPUT = 'deferred break fence: yes'    :(T5)
N4      OUTPUT = 'deferred break fence: no'
T5      p = RTAB(1) FENCE
        'abc' ? *p 'c'                          :S(Y5)F(N5)
Y5      OUTPUT = 'deferred rtab fence then c: yes' :(T6)
N5      OUTPUT = 'deferred rtab fence then c: no'
T6      p = (TAB(1) FENCE) . x
        'abc' ? *p 'x'                          :S(Y6)F(N6)
Y6      OUTPUT = 'captured tab fence: yes [' x ']' :(T7)
N6      OUTPUT = 'captured tab fence: no [' x ']'
T7      p = REM FENCE
        'abc' ? *p 'x'                          :S(Y7)F(N7)
Y7      OUTPUT = 'deferred rem fence: yes'      :(END)
N7      OUTPUT = 'deferred rem fence: no'
END
EOF
cat > "$T/ct.sno" <<'EOF'
        p = LEN(1) FENCE
        'abc' ? *p 'x'                          :S(Y1)F(N1)
Y1      OUTPUT = 'len fence: yes'               :(T2)
N1      OUTPUT = 'len fence: no'
T2      'ab' ? TAB(0) FENCE 'x'                 :S(Y2)F(N2)
Y2      OUTPUT = 'statement tab fence x: yes'   :(T3)
N2      OUTPUT = 'statement tab fence x: no'
T3      p = TAB(0) FENCE
        'ab' ? *p                               :S(Y3)F(N3)
Y3      OUTPUT = 'thunk alone: yes'             :(END)
N3      OUTPUT = 'thunk alone: no'
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
'ab' ? TAB(0) FENCE 0
'ab' ? TAB(1) FENCE 0
'' ? TAB(0) FENCE 0
'ab' ? (TAB(0)) FENCE 0
'a1' ? TAB(1) FENCE 1
'abc' ? REM FENCE 0
'abc' ? RTAB(1) FENCE 9
'(a)b' ? BAL FENCE 'x'
'abc' ? (TAB(1) FENCE) . X 9
'abc' ? 'a' TAB(2) FENCE 0
EOF
want() { timeout -k 5 30 "$SBL" -bf "$T/$1.sno" < "$2" > "$T/$1.want" 2>/dev/null; [ -s "$T/$1.want" ] || refuse "sbl -bf produced no output for $1 -- the oracle's answer moved"; }
want st /dev/null; want ct /dev/null; want ev "$T/ev.in"
grep -q '^row witness: no$' "$T/st.want" && grep -q '^stored tab fence: no$' "$T/st.want" || refuse "sbl -bf no longer fails a match that backtracks into a committed FENCE"
fail=0; pass=0
arm() { local n="$1" what="$2" got="$3" w="$4"
    if cmp -s "$w" "$got"; then pass=$((pass + 1)); echo "  arm $n PASS  $what"
    else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; diff "$w" "$got" | head -8 | sed 's/^/      /'; fi; }
m3() { timeout -k 5 30 "$SCRIP" "$T/$1.sno" < "$2" > "$T/$1.m3" 2>/dev/null; }
m4() { : > "$T/$1.m4"
       if timeout -k 5 120 "$SCRIP" --compile -o "$T/$1.s" "$T/$1.sno" < /dev/null > /dev/null 2>&1 \
          && gcc -no-pie "$T/$1.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/$1.bin" 2>/dev/null
       then timeout -k 5 30 "$T/$1.bin" < "$2" > "$T/$1.m4" 2>/dev/null; else echo COMPILE-FAILED > "$T/$1.m4"; fi; }
m3 st /dev/null; arm 1 "m3 static: backtracking into a thunk's committed FENCE fails the match" "$T/st.m3" "$T/st.want"
m4 st /dev/null; arm 2 "m4 static: the same" "$T/st.m4" "$T/st.want"
m3 ev "$T/ev.in"; arm 3 "m3 EVAL: the same shapes, EVALed" "$T/ev.m3" "$T/ev.want"
m4 ev "$T/ev.in"; arm 4 "m4 EVAL: the same" "$T/ev.m4" "$T/ev.want"
m3 ct /dev/null; arm 5 "CONTROL m3: LEN(1) FENCE, a statement TAB(0) FENCE 'x', the thunk alone" "$T/ct.m3" "$T/ct.want"
m4 ct /dev/null; arm 6 "CONTROL m4: the same" "$T/ct.m4" "$T/ct.want"
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- a bare FENCE in a pattern thunk releases the cells to its left, both modes, static and EVAL"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1

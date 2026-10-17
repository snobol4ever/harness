#!/usr/bin/env bash
# test_gate_sno_a_capture_over_succeed_or_a_bare_fence_reads_its_own_saved_cursor.sh -- a conditional or immediate capture whose body
# is or begins with SUCCEED, or whose stored body holds a bare FENCE, assigns the substring it matched, in both modes, statically
# compiled, stored in a variable, and inside EVAL alike, as SPITBOL answers it -- and no run prints rt_dcap_pump's CORRUPT CAPTURE ENTRY.
#
# ⛔ THE DEFECTS (row snobol4-a-zero-length-capture-entry-reads-an-uninitialized-saved-delta; found by the cto's differential on the
#   master entry arb_pos_len_replace_1, subject POS(0) SUCCEED . nullmatch). Two roads, one class: the capture's COND read a saved
#   cursor its SAVE never left where the COND looked.
#   (A) SUCCEED: sno_pat_supported refuses SUCCEED, so SUCCEED . n is built at run time and its body lowers to a bare IR_GOTO, which is
#       the COND's operand 0. zd_plan refused the SAVE..COND run because that operand was not a run member ("[ZD] run h=0 len=2
#       REFUSED at i=2 (opnd ...)"), though its own read loop skips a capture's operand 0. Unplanned, the SAVE pushed its own 16-byte
#       cell ([rsp+0]) while the COND read FR(op_off) = [rsp+48]: stack garbage, a different saved_delta every run; with $ the garbage
#       length exhausted the heap at the hard cap.
#   (B) A BARE FENCE INSIDE A STORED CAPTURE (p = FENCE . n, p = ('a' FENCE) . n): in a pattern thunk fence0_dyn_floor resets rsp to the
#       blob floor (mov rsp, rbp; sub rsp, 56) unless a successor is dynamic, and the COND after the fence -- whose SAVE sits before it --
#       then read [rsp+0] = the prologue's constant 160 (saved_delta=160). SCRIP 9411ee7d2 made p = FENCE . n reach this road.
# THE CURES (src/emitter/emit.cpp): (A) zd_plan's operand check passes over a COND/IMM's operand 0 when it is a bare wiring GOTO, as the
#   read loop already does; (B) fence0_dyn_floor takes no floor when a successor COND/IMM reads a save cell the fence would drop.
# MONITOR BRACKET (subject SUCCEED . n, monitor_run.sh --oracle): step 4 stno 2 -- spl assigns n = '', scr goes on to stno 3 with no
#   assignment; after the cure AGREE=10 DIVERGE=0 UNGRADED=0.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME; every arm also requires its stderr free of CORRUPT CAPTURE ENTRY):
#   1-2  m3 / m4 STATIC + STORED: SUCCEED . n, SUCCEED $ n, (SUCCEED 'a') . n, p = FENCE . n, p = ('a' FENCE) . n, n preset   -- RED on base
#   3-4  m3 / m4 EVAL: the same shapes and backtracking through them, EVALed                                        -- RED on base
#   5-6  m3 / m4: the master entry arb_pos_len_replace_1 itself, two runs each                                   -- RED on base
#   7-8  CONTROL m3 / m4: shapes base already answers -- LEN(0) . n, ('a' SUCCEED) . n, (SUCCEED | 'a') . n, static FENCE . n
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no corpus entry, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
NAME=sno_a_capture_over_succeed_or_a_bare_fence_reads_its_own_saved_cursor
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
[ -f "$S4E/corpus/tests/snobol4/ALL.sno" ] || refuse "no SNOBOL4 master under $S4E/corpus -- pull corpus"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
python3 "$HERE/corpus_suite_harness.py" extract "$S4E/corpus/tests/snobol4/ALL.sno" "$S4E/corpus/tests/snobol4/ALL.ref" arb_pos_len_replace_1 "$T/ap.sno" > /dev/null 2>&1 || refuse "cannot extract arb_pos_len_replace_1 from the master"
cat > "$T/st.sno" <<'EOF'
        subject = 'abcdefgh'
        n = 'stale'
        subject SUCCEED . n
        OUTPUT = 'static succeed cond: [' n ']'
        n = 'stale'
        subject SUCCEED $ n
        OUTPUT = 'static succeed imm: [' n ']'
        n = 'stale'
        subject (SUCCEED 'a') . n
        OUTPUT = 'static succeed then a: [' n ']'
        n = 'stale'
        p = SUCCEED . n
        subject p
        OUTPUT = 'stored succeed cond: [' n ']'
        n = 'stale'
        p = FENCE . n
        subject p
        OUTPUT = 'stored fence cond: [' n ']'
        n = 'stale'
        p = ('a' FENCE) . n
        subject p
        OUTPUT = 'stored a fence cond: [' n ']'
        n = 'stale'
        p = ('ab' FENCE) $ n
        subject p
        OUTPUT = 'stored ab fence imm: [' n ']'
END
EOF
cat > "$T/ct.sno" <<'EOF'
        subject = 'abcdefgh'
        n = 'stale'
        subject LEN(0) . n
        OUTPUT = 'len0: [' n ']'
        n = 'stale'
        subject ('a' SUCCEED) . n
        OUTPUT = 'a succeed: [' n ']'
        n = 'stale'
        subject (SUCCEED | 'a') . n
        OUTPUT = 'succeed or a: [' n ']'
        n = 'stale'
        subject FENCE . n
        OUTPUT = 'static fence: [' n ']'
        n = 'stale'
        p = (FENCE 'a') . n
        subject p
        OUTPUT = 'stored fence a: [' n ']'
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
'abc' ? SUCCEED . n
'abc' ? SUCCEED $ n
'abc' ? (SUCCEED 'a') . n
'abc' ? FENCE . n
'abc' ? (FENCE . n) 'x'
'abc' ? ('a' FENCE) . n 'b'
'abc' ? ('a' FENCE) . n 'x'
'abc' ? (SUCCEED . n 'a') . m
'abc' ? ('a' | FENCE) $ n 'b'
EOF
want() { timeout -k 5 30 "$SBL" -bf "$T/$1.sno" < "$2" > "$T/$1.want" 2>/dev/null; [ -s "$T/$1.want" ] || refuse "sbl -bf produced no output for $1 -- the oracle's answer moved"; }
want st /dev/null; want ct /dev/null; want ev "$T/ev.in"; want ap /dev/null
grep -q '^stored fence cond: \[\]$' "$T/st.want" && grep -q '^static succeed cond: \[\]$' "$T/st.want" || refuse "sbl -bf no longer answers the static witness as cut (null captures)"
fail=0; pass=0
arm() { local n="$1" what="$2" got="$3" err="$4" w="$5"
    if cmp -s "$w" "$got" && ! grep -q 'CORRUPT CAPTURE ENTRY' "$err"; then pass=$((pass + 1)); echo "  arm $n PASS  $what"
    else fail=$((fail + 1)); echo "  arm $n FAIL  $what"; diff "$w" "$got" | head -8 | sed 's/^/      /'; grep -m2 'CORRUPT CAPTURE ENTRY' "$err" | cut -c1-160 | sed 's/^/      stderr: /'; fi; }
m3() { timeout -k 5 30 "$SCRIP" "$T/$1.sno" < "$2" > "$T/$1.m3$3" 2> "$T/$1.e3$3"; }
m4() { : > "$T/$1.m4$3"; : > "$T/$1.e4$3"
       if [ -x "$T/$1.bin" ] || { timeout -k 5 120 "$SCRIP" --compile -o "$T/$1.s" "$T/$1.sno" < /dev/null > /dev/null 2>&1 \
          && gcc -no-pie "$T/$1.s" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$T/$1.bin" 2>/dev/null; }
       then timeout -k 5 30 "$T/$1.bin" < "$2" > "$T/$1.m4$3" 2> "$T/$1.e4$3"; else echo COMPILE-FAILED > "$T/$1.m4$3"; fi; }
m3 st /dev/null ""; arm 1 "m3 static + stored: captures over SUCCEED and a stored bare FENCE assign what they matched" "$T/st.m3" "$T/st.e3" "$T/st.want"
m4 st /dev/null ""; arm 2 "m4 static + stored: the same" "$T/st.m4" "$T/st.e4" "$T/st.want"
m3 ev "$T/ev.in" ""; arm 3 "m3 EVAL: the same shapes and backtracking through them" "$T/ev.m3" "$T/ev.e3" "$T/ev.want"
m4 ev "$T/ev.in" ""; arm 4 "m4 EVAL: the same" "$T/ev.m4" "$T/ev.e4" "$T/ev.want"
m3 ap /dev/null 1; m3 ap /dev/null 2; cat "$T/ap.e31" "$T/ap.e32" > "$T/ap.e3"; cmp -s "$T/ap.m31" "$T/ap.m32" || echo RUNS-DIFFER >> "$T/ap.m31"
arm 5 "m3 master entry arb_pos_len_replace_1, two runs" "$T/ap.m31" "$T/ap.e3" "$T/ap.want"
m4 ap /dev/null 1; m4 ap /dev/null 2; cat "$T/ap.e41" "$T/ap.e42" > "$T/ap.e4"; cmp -s "$T/ap.m41" "$T/ap.m42" || echo RUNS-DIFFER >> "$T/ap.m41"
arm 6 "m4 master entry arb_pos_len_replace_1, two runs" "$T/ap.m41" "$T/ap.e4" "$T/ap.want"
m3 ct /dev/null ""; arm 7 "CONTROL m3: LEN(0), 'a' SUCCEED, SUCCEED | 'a', static FENCE, stored FENCE 'a' captures" "$T/ct.m3" "$T/ct.e3" "$T/ct.want"
m4 ct /dev/null ""; arm 8 "CONTROL m4: the same" "$T/ct.m4" "$T/ct.e4" "$T/ct.want"
if [ "$fail" -eq 0 ]; then echo "GATE PASS(0) [$NAME]: $pass arms -- a capture over SUCCEED or a stored bare FENCE reads its own saved cursor, both modes, static, stored and EVAL"; exit 0; fi
echo "GATE FAIL(1) [$NAME]: $fail of $((pass + fail)) arms red"; exit 1

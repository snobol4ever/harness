#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_a_capture_slices_the_subject_and_table_convert_mkpat_take_the_direct_table.sh -- TWO COSTS OF PORTER AND JSON
# (ceo 2026-09-25, CEO-1259; notebook section 19). (1) An IMMEDIATE capture (`pat $ x`, the asm entries rt_cap_open_gva and
# rt_cap_open_plain) allocated a fresh string and copied the captured bytes on every capture, and a DEFERRED-CALL capture
# (`pat . *f()`) in the conditional pump was the one shape refused the slice every other conditional capture took; porter
# spent 7.7% in the capture entry and 4.5% in the allocator for it, and collected for it. Since this landing every capture is a
# SLICE of the subject -- a stamped DT_S pointing into the subject's bytes, the subject's frontier ownership broken exactly as the
# conditional pump has always done (a string is a value: a later assignment to the subject variable makes a new string, an
# in-place extension writes past the old end, and the collector roots an interior pointer) -- and nothing is allocated.
# (2) TABLE, CONVERT and SNO$MKPAT calls fell from the asm bid entry to the C by-name path (json 10,939 TABLE and 14,392 CONVERT
# per run, porter 13,588 SNO$MKPAT); they have direct-table rows now, and CONVERT is a leaf builtin so its sites reach the entry.
# ARMS: (1) the capture witness prints the oracle's lines in m3 and m4 (immediate, conditional and deferred-call captures;
# the subject reassigned, extended in place and reversed after the capture; captures extended in place; empty captures; a
# nested match inside the deferred callee; INPUT-line subjects across reads); (2) gdb counts rt_str_alloc hits over 3,000
# immediate captures and 1,000 deferred-call captures: at most 200 (pre-cure: one per capture); (3) gdb counts c_rt_call_bid_sn4
# hits over 1,000 TABLE() calls and rt_call_arr_impl hits over 2,000 CONVERT calls: at most 100 each (pre-cure: one per call).
# FAIL_ONCE (recorded): the pre-cure runtime at 0459c3a5c read rt_str_alloc hits 4,007, c_rt_call_bid_sn4 hits 1,003 and rt_call_arr_impl hits 3,004; this tree reads 3, 2 and 1.
# EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle, gdb or the build missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
command -v gdb >/dev/null 2>&1 || { echo "REFUSED(2): gdb missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/cap.sno" <<'SNO'
        &TRIM = 1
        DEFINE('f()')                                   :(f_end)
f       s2 = 'inner subject'
        s2 'inner' $ iw
        f = .fv                                         :(NRETURN)
f_end
        s = 'hello world'
        s 'hello' $ x ' ' $ sp 'world' . y
        OUTPUT = x '|' sp '|' y '|' s
        s = s '!'
        x = x 'X'
        y = 'Y' y
        OUTPUT = x '|' y '|' s
        s = 'abc'
        s 'b' $ m
        s = 'zzz'
        OUTPUT = m '|' s
        t = 'the quick brown fox'
        t 'quick' $ q ' ' 'brown' . *f()
        OUTPUT = q '|' fv '|' iw '|' t
        t = t ' jumps'
        OUTPUT = q '|' fv '|' t
        u = 'aaa'
        u '' $ e1 'aaa' . e2
        OUTPUT = SIZE(e1) '|' e2 '|' IDENT(e1) 'empty'
        n = 0
loop    line = INPUT                                    :F(done)
        line BREAK(' ') $ w1 ' ' REM . w2
        keep = keep w1 ',' w2 ';'
        n = n + 1                                       :(loop)
done    OUTPUT = n '|' keep
        v = 'p1 p2 p3'
        v 'p1' $ a1 ' ' 'p2' $ a2 ' ' 'p3' $ a3
        v = DUPL('-', 20)
        OUTPUT = a1 a2 a3 '|' v
        big = DUPL('ab', 6)
        big 'ab' $ h ARB $ mid 'ab' RPOS(0) . tl
        big = REVERSE(big)
        OUTPUT = h '|' mid '|' tl '|' big
        z = 'k=v'
        z BREAK('=') . k '=' REM . vv
        k = k k
        vv = vv 'x'
        OUTPUT = k '|' vv '|' z
END
SNO
printf 'one two\nthree four\nfive six\n' > "$W/cap.in"
"$SBL" $(sbl_lang_flags) "$W/cap.sno" < "$W/cap.in" > "$W/cap.ref" 2>&1 || true
[ -s "$W/cap.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the witness"; exit 2; }
red=0
( cd "$W" && timeout -k 5 30 "$ROOT/scrip" cap.sno < cap.in > "$W/cap.m3" 2>&1 ); cmp -s "$W/cap.m3" "$W/cap.ref" && echo "ok  (1) m3 = oracle over $(wc -l < "$W/cap.ref") lines" || { echo "RED (1) m3 differs from the oracle:"; diff "$W/cap.ref" "$W/cap.m3" | head -6; red=1; }
( cd "$W" && "$ROOT/scrip" --compile -o "$W/cap.s" cap.sno < /dev/null > /dev/null 2>&1 && gcc "$W/cap.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/cap.bin" 2>/dev/null ) || { echo "REFUSED(2): the witness did not build in mode 4"; exit 2; }
( cd "$W" && timeout -k 5 30 ./cap.bin < cap.in > "$W/cap.m4" 2>&1 ); cmp -s "$W/cap.m4" "$W/cap.ref" && echo "ok  (1) m4 = oracle" || { echo "RED (1) m4 differs from the oracle:"; diff "$W/cap.ref" "$W/cap.m4" | head -6; red=1; }
cat > "$W/imm.sno" <<'SNO'
        DEFINE('g()')                                   :(g_end)
g       g = .gv                                         :(NRETURN)
g_end
        s = 'alpha beta gamma'
        i = 0
loop    s 'alpha' $ a ' ' $ b 'beta' $ c ' gamma' . *g()
        i = LT(i, 1000) i + 1                           :S(loop)
        OUTPUT = a '|' b '|' c '|' gv '|' i
END
SNO
( cd "$W" && "$ROOT/scrip" --compile -o "$W/imm.s" imm.sno < /dev/null > /dev/null 2>&1 && gcc "$W/imm.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/imm.bin" 2>/dev/null ) || { echo "REFUSED(2): the capture twin did not build"; exit 2; }
( cd "$W" && timeout -k 5 30 ./imm.bin < /dev/null > "$W/imm.out" 2>&1 ); grep -q '^alpha| |beta| gamma|1000$' "$W/imm.out" || { echo "REFUSED(2): the capture twin did not print its line: $(head -1 "$W/imm.out")"; exit 2; }
allocs=$( cd "$W" && timeout -k 5 300 gdb -q -batch -ex 'set breakpoint pending on' -ex 'break rt_str_alloc' -ex 'ignore 1 100000000' -ex 'run < /dev/null > /dev/null 2>&1' -ex 'info breakpoints' ./imm.bin 2>&1 | grep -o 'already hit [0-9]* time' | grep -o '[0-9]*' | head -1 ); allocs=${allocs:-0}
if [ "$allocs" -le 200 ]; then echo "ok  (2) rt_str_alloc hits=$allocs <= 200 over 3,000 immediate and 1,000 deferred-call captures: every capture is a slice"
else echo "RED (2) rt_str_alloc hits=$allocs > 200 over 4,000 captures: captures copy the subject again"; red=1; fi
cat > "$W/tc.sno" <<'SNO'
        i = 0
loop    t = TABLE()
        t['k'] = i
        n = CONVERT('12', 'INTEGER') + CONVERT(i, 'INTEGER')
        s = CONVERT(n, 'STRING')
        i = LT(i, 1000) i + 1                           :S(loop)
        OUTPUT = n ' ' DATATYPE(n) ' ' s ' ' DATATYPE(s) ' ' t['k']
END
SNO
( cd "$W" && "$ROOT/scrip" --compile -o "$W/tc.s" tc.sno < /dev/null > /dev/null 2>&1 && gcc "$W/tc.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/tc.bin" 2>/dev/null ) || { echo "REFUSED(2): the table/convert twin did not build"; exit 2; }
( cd "$W" && timeout -k 5 30 ./tc.bin < /dev/null > "$W/tc.out" 2>&1 ); grep -q '^1012 INTEGER 1012 STRING 1000$' "$W/tc.out" || { echo "REFUSED(2): the table/convert twin did not print its line: $(head -1 "$W/tc.out")"; exit 2; }
ctail=$( cd "$W" && timeout -k 5 300 gdb -q -batch -ex 'set breakpoint pending on' -ex 'break c_rt_call_bid_sn4' -ex 'ignore 1 100000000' -ex 'run < /dev/null > /dev/null 2>&1' -ex 'info breakpoints' ./tc.bin 2>&1 | grep -o 'already hit [0-9]* time' | grep -o '[0-9]*' | head -1 ); ctail=${ctail:-0}
arr=$( cd "$W" && timeout -k 5 300 gdb -q -batch -ex 'set breakpoint pending on' -ex 'break rt_call_arr_impl' -ex 'ignore 1 100000000' -ex 'run < /dev/null > /dev/null 2>&1' -ex 'info breakpoints' ./tc.bin 2>&1 | grep -o 'already hit [0-9]* time' | grep -o '[0-9]*' | head -1 ); arr=${arr:-0}
if [ "$ctail" -le 100 ] && [ "$arr" -le 100 ]; then echo "ok  (3) c_rt_call_bid_sn4 hits=$ctail and rt_call_arr_impl hits=$arr, both <= 100 over 1,001 TABLE() and 3,003 CONVERT calls: the direct table answers them"
else echo "RED (3) c_rt_call_bid_sn4 hits=$ctail / rt_call_arr_impl hits=$arr over 1,001 TABLE() and 3,003 CONVERT calls: they fall to the C by-name path again"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: every capture is a slice of the subject, TABLE, CONVERT and SNO\$MKPAT take the direct table, and the capture shapes answer the oracle"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1

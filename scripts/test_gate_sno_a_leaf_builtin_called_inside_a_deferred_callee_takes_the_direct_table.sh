#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_a_leaf_builtin_called_inside_a_deferred_callee_takes_the_direct_table.sh -- THE EVAL STAGE IS NOT A PENDING ERROR
# (hq_snobol4 2026-10-15; row snobol4-speed-beauty-self-host-reads-0-22x-spitbol-in-mode-4-and-0-06x-in-mode-3). A function that a
# pattern calls through a deferred reference (`*f(x)`) runs with g_error = G_ERROR_EVAL_STAGE (LONG_MIN) for its whole dynamic extent,
# and the two gates of the leaf fast path -- the asm entry rt_call_bid_sn4 and its C twin c_rt_call_bid_sn4 -- declined on any nonzero
# g_error, so EVERY leaf builtin (REPLACE, DUPL, SIZE, SUBSTR, LPAD, TRIM, REMDR ...) called anywhere under a deferred call took the
# seven C wrappers of the by-name road (rt_call_arr_bl_sn4 .. rt_call_arr_impl, an errjmp frame, two GC callback frames):
# 1,276 instructions per REPLACE in the beauty self-host, 25.5% of its run. core_runtime_error already reads the stage as "count the
# error, the operation fails" (it returns, never throws), and every direct-table body returns its own FAIL after raising one, so the
# stage passes the gate; any other nonzero g_error (Icon's positive count, the constant folder's -2) still declines.
# ARMS: (1) the witness (leaf builtins under deferred calls, and four of them raising errors 171/90/166/165 at &ERRLIMIT 20) prints the
# oracle's lines in m3 and m4 -- the error counts (20 -> 18 -> 16 -> 14, two per failed call) are the arm that a double raise would break;
# (2) gdb counts rt_call_arr_impl hits and c_rt_call_bid_sn4 hits over 1,000 deferred calls of a REPLACE function, mode 4: at most 100
# each (pre-cure: one per call).
# FAIL_ONCE (recorded): the pre-cure runtime (b32062a4b) read rt_call_arr_impl hits >= 1,000 and c_rt_call_bid_sn4 hits >= 1,000.
# EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle, gdb or the build missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
command -v gdb >/dev/null 2>&1 || { echo "REFUSED(2): gdb missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/stage.sno" <<'SNO'
        DEFINE('lw(x)')                                 :(lw_end)
lw      lw = REPLACE(x, &UCASE, &LCASE)                 :(RETURN)
lw_end
        DEFINE('pr(x)')                                 :(pr_end)
pr      pr = LPAD(DUPL(x, 2), 6, '.')
        pr = SIZE(pr) REVERSE(TRIM(SUBSTR(pr, 2, 3)))   :(RETURN)
pr_end
        DEFINE('bad(x)')                                :(bad_end)
bad     bad = REPLACE(x, 'ab', 'x')                     :S(RETURN)F(FRETURN)
bad_end
        DEFINE('dp(x)')                                 :(dp_end)
dp      dp = DUPL(x, 'q')                               :S(RETURN)F(FRETURN)
dp_end
        DEFINE('rm(x)')                                 :(rm_end)
rm      rm = REMDR(x, 'q')                              :S(RETURN)F(FRETURN)
rm_end
        &ERRLIMIT = 20
        'Aa' ? LEN(1) . c *lw(c)                        :S(s1)F(f1)
s1      OUTPUT = 'lw matched ' c                        :(n2)
f1      OUTPUT = 'lw failed ' c
n2      'k6...' ? LEN(1) . c *pr(c)                     :S(s2)F(f2)
s2      OUTPUT = 'pr matched ' c                        :(n3)
f2      OUTPUT = 'pr failed ' c
n3      'zz' ? LEN(1) . c *bad(c)                       :S(s3)F(f3)
s3      OUTPUT = 'bad matched ' c                       :(n4)
f3      OUTPUT = 'bad failed ' c ' errlimit ' &ERRLIMIT
n4      'zz' ? LEN(1) . c *dp(c)                        :S(s4)F(f4)
s4      OUTPUT = 'dp matched ' c                        :(n5)
f4      OUTPUT = 'dp failed ' c ' errlimit ' &ERRLIMIT
n5      'zz' ? LEN(1) . c *rm(c)                        :S(s5)F(f5)
s5      OUTPUT = 'rm matched ' c                        :(n6)
f5      OUTPUT = 'rm failed ' c ' errlimit ' &ERRLIMIT
n6      OUTPUT = 'done errlimit ' &ERRLIMIT
END
SNO
"$SBL" $(sbl_lang_flags) "$W/stage.sno" < /dev/null > "$W/stage.ref" 2>&1 || true
[ -s "$W/stage.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the witness"; exit 2; }
grep -q '^done errlimit 14$' "$W/stage.ref" || { echo "REFUSED(2): the oracle's witness did not reach its last line: $(tail -1 "$W/stage.ref")"; exit 2; }
red=0
( cd "$W" && timeout -k 5 30 "$ROOT/scrip" stage.sno < /dev/null > "$W/stage.m3" 2>&1 )
if cmp -s "$W/stage.m3" "$W/stage.ref"; then echo "ok  (1) m3 = oracle over $(wc -l < "$W/stage.ref") lines"; else echo "RED (1) m3 differs from the oracle:"; diff "$W/stage.ref" "$W/stage.m3" | head -6; red=1; fi
( cd "$W" && "$ROOT/scrip" --compile -o "$W/stage.s" stage.sno < /dev/null > /dev/null 2>&1 && gcc "$W/stage.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/stage.bin" 2>/dev/null ) || { echo "REFUSED(2): the witness did not build in mode 4"; exit 2; }
( cd "$W" && timeout -k 5 30 ./stage.bin < /dev/null > "$W/stage.m4" 2>&1 )
if cmp -s "$W/stage.m4" "$W/stage.ref"; then echo "ok  (1) m4 = oracle"; else echo "RED (1) m4 differs from the oracle:"; diff "$W/stage.ref" "$W/stage.m4" | head -6; red=1; fi
cat > "$W/loop.sno" <<'SNO'
        DEFINE('lw(x)')                                 :(lw_end)
lw      lw = REPLACE(x, &UCASE, &LCASE)                 :(RETURN)
lw_end
        i = 0
loop    'Aa' ? LEN(1) . c *lw(c)                        :F(bad)
        i = LT(i, 1000) i + 1                           :S(loop)
        OUTPUT = 'done ' i                              :(fin)
bad     OUTPUT = 'failed at ' i
fin
END
SNO
( cd "$W" && "$ROOT/scrip" --compile -o "$W/loop.s" loop.sno < /dev/null > /dev/null 2>&1 && gcc "$W/loop.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/loop.bin" 2>/dev/null ) || { echo "REFUSED(2): the loop twin did not build"; exit 2; }
( cd "$W" && timeout -k 5 30 ./loop.bin < /dev/null > "$W/loop.out" 2>&1 ); grep -q '^done 1000$' "$W/loop.out" || { echo "REFUSED(2): the loop twin did not print its line: $(head -1 "$W/loop.out")"; exit 2; }
hits() { ( cd "$W" && timeout -k 5 300 gdb -q -batch -ex 'set breakpoint pending on' -ex "break $1" -ex 'ignore 1 100000000' -ex 'run < /dev/null > /dev/null 2>&1' -ex 'info breakpoints' ./loop.bin 2>&1 | grep -o 'already hit [0-9]* time' | grep -o '[0-9]*' | head -1 ); }
ctail=$(hits c_rt_call_bid_sn4); arr=$(hits rt_call_arr_impl); ctail=${ctail:-0}; arr=${arr:-0}
if [ "$ctail" -le 100 ] && [ "$arr" -le 100 ]; then echo "ok  (2) c_rt_call_bid_sn4 hits=$ctail and rt_call_arr_impl hits=$arr, both <= 100 over 1,001 deferred calls of a REPLACE function: the direct table answers them"
else echo "RED (2) c_rt_call_bid_sn4 hits=$ctail / rt_call_arr_impl hits=$arr over 1,001 deferred calls of a REPLACE function: a leaf builtin under the eval stage falls to the C by-name road again"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: a leaf builtin under a deferred call takes the direct table, and its errors count as the oracle counts them"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1

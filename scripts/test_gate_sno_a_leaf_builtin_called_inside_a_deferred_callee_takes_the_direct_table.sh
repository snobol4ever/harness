#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (R-523)"
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
# each (pre-cure: one per call); (3) the same stage one function level DOWN: the eval marker is G_ERROR_EVAL_AT(kw_fnclevel), LONG_MIN plus
# the level, so a pattern's deferred call made from inside a user function (every deferred call of the beauty self-host) runs with a marker
# the asm leaf's old `add rax,rax; jnz` gate declined at every level but 0 (hq_snobol4 2026-10-31, row snobol4-speed-beauty-self-host-reads-
# 0-22x...): a witness with a DATA type live (rt_dtax_gen != 0, which also keeps the C twin off its direct ladder), a deferred call under
# one and under four nested functions, errors raised under a function counted as the oracle counts them, prints the oracle's lines in m3
# and m4; (4) gdb counts c_rt_call_bid_sn4 hits over 1,001 such nested deferred calls: at most 100 (pre-cure at 5ec68d47a: 1,001).
# FAIL_ONCE (recorded): the pre-cure runtime (b32062a4b) read rt_call_arr_impl hits >= 1,000 and c_rt_call_bid_sn4 hits >= 1,000; arm (4)
# read c_rt_call_bid_sn4 hits = 1,001 on the tree before the leaf's error gate took the whole eval-marker range (5ec68d47a), 0 after.
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
( cd "$W" && "$ROOT/scrip" --compile --out="$W/stage.s" stage.sno < /dev/null > /dev/null 2>&1 && gcc "$W/stage.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/stage.bin" 2>/dev/null ) || { echo "REFUSED(2): the witness did not build in mode 4"; exit 2; }
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
( cd "$W" && "$ROOT/scrip" --compile --out="$W/loop.s" loop.sno < /dev/null > /dev/null 2>&1 && gcc "$W/loop.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/loop.bin" 2>/dev/null ) || { echo "REFUSED(2): the loop twin did not build"; exit 2; }
( cd "$W" && timeout -k 5 30 ./loop.bin < /dev/null > "$W/loop.out" 2>&1 ); grep -q '^done 1000$' "$W/loop.out" || { echo "REFUSED(2): the loop twin did not print its line: $(head -1 "$W/loop.out")"; exit 2; }
hits() { ( cd "$W" && timeout -k 5 300 gdb -q -batch -ex 'set breakpoint pending on' -ex "break $1" -ex 'ignore 1 100000000' -ex 'run < /dev/null > /dev/null 2>&1' -ex 'info breakpoints' ./${2:-loop.bin} 2>&1 | grep -o 'already hit [0-9]* time' | grep -o '[0-9]*' | head -1 ); }
ctail=$(hits c_rt_call_bid_sn4); arr=$(hits rt_call_arr_impl); ctail=${ctail:-0}; arr=${arr:-0}
if [ "$ctail" -le 100 ] && [ "$arr" -le 100 ]; then echo "ok  (2) c_rt_call_bid_sn4 hits=$ctail and rt_call_arr_impl hits=$arr, both <= 100 over 1,001 deferred calls of a REPLACE function: the direct table answers them"
else echo "RED (2) c_rt_call_bid_sn4 hits=$ctail / rt_call_arr_impl hits=$arr over 1,001 deferred calls of a REPLACE function: a leaf builtin under the eval stage falls to the C by-name road again"; red=1; fi
cat > "$W/nest.sno" <<'SNO'
        DATA('nd(a,b)')
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
        DEFINE('drv(n)i,c')                             :(drv_end)
drv     i = 0
dloop   'Aa' ? LEN(1) . c *lw(c)                        :F(dbad)
        i = LT(i, n) i + 1                              :S(dloop)
        drv = 'done ' i ' ' c                           :(RETURN)
dbad    drv = 'failed at ' i                            :(RETURN)
drv_end
        DEFINE('deep(n)')                               :(deep_end)
deep    deep = EQ(n, 0) drv(3)                          :S(RETURN)
        deep = deep(n - 1)                              :(RETURN)
deep_end
        DEFINE('errs(x)c')                              :(errs_end)
errs    'zz' ? LEN(1) . c *bad(c)                       :S(es1)F(ef1)
es1     errs = 'bad matched ' c                         :(RETURN)
ef1     errs = 'bad failed ' c ' errlimit ' &ERRLIMIT   :(RETURN)
errs_end
        DEFINE('errd(x)c')                              :(errd_end)
errd    'zz' ? LEN(1) . c *dp(c)                        :S(ds1)F(df1)
ds1     errd = 'dp matched ' c                          :(RETURN)
df1     errd = 'dp failed ' c ' errlimit ' &ERRLIMIT    :(RETURN)
errd_end
        DEFINE('pri(x)c')                               :(pri_end)
pri     'k6...' ? LEN(1) . c *pr(c)                     :S(ps1)F(pf1)
ps1     pri = 'pr matched ' c                           :(RETURN)
pf1     pri = 'pr failed ' c                            :(RETURN)
pri_end
        &ERRLIMIT = 20
        t = nd(1, 2)
        OUTPUT = drv(5)
        OUTPUT = deep(4)
        OUTPUT = pri(1)
        OUTPUT = errs(1)
        OUTPUT = errd(1)
        OUTPUT = deep(2)
        OUTPUT = 'done errlimit ' &ERRLIMIT
END
SNO
"$SBL" $(sbl_lang_flags) "$W/nest.sno" < /dev/null > "$W/nest.ref" 2>&1 || true
grep -q '^done errlimit 16$' "$W/nest.ref" || { echo "REFUSED(2): the oracle's nested witness did not reach its last line: $(tail -1 "$W/nest.ref")"; exit 2; }
( cd "$W" && timeout -k 5 30 "$ROOT/scrip" nest.sno < /dev/null > "$W/nest.m3" 2>&1 )
if cmp -s "$W/nest.m3" "$W/nest.ref"; then echo "ok  (3) m3 = oracle over $(wc -l < "$W/nest.ref") lines, the deferred calls one and four functions deep"; else echo "RED (3) m3 differs from the oracle:"; diff "$W/nest.ref" "$W/nest.m3" | head -6; red=1; fi
( cd "$W" && "$ROOT/scrip" --compile --out="$W/nest.s" nest.sno < /dev/null > /dev/null 2>&1 && gcc "$W/nest.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/nest.bin" 2>/dev/null ) || { echo "REFUSED(2): the nested witness did not build in mode 4"; exit 2; }
( cd "$W" && timeout -k 5 30 ./nest.bin < /dev/null > "$W/nest.m4" 2>&1 )
if cmp -s "$W/nest.m4" "$W/nest.ref"; then echo "ok  (3) m4 = oracle"; else echo "RED (3) m4 differs from the oracle:"; diff "$W/nest.ref" "$W/nest.m4" | head -6; red=1; fi
cat > "$W/loop2.sno" <<'SNO'
        DATA('nd(a,b)')
        DEFINE('lw(x)')                                 :(lw_end)
lw      lw = REPLACE(x, &UCASE, &LCASE)                 :(RETURN)
lw_end
        DEFINE('drv(n)i,c')                             :(drv_end)
drv     i = 0
dloop   'Aa' ? LEN(1) . c *lw(c)                        :F(dbad)
        i = LT(i, n) i + 1                              :S(dloop)
        drv = 'done ' i                                 :(RETURN)
dbad    drv = 'failed at ' i                            :(RETURN)
drv_end t = nd(1, 2)
        OUTPUT = drv(1000)
END
SNO
( cd "$W" && "$ROOT/scrip" --compile --out="$W/loop2.s" loop2.sno < /dev/null > /dev/null 2>&1 && gcc "$W/loop2.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/loop2.bin" 2>/dev/null ) || { echo "REFUSED(2): the nested loop twin did not build"; exit 2; }
( cd "$W" && timeout -k 5 30 ./loop2.bin < /dev/null > "$W/loop2.out" 2>&1 ); grep -q '^done 1000$' "$W/loop2.out" || { echo "REFUSED(2): the nested loop twin did not print its line: $(head -1 "$W/loop2.out")"; exit 2; }
ctail2=$(hits c_rt_call_bid_sn4 loop2.bin); ctail2=${ctail2:-0}
if [ "$ctail2" -le 100 ]; then echo "ok  (4) c_rt_call_bid_sn4 hits=$ctail2 over 1,001 deferred calls made from inside a function with a DATA type live: the leaf's gate takes the whole eval-marker range"
else echo "RED (4) c_rt_call_bid_sn4 hits=$ctail2 over 1,001 deferred calls made from inside a function: the leaf declines the eval marker above level 0 and the by-name road answers every builtin again"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: a leaf builtin under a deferred call takes the direct table, and its errors count as the oracle counts them"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1

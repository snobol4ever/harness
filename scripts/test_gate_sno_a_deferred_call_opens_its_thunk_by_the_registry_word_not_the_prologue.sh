#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_a_deferred_call_opens_its_thunk_by_the_registry_word_not_the_prologue.sh -- NINTH SPEED CLASS
# (hq_snobol4 2026-11-01, row snobol4-speed-by-instruction-count-the-ir-bar-...-ceo-1785; the beauty self-host, the largest real SNOBOL4
# program of the lane). A pattern's deferred call (*f(x)) opens its THUNK record through rt_call_open_staged_rec -> rt_call_open_by_name_p
# -> rt_proc_call_open_pn -> rt_proc_call_open_p -> rt_proc_call_prologue -> rt_wn_park_on and back through rt_c2bb_word: about 460
# instructions an open, 190,773 opens and 14 percent of beauty. For a thunk that road computes a frame size nobody reads, parks and restores
# rt_g_want_name to the value it found, and returns a word whose every field the registry slot already holds: the whole open is
# (fn, touches-level << 6 | want-name << 7 | slot << 40). rt_thunk_open_fast (rt.c) returns that word directly when the record is a
# dyn_scope thunk with a body, its slot is in the registry, no trace layer is armed (g_runtime.abi.trace_budget == 0 and rt_trace_layer_idle())
# and SCRIP_PROC_OPEN_P is not 0; every other open takes the road it took before, so a TRACEd or &FTRACEd deferred call still prints its event.
# ARMS: (1) the witness (deferred calls at the top level, with two arguments, a failing one, a recursion through a function that makes
# deferred calls, a DATA type live) prints the oracle's lines in m3 and m4; (2) gdb counts rt_proc_call_prologue hits over 1,001 deferred
# calls made at the top level, mode 4: at most 100 (pre-cure: one per call, 1,001 or more); (3) the same 1,001 deferred calls made from
# inside a function with a DATA type live, at most 100; (4) the same loop under &FTRACE = 100000 must still take the prologue (at least
# 1,000 hits): the guard that keeps a traced thunk open on its old road, where its trace event is emitted.
# FAIL_ONCE (recorded, no plant): this gate run against the parent runtime (SCRIP 051409d43) read arm (2) and arm (3) hits = 1,001 (RED) and
# arm (4) 1,001; against the cure arm (2) and (3) read 0 and arm (4) 1,001 (GREEN). Beauty self-host WORK 631.9 M to 578.5 M, 0.394x to 0.430x.
# EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle, gdb or the build missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
command -v gdb >/dev/null 2>&1 || { echo "REFUSED(2): gdb missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/dfr.sno" <<'SNO'
        DATA('node(v,nx)')
        DEFINE('f(x)')
        DEFINE('g(x,y)t')
        DEFINE('rec(m)')
        DEFINE('fails()')
        cnt = 0
        p = 'a' *f(1) 'c'
        'abc' ? p . r                                   :S(o1)F(e1)
e1      OUTPUT = 'e1'                                   :(o2)
o1      OUTPUT = 'r=' r
o2      'xyz' ? *g('x','y') . r2                        :S(o3)F(e3)
e3      OUTPUT = 'e3'                                   :(o4)
o3      OUTPUT = 'r2=' r2
o4      'qqq' ? *fails()                                :S(e5)F(o5)
e5      OUTPUT = 'e5'
o5      OUTPUT = 'rec ' rec(3)
        t1 = node('aa', node('bb'))
        'aabb' ? *LEN(2) . a1 *LEN(2) . a2
        OUTPUT = a1 a2
        OUTPUT = 'cnt=' cnt
        :(END)
f       cnt = cnt + 1
        f = 'b'                                         :(RETURN)
g       t = x y
        g = t                                           :(RETURN)
rec     rec = EQ(m,0) 'z'                               :S(RETURN)
        'abc' ? 'a' *f(m) 'c'
        rec = rec(m - 1)                                :(RETURN)
fails                                                   :(FRETURN)
END
SNO
"$SBL" $(sbl_lang_flags) "$W/dfr.sno" < /dev/null > "$W/dfr.ref" 2>&1 || true
[ -s "$W/dfr.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the witness"; exit 2; }
grep -q '^cnt=' "$W/dfr.ref" || { echo "REFUSED(2): the oracle's witness did not reach its last line: $(tail -1 "$W/dfr.ref")"; exit 2; }
red=0
( cd "$W" && timeout -k 5 30 "$ROOT/scrip" dfr.sno < /dev/null > "$W/dfr.m3" 2>&1 )
if cmp -s "$W/dfr.m3" "$W/dfr.ref"; then echo "ok  (1) m3 = oracle over $(wc -l < "$W/dfr.ref") lines"; else echo "RED (1) m3 differs from the oracle:"; diff "$W/dfr.ref" "$W/dfr.m3" | head -6; red=1; fi
build() { ( cd "$W" && "$ROOT/scrip" --compile --out="$W/$1.s" "$1.sno" < /dev/null > /dev/null 2>&1 && gcc "$W/$1.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/$1.bin" 2>/dev/null ) || { echo "REFUSED(2): $1 did not build in mode 4"; exit 2; }; }
build dfr
( cd "$W" && timeout -k 5 30 ./dfr.bin < /dev/null > "$W/dfr.m4" 2>&1 )
if cmp -s "$W/dfr.m4" "$W/dfr.ref"; then echo "ok  (1) m4 = oracle"; else echo "RED (1) m4 differs from the oracle:"; diff "$W/dfr.ref" "$W/dfr.m4" | head -6; red=1; fi
cat > "$W/loop.sno" <<'SNO'
        DEFINE('lw(x)')                                 :(lw_end)
lw      lw = 'a'                                        :(RETURN)
lw_end
        i = 0
loop    'Aa' ? LEN(1) . c *lw(c)                        :F(bad)
        i = LT(i, 1000) i + 1                           :S(loop)
        OUTPUT = 'done ' i                              :(fin)
bad     OUTPUT = 'failed at ' i
fin
END
SNO
cat > "$W/loopt.sno" <<'SNO'
        &FTRACE = 100000
        DEFINE('lw(x)')                                 :(lw_end)
lw      lw = 'a'                                        :(RETURN)
lw_end
        i = 0
loop    'Aa' ? LEN(1) . c *lw(c)                        :F(bad)
        i = LT(i, 1000) i + 1                           :S(loop)
        OUTPUT = 'done ' i                              :(fin)
bad     OUTPUT = 'failed at ' i
fin
END
SNO
cat > "$W/loopn.sno" <<'SNO'
        DATA('nd(a,b)')
        DEFINE('lw(x)')                                 :(lw_end)
lw      lw = 'a'                                        :(RETURN)
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
for n in loop loopt loopn; do build $n; done
( cd "$W" && timeout -k 5 30 ./loop.bin < /dev/null > "$W/loop.out" 2>&1 ); grep -q '^done 1000$' "$W/loop.out" || { echo "REFUSED(2): the loop twin did not print its line: $(head -1 "$W/loop.out")"; exit 2; }
( cd "$W" && timeout -k 5 30 ./loopn.bin < /dev/null > "$W/loopn.out" 2>&1 ); grep -q '^done 1000$' "$W/loopn.out" || { echo "REFUSED(2): the nested loop twin did not print its line: $(head -1 "$W/loopn.out")"; exit 2; }
( cd "$W" && timeout -k 5 30 ./loopt.bin < /dev/null > "$W/loopt.out" 2>&1 ); grep -q 'done 1000$' "$W/loopt.out" || { echo "REFUSED(2): the traced loop twin did not print its line: $(tail -1 "$W/loopt.out")"; exit 2; }
hits() { ( cd "$W" && timeout -k 5 300 gdb -q -batch -ex 'set breakpoint pending on' -ex "break $1" -ex 'ignore 1 100000000' -ex 'run < /dev/null > /dev/null 2>&1' -ex 'info breakpoints' ./$2 2>&1 | grep -o 'already hit [0-9]* time' | grep -o '[0-9]*' | head -1 ); }
h2=$(hits rt_proc_call_prologue loop.bin); h2=${h2:-0}
if [ "$h2" -le 100 ]; then echo "ok  (2) rt_proc_call_prologue hits=$h2 over 1,001 deferred calls made at the top level: the thunk opens by the registry word"
else echo "RED (2) rt_proc_call_prologue hits=$h2 over 1,001 deferred calls made at the top level: a thunk open walks the by-name prologue road again"; red=1; fi
h3=$(hits rt_proc_call_prologue loopn.bin); h3=${h3:-0}
if [ "$h3" -le 100 ]; then echo "ok  (3) rt_proc_call_prologue hits=$h3 over 1,001 deferred calls made from inside a function with a DATA type live"
else echo "RED (3) rt_proc_call_prologue hits=$h3 over 1,001 deferred calls made from inside a function: the thunk open walks the by-name prologue road again"; red=1; fi
h4=$(hits rt_proc_call_prologue loopt.bin); h4=${h4:-0}
if [ "$h4" -ge 1000 ]; then echo "ok  (4) rt_proc_call_prologue hits=$h4 over 1,001 deferred calls under &FTRACE: a traced thunk open keeps its old road and its trace event"
else echo "RED (4) rt_proc_call_prologue hits=$h4 over 1,001 deferred calls under &FTRACE: the fast open skips a trace layer that is armed"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: a deferred call opens its thunk by the registry word and a traced one keeps its prologue"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1

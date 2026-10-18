#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_a_deferred_call_capture_finds_its_procedure_once.sh -- A `pattern . *f` CAPTURE USED TO LOOK ITS PROCEDURE UP TWICE:
# rt_proc_is_registered(f) in the pump and then rt_call_open_by_name(f) inside rt_dcap_call_prepare, each an rt_proc_find (a
# pointer-keyed cache confirmed by strcmp, ~105 Ir at -O0) -- and the slim and dynamic call prologues strcmp'd every parameter name
# against the result name on EVERY call to learn whether the result is shadowed. The calculator demo makes 107,868 such captures
# (ceo 2026-09-25, CEO-1257; notebook section 17). Since this landing rt_dcap_call_prepare finds once and reports registration,
# rt_call_open_by_name_p takes the procedure it was handed, and the shadow fact is computed once per procedure in
# rt_proc_resolve_cells (bit 1 of cells_done -- the record is pinned at 128 bytes so the fact rides in a bit).
# ARMS: (1) the witness (a shadowed result name, a plain function, name-returning deferred calls `. *h()` and `. *m()`, an
# unregistered plain star target, two star calls in one match, 5,000 star calls in a loop) prints the oracle's lines in m3 and
# m4; (2) gdb counts rt_proc_find hits over the run: at most 5,300 for 5,002 deferred calls (pre-cure: two per call).
# FAIL_ONCE (recorded): the pre-cure runtime at 71f47a9b1 read 10,028 hits; this tree reads 5,024.
# EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle, gdb or the build missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
command -v gdb >/dev/null 2>&1 || { echo "REFUSED(2): gdb missing -- arm 2 is a breakpoint hit count"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/star.sno" <<'SNO'
        DEFINE('f(f)')                                  :(f_end)
f       f = f * 2                                       :(RETURN)
f_end
        DEFINE('g(a,b)t')                               :(g_end)
g       t = a b
        g = t t                                         :(RETURN)
g_end
        DEFINE('h()')                                   :(h_end)
h       h = .hv                                         :(NRETURN)
h_end
        DEFINE('m()')                                   :(m_end)
m       cnt = cnt + 1
        m = .mv                                         :(NRETURN)
m_end
        OUTPUT = f(21) ' ' g('ab', 'c') ' ' f(f(1))
        s = 'hello world'
        s 'hello' . *h()                                :S(ok1)
        OUTPUT = 'no match'                             :(n1)
ok1     OUTPUT = 'after star h(): ' hv
n1      s 'world' . *unreg                              :S(ok2)
        OUTPUT = 'no match 2'                           :(n2)
ok2     OUTPUT = 'after star unreg: ' unreg
n2      s ('hel' 'lo') . *m() ' ' . *h()                :S(ok3)
        OUTPUT = 'no match 3'                           :(n3)
ok3     OUTPUT = 'after two stars: ' mv '/' hv '/' cnt
n3      i = 0
loop    s 'hello' . *m()
        i = LT(i, 5000) i + 1                           :S(loop)
        OUTPUT = 'loop done ' i ' ' mv ' ' cnt
END
SNO
"$SBL" $(sbl_lang_flags) "$W/star.sno" < /dev/null > "$W/star.ref" 2>&1 || true
[ -s "$W/star.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the witness"; exit 2; }
red=0
( cd "$W" && timeout -k 5 30 "$ROOT/scrip" star.sno < /dev/null > "$W/star.m3" 2>&1 ); cmp -s "$W/star.m3" "$W/star.ref" && echo "ok  (1) m3 = oracle" || { echo "RED (1) m3 differs from the oracle:"; diff "$W/star.ref" "$W/star.m3" | head -6; red=1; }
( cd "$W" && "$ROOT/scrip" --compile -o "$W/star.s" star.sno < /dev/null > /dev/null 2>&1 && gcc "$W/star.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/star.bin" 2>/dev/null ) || { echo "REFUSED(2): the witness did not build in mode 4"; exit 2; }
( cd "$W" && timeout -k 5 30 ./star.bin < /dev/null > "$W/star.m4" 2>&1 ); cmp -s "$W/star.m4" "$W/star.ref" && echo "ok  (1) m4 = oracle" || { echo "RED (1) m4 differs from the oracle:"; diff "$W/star.ref" "$W/star.m4" | head -6; red=1; }
hits=$( cd "$W" && timeout -k 5 300 gdb -q -batch -ex 'set breakpoint pending on' -ex 'break rt_proc_find' -ex 'ignore 1 100000000' -ex 'run < /dev/null > /dev/null 2>&1' -ex 'info breakpoints' ./star.bin 2>&1 | grep -o 'already hit [0-9]* time' | grep -o '[0-9]*' | head -1 )
[ -n "$hits" ] || { echo "REFUSED(2): gdb did not report a hit count for rt_proc_find"; exit 2; }
if [ "$hits" -le 5300 ]; then echo "ok  (2) rt_proc_find hits=$hits <= 5300 over 5,002 deferred calls: one lookup per call"
else echo "RED (2) rt_proc_find hits=$hits > 5300 over 5,002 deferred calls: the capture looks its procedure up twice again"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: a deferred-call capture finds its procedure once and the shadow fact is a per-procedure bit"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1

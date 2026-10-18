#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_a_compiled_program_runs_on_a_stack_it_maps_itself.sh -- A MODE-4 PROGRAM RUNS ON A STACK THE RUNTIME MAPS FOR IT, 2 MB
# ALIGNED AND HUGE-PAGE ADVISED, NOT ON THE PROCESS STACK (ceo 2026-09-25, CEO-1265; Lon 2026-09-25 10:06, in-chat to the ceo:
# "continue getting all demos and benchmarks running faster than SPITBOL"). The process stack grows down a 4 KB page at a time and can
# never take a transparent huge page; the calculator demo touched 48 MB of it in 12,312 faults, two thirds of its run. The emitted main
# calls rt_main_stack_adopt first (the -s budget rounded up to 2 MB, MADV_HUGEPAGE, a PROT_NONE guard page below) and moves rsp there.
# ARMS: (1) at a runtime call inside main, rsp lies in an anonymous mapping that is not [stack] and is THPeligible (gdb and the
# inferior's own smaps); (2) a match that keeps ~15 MB of stack for its whole subject, at -s64m, takes at most 2,500 minor faults and
# answers the oracle; (3) unbounded recursion at the default stack is ERROR 246 on the adopted region's guard, rc 1; (4) a recursion
# 3,000 deep that allocates at every level answers the oracle under SCRIP_GC_STRESS=1 -- the collector walks the adopted stack.
# FAIL_ONCE (recorded): on the pre-adoption runtime at dd6d5c96b arm 1 reads rsp in [stack] and arm 2 4,298 faults; this tree reads an
# anonymous THPeligible mapping and 710. EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle, gdb, a kernel with huge pages off).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
command -v gdb >/dev/null 2>&1 || { echo "REFUSED(2): gdb missing -- arm 1 reads rsp at a breakpoint"; exit 2; }
case "$(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null)" in *"[never]"*|"") echo "REFUSED(2): transparent huge pages are off on this kernel -- arm 2's bound is a huge-page measurement"; exit 2;; esac
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/deep.sno" <<'SNO'
        src = DUPL('ab' CHAR(10), 40000)
        W = SPAN('ab')
        X = W | '(' *X ')'
        C = POS(0) ARBNO(X CHAR(10) FENCE) RPOS(0)
        src C                                           :F(bad)
        OUTPUT = 'ok ' SIZE(src)                        :(END)
bad     OUTPUT = 'Boo!'
END
SNO
cat > "$W/rec.sno" <<'SNO'
        DEFINE('R(N)')                                  :(REND)
R       R = R(N + 1)                                    :(RETURN)
REND    R(1)
END
SNO
cat > "$W/gcdeep.sno" <<'SNO'
        DEFINE('R(N)S')                                 :(REND)
R       S = DUPL('x', 50) N
        R = LT(N, 3000) R(N + 1)                        :S(RD)
        R = SIZE(S)                                     :(RETURN)
RD      R = R + SIZE(S)                                 :(RETURN)
REND    OUTPUT = R(1)
END
SNO
for p in deep rec gcdeep; do ( cd "$W" && "$ROOT/scrip" --compile -o $p.s $p.sno < /dev/null > /dev/null 2>&1 && gcc $p.s -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o $p.bin 2>/dev/null ) || { echo "REFUSED(2): $p.sno did not build in mode 4"; exit 2; }; done
red=0
cat > "$W/rsp.py" <<'PY'
import gdb
pid = gdb.selected_inferior().pid
sp = int(gdb.parse_and_eval("$rsp"))
cur = None; hit = None
for l in open("/proc/%d/smaps" % pid).read().split("\n"):
    f = l.split()
    if f and len(f[0].split("-")) == 2 and all(c in "0123456789abcdef-" for c in f[0]):
        lo, hi = [int(x, 16) for x in f[0].split("-")]
        cur = (lo, hi, f[5] if len(f) > 5 else "")
    elif f and f[0] == "THPeligible:" and cur and cur[0] <= sp < cur[1]:
        hit = (cur, f[1])
print("RSPMAP %s lo=%x hi=%x name=[%s] THPeligible=%s" % ("found" if hit else "none", hit[0][0] if hit else 0, hit[0][1] if hit else 0, hit[0][2] if hit else "", hit[1] if hit else "?"))
PY
m="$( cd "$W" && timeout -k 5 120 gdb -q -batch -ex 'set breakpoint pending on' -ex 'break rt_main_args_stage_argv' -ex 'run < /dev/null > /dev/null 2>&1' -ex "source $W/rsp.py" ./rec.bin 2>&1 | grep -m1 '^RSPMAP' )"
[ -n "$m" ] || { echo "REFUSED(2): gdb printed no RSPMAP line -- the breakpoint or the smaps read did not happen"; exit 2; }
case "$m" in *"RSPMAP found"*"name=[]"*"THPeligible=1"*) echo "ok  (1) main runs on an anonymous, huge-page-eligible stack it mapped: $m";;
  *) echo "RED (1) main's stack is not the adopted one: $m"; red=1;; esac
ref="$( cd "$W" && "$SBL" $(sbl_lang_flags) deep.sno < /dev/null 2>/dev/null )"; [ -n "$ref" ] || { echo "REFUSED(2): the oracle printed nothing for deep.sno"; exit 2; }
r="$( cd "$W" && { /usr/bin/time -f 'FAULTS %R' ./deep.bin -s64m < /dev/null > deep.out; } 2>&1 | grep -m1 '^FAULTS' | grep -oE '[0-9]+' )"; [ -n "$r" ] || { echo "REFUSED(2): /usr/bin/time printed no fault count"; exit 2; }
if [ "$(cat "$W/deep.out")" = "$ref" ] && [ "$r" -le 2500 ]; then echo "ok  (2) a match keeping ~15 MB of stack takes $r minor faults at -s64m (bound 2,500) and answers the oracle"
else echo "RED (2) the deep-stack match took $r minor faults at -s64m (bound 2,500) and printed [$(cat "$W/deep.out")] against [$ref]"; red=1; fi
o="$( cd "$W" && timeout -k 5 60 ./rec.bin < /dev/null 2>&1 )"; rc=$?
case "$o" in *"ERROR 246"*) [ "$rc" -eq 1 ] && echo "ok  (3) unbounded recursion at the default stack is ERROR 246, rc 1" || { echo "RED (3) ERROR 246 printed with rc $rc"; red=1; };;
  *) echo "RED (3) unbounded recursion did not end in ERROR 246 (rc $rc): $(echo "$o" | head -2 | tr '\n' ' ')"; red=1;; esac
gref="$( cd "$W" && "$SBL" $(sbl_lang_flags) gcdeep.sno < /dev/null 2>/dev/null )"
g="$( cd "$W" && env -u SCRIP_HEAP_MB -u SCRIP_HEAP_KB SCRIP_GC_STRESS=1 timeout -k 5 120 ./gcdeep.bin < /dev/null 2>/dev/null )"
[ -n "$gref" ] && [ "$g" = "$gref" ] && echo "ok  (4) a 3,000-deep allocating recursion answers the oracle under SCRIP_GC_STRESS=1 ($g)" || { echo "RED (4) the allocating recursion under stress printed [$g] against [$gref]"; red=1; }
[ "$red" -eq 0 ] && { echo "GATE OK: a compiled program runs on a stack it maps itself"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1

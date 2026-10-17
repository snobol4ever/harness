#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_the_default_stack_and_heap_are_spitbols.sh -- LON'S WORDS OF 2026-09-25, HELD BY MECHANISM (ceo CEO-1261), verbatim, in-chat to
# the ceo: "Let's set our default stack size and heap size for SCRIP to be the same as SPITBOL." and "Ensure that all the test suite
# programs have the stack size and heap size setting placed into the per-program attribute files."
# SPITBOL prints its own defaults on its usage screen: "option defaults: -F -d128m -i1m -m16m -s4m" -- a 128 MB maximum heap, a 1 MB
# initial heap that is also the enlarge amount, a 4 MB stack. SCRIP's are GC_HEAP_CAP_KB and GC_HEAP_KB in gc_heap.c and
# RT_STACK_DEFAULT_BYTES in rt_stack_overflow.c; a program's stack budget counts from where the program starts, and mode 3 adds the
# trampoline's reservation for the top-level slot region above it (RT_OUTER_RESERVE, scrip.c), so both modes give the program 4 MB.
# ARMS: (1) the three numbers SPITBOL prints equal SCRIP's three compiled constants -- read from the oracle and from source, never
# repeated here; (2) a running program reports the 1 MB window and the 128 MB cap in m3 and m4 (SCRIP_ZETA_TELEM's [ZHP] line);
# (3) a 20,000-deep recursion answers in m3 and m4 at the default, as SPITBOL does at its default, and a 200,000-deep one stops with
# ERROR 246 in both modes at the default, as SPITBOL does, and answers with -s256m in both; (4) every row of every test-suite attribute
# file (corpus tests/*/ALL.csv and packages/*/*/ALL.csv) carries a numeric heap_kb and stack_kb.
# FAIL_ONCE (recorded): the pre-landing runtime at 80ee6bb5c read arena=128KB cap=4096KB, ran the 200,000-deep recursion on its 64 MB
# floor, and 11,991 attribute rows carried no settings. EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle, corpus or build missing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SBL=/home/resources/spitbol-bench-oracle/sbl; [ -x "$SBL" ] || { echo "REFUSED(2): the SPITBOL oracle $SBL is missing"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
red=0
defs=$("$SBL" -h 2>&1 | grep -o 'option defaults:.*' | head -1)
[ -n "$defs" ] || { echo "REFUSED(2): SPITBOL printed no 'option defaults:' line"; exit 2; }
kb() { case "$1" in *m) echo $(( ${1%m} * 1024 ));; *k) echo "${1%k}";; *) echo $(( $1 / 1024 ));; esac; }
sd=$(kb "$(echo "$defs" | grep -o ' -d[0-9]*[km]*' | sed 's/ -d//')"); si=$(kb "$(echo "$defs" | grep -o ' -i[0-9]*[km]*' | sed 's/ -i//')"); ss=$(kb "$(echo "$defs" | grep -o ' -s[0-9]*[km]*' | sed 's/ -s//')")
cap=$(sed -n 's/^#define[[:space:]]\+GC_HEAP_CAP_KB[[:space:]]\+\([0-9]\+\).*/\1/p' "$ROOT/src/runtime/rt/gc_heap.c" | head -1)
win=$(sed -n 's/^#define[[:space:]]\+GC_HEAP_KB[[:space:]]\+\([0-9]\+\).*/\1/p' "$ROOT/src/runtime/rt/gc_heap.c" | head -1)
stk=$(sed -n 's/^#define[[:space:]]\+RT_STACK_DEFAULT_BYTES[[:space:]]\+(\([0-9]\+\)L \* 1024L \* 1024L).*/\1/p' "$ROOT/src/runtime/rt/rt_stack_overflow.c" | head -1)
[ -n "$cap" ] && [ -n "$win" ] || { echo "REFUSED(2): could not read GC_HEAP_CAP_KB / GC_HEAP_KB out of gc_heap.c"; exit 2; }
if [ -n "$stk" ]; then stk=$(( stk * 1024 )); else stk="none (no compiled RT_STACK_DEFAULT_BYTES)"; fi
if [ "$cap" = "$sd" ] && [ "$win" = "$si" ] && [ "$stk" = "$ss" ]; then echo "ok  (1) SPITBOL prints -d${sd}k -i${si}k -s${ss}k and SCRIP compiles GC_HEAP_CAP_KB=$cap GC_HEAP_KB=$win RT_STACK_DEFAULT=${stk}k"
else echo "RED (1) SPITBOL's defaults -d${sd}k -i${si}k -s${ss}k differ from SCRIP's GC_HEAP_CAP_KB=$cap GC_HEAP_KB=$win RT_STACK_DEFAULT=${stk}k"; red=1; fi
printf "        OUTPUT = 'hello'\nEND\n" > "$W/h.sno"
( cd "$W" && "$ROOT/scrip" --compile -o h.s h.sno < /dev/null > /dev/null 2>&1 && gcc h.s -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o h.bin 2>/dev/null ) || { echo "REFUSED(2): hello did not build in mode 4"; exit 2; }
r3=$( cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB SCRIP_ZETA_TELEM=1 timeout -k 5 20 "$ROOT/scrip" h.sno < /dev/null 2>&1 | grep -o 'arena=[0-9]*KB\|cap=[0-9]*KB' | tr '\n' ' ')
r4=$( cd "$W" && env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB SCRIP_ZETA_TELEM=1 timeout -k 5 20 ./h.bin < /dev/null 2>&1 | grep -o 'arena=[0-9]*KB\|cap=[0-9]*KB' | tr '\n' ' ')
want="arena=${si}KB cap=${sd}KB "
if [ "$r3" = "$want" ] && [ "$r4" = "$want" ]; then echo "ok  (2) a running program reports ${want% } in m3 and m4"
else echo "RED (2) the running heap is not SPITBOL's: m3 [$r3] m4 [$r4], wanted [$want]"; red=1; fi
for d in 20000 200000; do cat > "$W/d$d.sno" <<SNO
        DEFINE('r(n)')                                  :(r_end)
r       r = EQ(n, 0) 0                                  :S(RETURN)
        r = r(n - 1) + 1                                :(RETURN)
r_end
        OUTPUT = r($d)
END
SNO
( cd "$W" && "$ROOT/scrip" --compile -o d$d.s d$d.sno < /dev/null > /dev/null 2>&1 && gcc d$d.s -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o d$d.bin 2>/dev/null ) || { echo "REFUSED(2): the recursion witness $d did not build"; exit 2; }
done
ok20=$( cd "$W" && env -u SCRIP_STACK timeout -k 5 30 "$ROOT/scrip" d20000.sno < /dev/null 2>/dev/null; env -u SCRIP_STACK timeout -k 5 30 ./d20000.bin < /dev/null 2>/dev/null; timeout -k 5 30 "$SBL" -bf d20000.sno < /dev/null 2>/dev/null | head -1 )
of3=$( cd "$W" && env -u SCRIP_STACK timeout -k 5 30 "$ROOT/scrip" d200000.sno < /dev/null 2>&1 | grep -c 'ERROR 246' ); of4=$( cd "$W" && env -u SCRIP_STACK timeout -k 5 30 ./d200000.bin < /dev/null 2>&1 | grep -c 'ERROR 246' ); ofs=$( cd "$W" && timeout -k 5 30 "$SBL" -bf d200000.sno < /dev/null 2>&1 | grep -c 'ERROR 246' )
big=$( cd "$W" && timeout -k 5 60 "$ROOT/scrip" -s256m d200000.sno < /dev/null 2>/dev/null; timeout -k 5 60 ./d200000.bin -s256m < /dev/null 2>/dev/null )
if [ "$(echo $ok20)" = "20000 20000 20000" ] && [ "$of3" -ge 1 ] && [ "$of4" -ge 1 ] && [ "$ofs" -ge 1 ] && [ "$(echo $big)" = "200000 200000" ]; then echo "ok  (3) 20,000 deep answers in m3, m4 and SPITBOL at the defaults; 200,000 deep stops with ERROR 246 in m3, m4 and SPITBOL at the defaults and answers in m3 and m4 with -s256m"
else echo "RED (3) the stack limit is not SPITBOL's: 20,000 deep m3/m4/sbl [$(echo $ok20)], 200,000 deep ERROR 246 m3=$of3 m4=$of4 sbl=$ofs, with -s256m m3/m4 [$(echo $big)]"; red=1; fi
miss=$(python3 - "$S4E/corpus" <<'PY'
import csv, glob, os, sys
root = sys.argv[1]; bad = []; n = 0
for f in sorted(glob.glob(os.path.join(root, 'tests/*/ALL.csv')) + glob.glob(os.path.join(root, 'packages/*/*/ALL.csv'))):
    with open(f, newline='', encoding='utf-8') as fh:
        rd = csv.DictReader(fh)
        if 'heap_kb' not in (rd.fieldnames or []) or 'stack_kb' not in (rd.fieldnames or []):
            bad.append(os.path.relpath(f, root) + ':no-columns'); continue
        for i, r in enumerate(rd, 2):
            n += 1
            if not (r.get('heap_kb') or '').strip().isdigit() or not (r.get('stack_kb') or '').strip().isdigit():
                bad.append('%s:%d' % (os.path.relpath(f, root), i))
print(n, len(bad), ' '.join(bad[:6]))
PY
)
set -- $miss; rows=$1; nbad=$2; shift 2
[ "${rows:-0}" -gt 0 ] || { echo "REFUSED(2): no attribute rows found under $S4E/corpus"; exit 2; }
if [ "$nbad" = 0 ]; then echo "ok  (4) all $rows rows of the test-suite attribute files carry a numeric heap_kb and stack_kb"
else echo "RED (4) $nbad of $rows attribute rows carry no numeric heap_kb/stack_kb: $*"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: SCRIP's default stack and heap are SPITBOL's, both modes honour them, and every test program declares its settings"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1

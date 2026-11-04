#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 1
../harness/scripts/util_require_fresh.sh --gate "$(basename "$0" .sh)" || exit $?
# test_gate_icon_procedure_registry_rides_the_module_table_not_startup_calls.sh -- AN ICON PROGRAM'S PROCEDURE REGISTRY IS STATIC DATA THE COMPILER EMITS AND ONE CALL INSTALLS BY POINTER, NOT ONE RUNTIME
# CALL PER PROCEDURE (row icon-the-startup-rebuilds-compile-time-tables-procedures-csets-globals-registered-by-c-calls-at-run-time-r-1969, slice 2).
# ⛔ THE MEASURED DEFECT: module_init called rt_proc_register_rec once per procedure (and rt_proc_set_gen_region_ft / rt_proc_set_frame after it), and each call built an rt_proc_t in a growable array
# (rt_gen_proc_grow, the first call allocating the table) and inserted the name into the FNV hash (proc_hsl, a 1024-slot table allocated on the first insert). The compiler already held every field, so it emits
# them: .Lstartup_procs (128-byte rt_proc_t rows, the root "main" row last) and .Lstartup_phash (the open-addressed int table, built with the runtime's own rt_proc_hash_fill so the probe agrees), each behind a
# 16-byte rt_hblk_t header so a later rt_gcheap_grow_block copies the block into the collected heap, and ONE call, rt_procs_install(rows, n, hash, cap), points g_runtime.abi.rt_gen_procs and proc_hsl at them.
# A module whose procedures are not all plain (a DEFINE scope, a thunk, a Prolog dcfn, a skipped slot, a repeated name) keeps rt_proc_register_rec; the decision is the driver's, from the records.
# FOUR ARMS. STATIC: every Icon benchmark in mode 4 has no call to rt_proc_register_rec, exactly ONE rt_procs_install, and tables that parse: the rt_hblk_t granule counts equal 16 plus the payload over 16, the row count
# agrees with the install call's n, and an independent FNV-1a probe finds every procedure's name at its own row (the root last). BEHAVIOURAL: a witness with variadic, generator, recursive, static-local and
# 60 plain procedures run in BOTH modes byte-equal to the oracle (Arizona icont 9.5.25a), including proc("name") and a string invocation, the oracle's output carrying the lines compared. GROW (gdb on the
# mode-4 tgrlink, stopped before main): 200 rt_proc_register calls past the static block leave every original and added name findable (count, lookup and the block moved into the heap). FALLBACK (the
# same session): rt_proc_reset then rt_procs_install of a copy of the rows re-registers them through rt_proc_register_rec and every row, gen_region_ft and frame fields included, reads as before.
# FAIL-ONCE: the STATIC arm is red on SCRIP cfe269557 (71 emitted rt_proc_register_rec calls over the 17 benchmarks, no install). No plant anywhere in src/.
# Board line: ICON_PROC_REGISTRY_BOARD programs=<p> register_rec_calls=<n> installs=<i> tables=<ok|bad> m3=<same|differs> m4=<same|differs> grow=<ok|bad> fallback=<ok|bad> (tree <hash>)
# rc 0 all arms green · rc 1 an arm red, named · rc 2 cannot measure (no oracle, no corpus benchmarks, no gdb, a program did not compile, a witness did not build).
NAME=icon_procedure_registry_rides_the_module_table_not_startup_calls
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(pwd)"
refuse() { echo "⛔ GATE REFUSE(2) [$NAME]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "cannot source lib_oracle_flags.sh"
ICONT="$(icont_bin)" || refuse "no icont oracle (lib_oracle_flags icont_bin) -- a missing oracle prints a full, plausible, entirely false all-FAIL table"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so missing -- run make"
command -v gdb >/dev/null 2>&1 || refuse "no gdb -- the GROW and FALLBACK arms drive the running registry"
BENCH="$ROOT/../corpus/benchmarks/icon"
ls "$BENCH"/*.icn >/dev/null 2>&1 || refuse "no Icon benchmarks at $BENCH (a sparse corpus needs benchmarks/icon)"
[ -f "$BENCH/tgrlink.icn" ] || refuse "no tgrlink.icn benchmark -- the GROW and FALLBACK arms need a program with generator regions"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/tables.py" <<'EOS'
import re, sys
def fnv(s):
    h = 2166136261
    for c in s.encode('utf-8'):
        h = ((h ^ c) * 16777619) & 0xffffffff
    return h
def bytes_of(ln):
    t = ln.split()
    return {'.quad': 8, '.long': 4, '.short': 2}.get(t[0], 0) if t else 0
src = open(sys.argv[1], encoding='utf-8', errors='replace').read().split('\n')
st = [l.strip() for l in src]
names = {}
for l in src:
    m = re.match(r'^\s*(\.Lstartup_pname\d+|\.Lstartup_rootcall):\s+\.string\s+"(.*)"\s*$', l)
    if m: names[m.group(1)] = m.group(2)
try:
    ip = next(i for i, l in enumerate(st) if l == '.Lstartup_procs:')
    ih = next(i for i, l in enumerate(st) if l == '.Lstartup_phash:')
except StopIteration:
    print('BAD no .Lstartup_procs or .Lstartup_phash label'); sys.exit(0)
def header(i):
    a = [x.split() for x in st[i - 3:i]]
    if a[0][0] != '.long' or a[1][0] != '.short' or a[2][:2] != ['.short', '0']: return None
    return int(a[0][1]), int(a[1][1])
hp, hh = header(ip), header(ih)
if not hp or not hh: print('BAD a block header is not .long gran / .short type / .short 0'); sys.exit(0)
j = ip + 1; body = []
while j < ih and st[j].split()[:2] != ['.balign', '16']:
    if st[j].startswith(('.quad', '.long')): body.append(st[j])
    j += 1
nb = sum(bytes_of(l) for l in body)
if nb % 128: print('BAD the rows are %d bytes, not a multiple of 128' % nb); sys.exit(0)
n = nb // 128
if hp[0] != (16 + 128 * n) // 16: print('BAD procs header granules %d, want %d' % (hp[0], (16 + 128 * n) // 16)); sys.exit(0)
slots = []
k = ih + 1
while k < len(st) and st[k].startswith('.long'):
    slots.append(int(st[k].split()[1])); k += 1
cap = len(slots)
if cap & (cap - 1) or cap < 8 or hh[0] != (16 + 4 * cap) // 16 or (n + 1) * 4 >= cap * 3: print('BAD hash cap %d header %d rows %d' % (cap, hh[0], n)); sys.exit(0)
if sum(1 for v in slots if v) != n or any(v < 0 or v > n for v in slots): print('BAD the hash holds %d nonzero slots for %d rows' % (sum(1 for v in slots if v), n)); sys.exit(0)
text = '\n'.join(src)
m = re.search(r'mov\s+esi,\s*(\d+)\s*\n\s*lea\s+rdx,\s*\[rip\s*\+\s*\.Lstartup_phash\]\s*\n\s*mov\s+ecx,\s*(\d+)\s*\n\s*call\s+rt_procs_install@PLT', text)
if not m or int(m.group(1)) != n or int(m.group(2)) != cap: print('BAD the install call does not say n=%d cap=%d' % (n, cap)); sys.exit(0)
labels = [body[r * 25].split()[1] for r in range(n)]
for r in range(n):
    nm = names.get(labels[r])
    if nm is None: print('BAD row %d name label %s has no .string' % (r, labels[r])); sys.exit(0)
    h = fnv(nm) & (cap - 1); steps = 0
    while slots[h] and slots[h] - 1 != r and steps <= cap: h = (h + 1) & (cap - 1); steps += 1
    if slots[h] - 1 != r: print('BAD the FNV probe of %s does not reach row %d' % (nm, r)); sys.exit(0)
if '.Lstartup_rootcall' in labels and labels[-1] != '.Lstartup_rootcall': print('BAD the root row is not last'); sys.exit(0)
print('ok rows=%d cap=%d' % (n, cap))
EOS
bad=0; progs=0; regrec=0; installs=0; tabs=ok
for f in "$BENCH"/*.icn; do
    timeout -k 5 120 ./scrip --compile --out="$W/b.s" "$f" < /dev/null >/dev/null 2>&1 || refuse "$(basename "$f") did not compile in mode 4 -- the count would not cover the population"
    progs=$((progs + 1))
    n=$(grep -cE 'call[[:space:]]+(qword ptr \[rip \+ )?rt_proc_register_rec\b' "$W/b.s"); regrec=$((regrec + n))
    n=$(grep -cE 'call[[:space:]]+(qword ptr \[rip \+ )?rt_procs_install\b' "$W/b.s"); installs=$((installs + n))
    r=$(python3 -I "$W/tables.py" "$W/b.s" 2>&1)
    case "$r" in ok*) ;; *) tabs=bad; bad=1; echo "  STATIC RED: $(basename "$f"): $r";; esac
done
if [ "$regrec" -ne 0 ]; then echo "  STATIC RED: $regrec emitted call(s) to rt_proc_register_rec over $progs Icon benchmarks -- the rows must be the static .Lstartup_procs array"; bad=1; fi
if [ "$installs" -ne "$progs" ]; then echo "  STATIC RED: $installs rt_procs_install call(s) over $progs Icon benchmarks -- want exactly one per program, never one per procedure"; bad=1; fi
{
    echo 'record pt(x, y)'
    echo 'global g1, g2'
    echo 'procedure vsum(a[]);'; echo 'local s, e;'; echo 's := 0;'; echo 'every e := !a do s +:= e;'; echo 'return s;'; echo 'end'
    echo 'procedure gen3(n);'; echo 'local i;'; echo 'every i := 1 to n do suspend i * i;'; echo 'end'
    echo 'procedure rec(n);'; echo 'if n <= 0 then return 0;'; echo 'return n + rec(n - 1);'; echo 'end'
    echo 'procedure noargs();'; echo 'static k;'; echo 'initial k := 0;'; echo 'k +:= 1;'; echo 'return k;'; echo 'end'
    for i in $(seq 1 60); do printf 'procedure p%d(x);\nreturn x + %d;\nend\n' "$i" "$i"; done
    echo 'procedure main(args);'; echo 'local p, r, t, i, f, L;'; echo 'g1 := 5; g2 := "s"; t := 0;'
    printf 'L := ['; for i in $(seq 1 59); do printf 'p%d, ' "$i"; done; echo 'p60];'
    echo 'write(vsum(1, 2, 3, 4));'; echo 'every write(gen3(4));'; echo 'write(rec(10));'; echo 'write(noargs(), noargs(), noargs());'
    echo 'write(image(proc("vsum")), " ", image(proc("nosuch")));'; echo 'p := proc("rec");'; echo 'write(p(5));'; echo 'r := ("vs" || "um")(10, 20);'; echo 'write(r);'
    echo 'every i := 1 to 60 do { f := proc("p" || i); t +:= f(1) };'; echo 'write(t);'; echo 'write(*L, " ", *args);'; echo 'write(image(pt(1, 2)));'; echo 'end'
} > "$W/w.icn"
( cd "$W" && "$ICONT" -s -o oracle_bin w.icn >/dev/null 2>&1 ) || refuse "the oracle did not build the witness"
( cd "$W" && timeout -k 5 60 ./oracle_bin a b < /dev/null > oracle.out 2>&1 )
for k in "10" "30" "1890" "60 2" "record pt_1(2)" "333"; do
    grep -qxF -- "$k" "$W/oracle.out" || refuse "the oracle's output lacks the line [$k]: the comparison would be empty against empty"
done
( cd "$W" && timeout -k 5 120 "$ROOT/scrip" w.icn -- a b < /dev/null > m3.out 2>&1 )
( cd "$W" && timeout -k 5 120 "$ROOT/scrip" --compile --out=w.s w.icn < /dev/null >/dev/null 2>&1 && gcc w.s -o w4 -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) || refuse "the witness did not build in mode 4"
( cd "$W" && timeout -k 5 60 ./w4 a b < /dev/null > m4.out 2>&1 )
m3=same; m4=same
cmp -s "$W/oracle.out" "$W/m3.out" || { m3=differs; bad=1; echo "  BEHAVIOURAL RED: mode 3 differs from the oracle:"; diff "$W/oracle.out" "$W/m3.out" | head -8; }
cmp -s "$W/oracle.out" "$W/m4.out" || { m4=differs; bad=1; echo "  BEHAVIOURAL RED: mode 4 differs from the oracle (a name the hash cannot find fails proc() and the string call):"; diff "$W/oracle.out" "$W/m4.out" | head -8; }
hasins=$(nm -D --defined-only "$ROOT/out/libscrip_rt.so" 2>/dev/null | grep -cE ' rt_procs_install$')
if [ "$hasins" -eq 0 ]; then
    echo "  GROW RED: libscrip_rt.so exports no rt_procs_install -- there is no install to grow past or fall back from"
    echo "ICON_PROC_REGISTRY_BOARD programs=$progs register_rec_calls=$regrec installs=$installs tables=$tabs m3=$m3 m4=$m4 grow=na fallback=na (tree $(git rev-parse --short HEAD))"
    echo "GATE FAIL [$NAME]"; exit 1
fi
timeout -k 5 120 ./scrip --compile --out="$W/t.s" "$BENCH/tgrlink.icn" < /dev/null >/dev/null 2>&1 && gcc "$W/t.s" -o "$W/t4" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 || refuse "tgrlink did not build in mode 4"
cat > "$W/g.gdb" <<'EOS'
set pagination off
set confirm off
set breakpoint pending on
define rows
  set $i = 0
  while $i < g_runtime.rt.rt_gen_proc_count
    set $p = &g_runtime.abi.rt_gen_procs[$i]
    printf "ROW %d %s %lx %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n", $i, $p->name, (long)$p->fn, $p->nparams, $p->nformals, $p->frame_bytes, $p->gen_region_ft, $p->frame_nslots, $p->decl_level, $p->is_generator, $p->jmp_entry, $p->pinned, $p->zstatic, $p->rest_kind, $p->named_rest, $p->is_variadic, (int)rt_proc_index_of($p->name)
    set $i = $i + 1
  end
end
break rt_main_progname_stage
run < /dev/null > /dev/null 2>&1
set $rows0 = (long)g_runtime.abi.rt_gen_procs
set $n0 = g_runtime.rt.rt_gen_proc_count
printf "@@BEFORE\n"
rows
printf "@@END\n"
set $copy = (void*)malloc($n0 * 128)
call (void*)memcpy($copy, g_runtime.abi.rt_gen_procs, $n0 * 128)
call (void)rt_proc_reset()
call (void)rt_procs_install($copy, $n0, 0, 0)
printf "@@AFTER\n"
rows
printf "@@END\n"
set $j = 0
while $j < 200
  set $s = (char*)malloc(16)
  call (int)sprintf($s, "zz%d", $j)
  call (void)rt_proc_register($s, 0, 0)
  set $j = $j + 1
end
set $i = 0
set $badl = 0
while $i < $n0 + 200
  if (int)rt_proc_index_of(g_runtime.abi.rt_gen_procs[$i].name) != $i
    set $badl = $badl + 1
  end
  set $i = $i + 1
end
printf "@@GROW n0=%d count=%d bad=%d moved=%d\n", $n0, g_runtime.rt.rt_gen_proc_count, $badl, (long)g_runtime.abi.rt_gen_procs != $rows0
EOS
timeout -k 5 300 gdb -q -batch -x "$W/g.gdb" "$W/t4" > "$W/g.out" 2>&1
grep -q '^@@GROW' "$W/g.out" || refuse "gdb did not reach the registry (no @@GROW line): $(tail -3 "$W/g.out" | tr '\n' ' ')"
awk '/^@@BEFORE/{f=1;next} /^@@END/{f=0} f' "$W/g.out" > "$W/before.txt"
awk '/^@@AFTER/{f=1;next} /^@@END/{f=0} f' "$W/g.out" > "$W/after.txt"
rowsn=$(grep -c '^ROW ' "$W/before.txt")
[ "$rowsn" -gt 1 ] || refuse "the registry dump has $rowsn row(s) -- the comparison would be empty"
grep -qE '^ROW [0-9]+ [^ ]+ [0-9a-f]+ [0-9]+ [0-9]+ [0-9]+ [1-9][0-9]* ' "$W/before.txt" || refuse "no row carries a gen_region_ft -- tgrlink no longer exercises the folded field"
fb=ok; gr=ok
cmp -s "$W/before.txt" "$W/after.txt" || { fb=bad; bad=1; echo "  FALLBACK RED: the rows differ after rt_proc_reset + rt_procs_install of a copy:"; diff "$W/before.txt" "$W/after.txt" | head -6; }
g=$(grep '^@@GROW' "$W/g.out")
case "$g" in *"count=$((rowsn + 200)) bad=0 moved=1") ;; *) gr=bad; bad=1; echo "  GROW RED: $g (want count=$((rowsn + 200)) bad=0 moved=1)";; esac
echo "ICON_PROC_REGISTRY_BOARD programs=$progs register_rec_calls=$regrec installs=$installs tables=$tabs m3=$m3 m4=$m4 grow=$gr fallback=$fb (tree $(git rev-parse --short HEAD))"
[ "$bad" = 0 ] && { echo "GATE OK [$NAME]: $progs benchmarks carry the procedure registry as data and every lookup, growth and fallback reads it"; exit 0; }
echo "GATE FAIL [$NAME]"; exit 1

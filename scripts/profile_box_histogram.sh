#!/usr/bin/env bash
# profile_box_histogram.sh — THE STANDARD PER-BOX WALL-COST HISTOGRAM (s143).
# Full method + interpretation guide: .github/ARCH-ENGINE.md
#
# Compiles a .sno to mode-4, runs callgrind at INSTRUCTION granularity with
# cache+branch sims, joins instruction addresses against the binary's nm t/T
# labels (every emitted box label IS a symbol in an m4 binary), and prints ONE
# unified histogram: emitted boxes (address-joined, family-rolled) + runtime
# .so / libc functions (fn=-joined), ranked by a WALL cycle proxy.
#
#   cyc-proxy = Ir + 10*(I1mr+D1mr+D1mw) + 100*(ILmr+DLmr+DLmw) + 15*(Bcm+Bim)
#
# TWO LAWS (s143, do not relearn):
#  (1) Ir LIES on rep-string ops — callgrind counts each rep iteration but ERMS
#      microcode fills ~35 cycles/560B: rank by cyc-proxy, never bare Ir.
#  (3) ⛔ NAME-COMPRESSION IS NOT OPTIONAL (s168): callgrind names an object/function ONCE and
#      then back-references it as a bare '(id)'.  In a treebank m4 profile 336 of 659 fn= lines and
#      11 of 13 ob= lines are bare -- and the PROGRAM'S OWN object is named only on a cob= line, so
#      an ob=-name-only parser scores the emitted blob at 0.0% and pins its cycles on whatever
#      unrelated function was last named (measured: 'rt:lookup_malloc_symbol', which is ld.so and
#      never runs hot here).  ob=/cob= and fn=/cfn= ids are resolved through one table below.
#  (2) ABSOLUTE ms drift with host load (byte-identical .so measured 51<->71ms)
#      — this tool RANKS; verify wins with same-moment interleaved A/B only
#      (../harness/scripts/bench_sno_match4.sh protocol).
#
# Usage:  profile_box_histogram.sh prog.sno input [top_n]
# Env:    SCRIP, RT_DIR, SIMS=0 (Ir-only, ~2x faster), GRAN=label (no family rollup)
#         Numbers are RT_OPT-of-libscrip_rt numbers (-O0 unless Lon directed).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"; RT="${RT_DIR:-$HERE/../../SCRIP/out}"
SNO="${1:?usage: profile_box_histogram.sh prog.sno input [top_n]}"; IN="${2:?input file}"; TOPN="${3:-24}"
SIMS="${SIMS:-1}"; GRAN="${GRAN:-family}"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
"$SCRIP" --compile "$SNO" > "$W/p.s" 2>"$W/cc.err" || { echo "COMPILE FAIL"; head -3 "$W/cc.err"; exit 1; }
gcc -no-pie "$W/p.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$W/p.prog" 2>/dev/null || { echo "LINK FAIL"; exit 1; }
SIMFLAGS=""; [ "$SIMS" = "1" ] && SIMFLAGS="--cache-sim=yes --branch-sim=yes"
valgrind --tool=callgrind --dump-instr=yes $SIMFLAGS --main-stacksize=2000000000 \
         --callgrind-out-file="$W/cg.out" "$W/p.prog" < "$IN" > "$W/run.out" 2>/dev/null || { echo "CALLGRIND FAIL"; exit 1; }
echo "program output: $(cat "$W/run.out" | head -2)"
python3 - "$W/cg.out" "$W/p.prog" "$TOPN" "$GRAN" << 'PYEOF'
import re, subprocess, sys, bisect
cg, binary, topn, gran = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
syms = []
for l in subprocess.run(['nm','-n',binary],capture_output=True,text=True).stdout.splitlines():
    p = l.split()
    if len(p) == 3 and p[1] in 'tT': syms.append((int(p[0],16), p[2]))
addrs = [a for a,_ in syms]
ev_names, npos = ['Ir'], 1
for l in open(cg):
    if l.startswith('events:'): ev_names = l.split()[1:]
    if l.startswith('positions:'): npos = len(l.split()) - 1
    if l.startswith('summary:'): break
NEV = len(ev_names)
def idx(n): return ev_names.index(n) if n in ev_names else -1
iIr = idx('Ir'); iL1 = [idx(x) for x in ('I1mr','D1mr','D1mw')]; iLL = [idx(x) for x in ('ILmr','DLmr','DLmw')]; iB = [idx(x) for x in ('Bcm','Bim')]
tot = {}; last = 0; in_prog = True; cur_fn = '?'; skip = False
bname = binary.split('/')[-1]
obnames = {}; fnnames = {}
def idname(rest, table):
    m = re.match(r'^\((\d+)\)\s*(.*)$', rest)
    if not m: return rest.strip()
    i, nm = m.group(1), m.group(2).strip()
    if nm: table[i] = nm
    return table.get(i, '(%s)' % i)
for l in open(cg):
    l = l.rstrip('\n')
    if l.startswith('cob='): idname(l[4:], obnames); continue
    if l.startswith('cfn='): idname(l[4:], fnnames); continue
    if l.startswith('cfi=') or l.startswith('cfl='): continue
    if l.startswith('ob='): in_prog = bname in idname(l[3:], obnames); continue
    if l.startswith('fn='): cur_fn = idname(l[3:], fnnames) or cur_fn; continue
    if l.startswith('calls='): skip = True; continue
    if not l or l[0].isalpha() or l.startswith('#'): continue
    if skip: skip = False; continue
    parts = l.split(); pos = parts[0]
    if pos.startswith('0x'): addr = int(pos,16)
    elif pos == '*': addr = last
    elif pos.startswith('+'): addr = last + int(pos[1:])
    elif pos.startswith('-'): addr = last - int(pos[1:])
    else: continue
    last = addr
    ev = []
    for x in parts[npos:npos+NEV]:
        try: ev.append(int(x))
        except ValueError: ev = None; break
    if not ev: continue
    ev += [0]*(NEV-len(ev))
    if in_prog:
        i = bisect.bisect_right(addrs, addr) - 1
        name = syms[i][1] if i >= 0 else '?blob?'
        if gran == 'family':
            name = re.sub(r'^n\d+_','',name); name = re.sub(r'_n\d+_([^_]+)$',r'_\1',name); name = re.sub(r'(?<=[A-Za-z$])\d+(?=_|$)','',name); name = re.sub(r'\d+$','',name)
    else:
        name = 'rt:' + cur_fn
    a = tot.setdefault(name, [0]*NEV)
    for j,v in enumerate(ev): a[j] += v
def cyc(a):
    c = a[iIr] if iIr >= 0 else 0
    for i in iL1:
        if i >= 0: c += 10*a[i]
    for i in iLL:
        if i >= 0: c += 100*a[i]
    for i in iB:
        if i >= 0: c += 15*a[i]
    return c
rows = sorted(((cyc(a),k,a) for k,a in tot.items()), reverse=True)
g = sum(r[0] for r in rows) or 1
gI = sum(r[2][iIr] for r in rows) or 1
blob = sum(r[0] for r in rows if not r[1].startswith('rt:'))
print(f"cyc-proxy split: emitted boxes {100*blob/g:.1f}%  |  runtime+libc {100*(g-blob)/g:.1f}%   (events: {' '.join(ev_names)})")
hasB = any(i >= 0 for i in iB)
hdr = f"{'cyc-proxy':>14} {'cyc%':>5} {'Ir':>14} {'Ir%':>5}"
if hasB: hdr += f" {'Bcm+Bim':>11} {'D1m':>9} {'DLm':>7}"
print(hdr + "  box-family / rt:function")
for c,k,a in rows[:topn]:
    line = f"{c:>14,} {100*c/g:5.1f} {a[iIr]:>14,} {100*a[iIr]/gI:5.1f}"
    if hasB:
        b = sum(a[i] for i in iB if i >= 0); d1 = sum(a[i] for i in iL1[1:] if i >= 0); dl = sum(a[i] for i in iLL[1:] if i >= 0)
        line += f" {b:>11,} {d1:>9,} {dl:>7,}"
    print(line + f"  {k}")
PYEOF

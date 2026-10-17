#!/bin/bash
# profile_pcsample.sh — wall-clock PC sampling of a SCRIP mode-4 binary at the TRUE 1x workload (RUNG SPD-0a).
# Usage: profile_pcsample.sh <prog-binary> <input-file> [nsamples] [outdir]
# Method (s108): setarch -R pins ASLR so blob addresses repeat across loop-exec iterations; gdb batch attaches
# sample the PC mid-run; SCRIP_BLOB_MAP=1 stderr (BLOBMAP label / BLOBBOX kind lines) from the SAME pinned base
# names each PC. Only loop-exec-at-1x is valid evidence — scaled input samples the asymptotic regime (s108).
set -u
PROG=$(readlink -f "$1"); INP=$(readlink -f "$2"); N=${3:-60}; OUT=${4:-/tmp/pcs-$$}; mkdir -p "$OUT"; : > "$OUT/pcs.txt"
ulimit -s unlimited
( while :; do SCRIP_BLOB_MAP=1 setarch "$(uname -m)" -R "$PROG" < "$INP" > /dev/null 2> "$OUT/map.txt" & echo $! > "$OUT/pid"; wait $! 2>/dev/null; done ) & LOOP=$!
sleep 0.4
for i in $(seq "$N"); do
  P=$(cat "$OUT/pid" 2>/dev/null); [ -n "$P" ] && [ -d "/proc/$P" ] || { sleep 0.03; continue; }
  timeout -k 5 5 gdb -q -p "$P" -batch -ex 'x/i $pc' 2>/dev/null | grep '=>' >> "$OUT/pcs.txt"
  sleep 0.03
done
kill "$LOOP" 2>/dev/null; P=$(cat "$OUT/pid" 2>/dev/null); [ -n "$P" ] && kill -9 "$P" 2>/dev/null
sort "$OUT/pcs.txt" | uniq -c | sort -rn > "$OUT/pc_hist.txt"
grep -aE 'BLOBMAP|BLOBBOX' "$OUT/map.txt" > "$OUT/map_raw.txt" || true
python3 - "$OUT/pc_hist.txt" "$OUT/map_raw.txt" "$PROG" <<'EOF'
import sys, re, subprocess
hist, mapf, prog = sys.argv[1], sys.argv[2], sys.argv[3]
marks = []
for ln in open(mapf, errors="replace"):
    p = ln.split()
    if len(p) >= 3 and p[1].startswith("0x"): marks.append((int(p[1], 16), p[0], " ".join(p[2:])))
marks.sort()
syms = []
try:
    for ln in subprocess.run(["nm", "-C", "--defined-only", prog], capture_output=True, text=True).stdout.splitlines():
        p = ln.split()
        if len(p) == 3 and p[1] in "tT": syms.append((int(p[0], 16), p[2]))
    syms.sort()
except Exception: pass
def lookup(a, tbl, tag):
    best = None
    for m in tbl:
        if m[0] <= a: best = m
        else: break
    if best and a - best[0] < 0x40000: return f"{tag}{best[-1]}+0x{a-best[0]:x}"
    return None
tot = 0; rows = []
for ln in open(hist):
    m = re.match(r"\s*(\d+)\s+=>\s+(0x[0-9a-f]+)", ln)
    if not m: continue
    c, a = int(m.group(1)), int(m.group(2), 16)
    tot += c; rows.append((c, a))
for c, a in rows[:30]:
    nm = lookup(a, marks, "") or lookup(a, [(s, n) for s, n in syms], "C:") or "?"
    print(f"{c:6d} {100*c/max(tot,1):5.1f}%  {hex(a)}  {nm}")
print(f"TOTAL_SAMPLES={tot}")
EOF

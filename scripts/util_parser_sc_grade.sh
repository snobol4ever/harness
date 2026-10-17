#!/usr/bin/env bash
# util_parser_sc_grade.sh LANG LIST CDUMP [OUTDIR] -- grade a bootstrap/parser_<lang>.sc against the C parser's dumps.
# BUILD: the runtime chain and the parser are concatenated, transpiled (scrip --transpile), compiled to a mode-4 binary the
# way util_parser_grid.sh builds the SCRIP engine, cached under OUTDIR (default: the scratchpad) by the parser's mtime.
# GRADE: the binary runs the LIST (one file per line, absolute paths, run from corpus/) with the tree dump on; each file's
# dump is compared to its section of CDUMP, keyed by the full path (three benchmark directories hold a different fib.pl) (the C parser's output over the same list, "== path" headers).  Prints
# PARSER-SC lang=L files=N match=M diff=D fail=F (fail = Parse Error or no section), then the differing files smallest
# first with the two dumps side by side (SC left, C right), capped by SHOW (default 6).  rc 0 all match, 1 otherwise, 2 refused.
set -u
L="${1:-}"; LIST="${2:-}"; CDUMP="${3:-}"; OUT="${4:-/tmp/claude-1000/-home-claude-ceo/fb236173-6673-43de-8e6c-9c0a8fad13e9/scratchpad/scgrade}"
SHOW="${SHOW:-6}"
here=$(cd "$(dirname "$0")" && pwd); W=$(cd "$here/../../SCRIP" && pwd); CORPUS=$(cd "$W/../corpus" 2>/dev/null && pwd); B="$W/bootstrap"
[ -n "$L" ] && [ -f "$B/parser_$L.sc" ] || { echo "PARSER-SC ⛔ REFUSE(2): no bootstrap/parser_$L.sc"; exit 2; }
[ -f "$LIST" ] && [ -f "$CDUMP" ] || { echo "PARSER-SC ⛔ REFUSE(2): LIST and CDUMP must be files"; exit 2; }
mkdir -p "$OUT" || exit 2
CHAIN="$B/global.sc $B/case.sc $B/assign.sc $B/match.sc $B/counter.sc $B/stack.sc $B/tree.sc $B/ShiftReduce.sc $B/tdump.sc $B/gen.sc $B/qize.sc $B/semantic.sc $B/omega.sc $B/trace.sc"
BIN="$OUT/$L.bin"
if [ ! -x "$BIN" ] || [ "$B/parser_$L.sc" -nt "$BIN" ] || [ "$W/scrip" -nt "$BIN" ]; then
    cat $CHAIN "$B/parser_$L.sc" > "$OUT/$L.sc"
    "$W/scrip" --transpile "$OUT/$L.sc" > "$OUT/$L.sno" 2> "$OUT/$L.tr.err" && [ -s "$OUT/$L.sno" ] || { echo "PARSER-SC ⛔ REFUSE(2): transpile failed: $(head -3 "$OUT/$L.tr.err" | cut -c1-300)"; exit 2; }
    "$W/scrip" --compile "$OUT/$L.sno" -o "$OUT/$L.s" < /dev/null > "$OUT/$L.cc.err" 2>&1 || { echo "PARSER-SC ⛔ REFUSE(2): compile failed: $(grep -m3 -i 'error' "$OUT/$L.cc.err" | cut -c1-300)"; exit 2; }
    gcc -m64 -no-pie -rdynamic "$OUT/$L.s" -Wl,-rpath,"$W/out" -L"$W/out" -lscrip_rt -lm -lpthread -o "$BIN" 2>> "$OUT/$L.cc.err" || { echo "PARSER-SC ⛔ REFUSE(2): link failed: $(tail -3 "$OUT/$L.cc.err" | cut -c1-300)"; exit 2; }
fi
# The binary runs at the CHAIN's declared heap and stack (ceo CEO-1353, RULES.md clause 8 (g)(4)), never typed here:
# bootstrap/parser_<lang>.heap and .stack, read by lib_declared_arena.sh and leading the binary's own command line.
. "$here/lib_declared_arena.sh" || { echo "PARSER-SC ⛔ REFUSE(2): cannot load lib_declared_arena.sh"; exit 2; }
SW="$(declared_switches_beside "$B/parser_$L.sc")" || { echo "PARSER-SC ⛔ REFUSE(2): bootstrap/parser_$L's declaration is refused"; exit 2; }
[ -n "$SW" ] || { echo "PARSER-SC ⛔ REFUSE(2): bootstrap/parser_$L.sc declares no heap or stack (parser_$L.heap, .stack)"; exit 2; }
# CHUNK files per process (default 100): the tree gate runs each file alone (Lon 2026-09-28), and a long single run of the mode-4
# binary dies in emitted code once its dead trees pass ~2 GB (the 2026-09-30 witness, any collector window) -- a runtime defect rowed apart
CHUNK="${CHUNK:-1}"; : > "$OUT/$L.sc.dump"; : > "$OUT/$L.sc.err"; rc=0; split -l "$CHUNK" -d -a 4 "$LIST" "$OUT/$L.chunk."
for ck in "$OUT/$L.chunk."*; do
    ( cd "$CORPUS" && PARSER_FILES="$ck" PARSER_TREE_HASH=0 SCRIP_DIAG=0 timeout -k 5 600 "$BIN" $SW < /dev/null >> "$OUT/$L.sc.dump" 2>> "$OUT/$L.sc.err" ); r=$?; [ "$r" -gt "$rc" ] && rc=$r
    # the tree gate's classes, per process: a signal is a CRASH, any other nonzero exit a refusal (with CHUNK=1 the process is the file)
    if [ "$r" -ge 128 ]; then echo "CRASH rc=$r" >> "$OUT/$L.sc.dump"; elif [ "$r" -ne 0 ]; then echo "Parse Error (rc=$r)" >> "$OUT/$L.sc.dump"; fi
    echo >> "$OUT/$L.sc.dump"
done
rm -f "$OUT/$L.chunk."*
python3 - "$L" "$LIST" "$CDUMP" "$OUT/$L.sc.dump" "$SHOW" "$rc" <<'PYEOF'
import sys, re, os
L, LIST, CDUMP, SCDUMP, SHOW, rc = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5]), sys.argv[6]
def sections(path):
    t = open(path, encoding="utf-8", errors="replace").read()
    parts = re.split(r'^== (.*)$', t, flags=re.M); d = {}
    for i in range(1, len(parts), 2): d[parts[i].strip()] = parts[i+1].strip("\n")
    return d
c = sections(CDUMP); s = sections(SCDUMP)
files = [x.strip() for x in open(LIST) if x.strip()]
match = []; diff = []; fail = []; crefused = []; crash = []
for f in files:
    cs = c.get(f); ss = s.get(f)
    if ss is not None and "CRASH rc=" in ss: crash.append(f); continue
    cbad = cs is None or "Parse Error" in cs
    sbad = ss is None or "Parse Error" in (ss or "")
    if cbad and sbad: match.append(f); continue
    if cbad: crefused.append(f); continue
    if sbad: fail.append(f); continue
    (match if cs == ss else diff).append(f)
print(f"PARSER-SC lang={L} files={len(files)} match={len(match)} diff={len(diff)} fail={len(fail)} crash={len(crash)} c_refused={len(crefused)} run_rc={rc}")
if fail: print("FAIL (Parse Error or unparsed): " + " ".join(os.path.basename(x) for x in fail[:40]) + (" ..." if len(fail) > 40 else ""))
if crash: print("CRASH (the .sc binary died on a signal): " + " ".join(os.path.basename(x) for x in crash[:40]) + (" ..." if len(crash) > 40 else ""))
if crefused: print("C-REFUSED (the C parser prints Parse Error, the .sc a tree): " + " ".join(os.path.basename(x) for x in crefused[:20]))
def flat(x): return re.sub(r'\n\s*', ' ', x).replace("(TT_STMT (TT_ATTR :subj ", "(S ")
def toks(x): return flat(x).replace("(", " ( ").replace(")", " ) ").split()
classes = {}
win = {}
for f in diff:
    a, b = toks(s[f]), toks(c[f]); i = 0
    while i < len(a) and i < len(b) and a[i] == b[i]: i += 1
    key = (" ".join(a[i:i+2]) or "<end>", " ".join(b[i:i+2]) or "<end>")
    classes.setdefault(key, []).append(f)
    win[f] = ("SC: " + " ".join(a[max(0,i-6):i+10]), "C : " + " ".join(b[max(0,i-6):i+10]))
print("DIFF CLASSES (first divergence, SC token pair -> C token pair): count, example")
for key, fs in sorted(classes.items(), key=lambda kv: -len(kv[1]))[:24]:
    ex = sorted(fs, key=lambda f: len(c[f]))[0]
    try: exsrc = open(ex, encoding="utf-8").read().strip().replace("\n", " ⏎ ")[:150]
    except Exception: exsrc = "?"
    print(f"  {len(fs):4d}  {key[0]!r:28} -> {key[1]!r:28}  e.g. {os.path.basename(ex)}\n          {exsrc}\n          {win[ex][0][:230]}\n          {win[ex][1][:230]}")
for f in sorted(diff, key=lambda f: len(c[f]))[:SHOW]:
    try: src = open(f, encoding="utf-8").read().strip()
    except Exception: src = "?"
    print("---- DIFF " + f + "\n" + src[:200].replace("\n", " ⏎ ") + "\n" + win[f][0] + "\n" + win[f][1])
sys.exit(0 if not diff and not fail and not crash and not crefused else 1)
PYEOF

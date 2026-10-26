#!/bin/bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ WITNESS GATE for CEO-684 slice 1: AN ACTIVATION FRAME RESERVES ONLY WHAT IT NAMES.  --dump-zeta prints the
# typed per-activation frame layout -- every field with its offset, size and kind -- and the sum of those fields
# must TILE the region [16, region_end).  A byte in the region that no field covers is storage the emitter
# reserved, the collector walks past and no template can address: it costs one stack byte per activation forever
# and buys nothing.
# ⛔ WHY A HOLE IS A DEFECT AND NOT A TUNING MATTER, which is the whole reason this is a blocking gate and not a
# report: the cost is INVISIBLE WHEREVER FRAMES ARE RECLAIMED.  A deterministic call drops its frame at once, so
# an over-reserved frame has never shown up in any benchmark we run; it becomes an UNBOUNDED stack cost at exactly
# the moment a frame is RETAINED behind a live choicepoint, which is the Prolog backtracking case (CEO-683/684).
# Measured on r/1 of a four-variable clause: 41 slots, 688 bytes, of which 7 x 16 = 112 bytes are uncovered.
# ⛔ THE GATE IS A TILING CENSUS, NOT A SIZE PIN, deliberately.  Pinning a byte count would red on every legitimate
# change to what a frame CARRIES and would teach the next seat to bump the number; a tiling census only ever fires
# when the layout reserves something it cannot name, which is never correct.  A NAMED pad field (gate.pad,
# resume.pad, callgen.act pad) is COVERED and therefore fine -- the gate is about unnamed reservation.
# ⛔ EVERY FRONTEND, because the granter is language-blind (zls_grant in src/planner/frame_layout.c) and a per-call
# over-reservation reaches all seven: SNOBOL4, Icon and Prolog witnesses here, each chosen to contain calls with
# different arities, because the suspected formula error scales with the NUMBER OF CALLS and not with their size.
# ⛔ REFUSES rc=2 rather than grading when --dump-zeta yields no parsable graph at all -- a runner that cannot
# measure never prints the success shape.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
cd "$ROOT" || exit 2
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/w.pl" <<'PLEOF'
q(1).
q(2).
r(N) :- N > 0, q(_), N1 is N-1, r(N1).
r(0).
:- initialization(main).
main :- r(5), write(ok), nl.
PLEOF
cat > "$T/w.sno" <<'SNEOF'
    DEFINE('F(A,B)')                                    :(F.end)
F   F = A B REPLACE(A,'ab','AB')                        :(RETURN)
F.end
    OUTPUT = F('abc','def')
    OUTPUT = SIZE(TRIM('  x  ')) DUPL('z',2)
END
SNEOF
cat > "$T/w.icn" <<'ICEOF'
procedure g(a, b);
  return a || b || repl("z", 2);
end
procedure main();
  write(g("abc", "def"));
  write(map("ABC", "ABC", "xyz"));
end
ICEOF
for w in w.pl w.sno w.icn; do timeout -k 5 20s ./scrip --dump-zeta "$T/$w" </dev/null > "$T/$w.zeta" 2>/dev/null; done
python3 - "$T" <<'PYEOF'
import sys, os, re
T = sys.argv[1]
ghdr = re.compile(r"^;\s*graph\s+(\d+)\s+'([^']*)'\s+—\s+slots=(\d+)\s+region_end=(\d+)")
fld  = re.compile(r"^;\s+\+(\d+)\s+(\d+)\s+(\S+)\s+(.*)$")
graphs = 0; holed = 0; hole_bytes = 0; rows = []
for w in ("w.pl", "w.sno", "w.icn"):
    p = os.path.join(T, w + ".zeta")
    if not os.path.exists(p): continue
    cur = None
    for line in open(p, errors="replace"):
        m = ghdr.match(line)
        if m:
            if cur: rows.append(cur)
            cur = {"lang": w, "name": m.group(2), "end": int(m.group(4)), "cov": []}
            continue
        m = fld.match(line)
        if m and cur is not None:
            off = int(m.group(1)); size = int(m.group(2))
            cur["cov"].append((off, off + size))
    if cur: rows.append(cur)
out = []
for r in rows:
    graphs += 1
    if not r["cov"]: continue
    lo = min(a for a, b in r["cov"])
    covered = bytearray(max(0, r["end"] - lo))
    for a, b in r["cov"]:
        for i in range(max(a, lo), min(b, r["end"])): covered[i - lo] = 1
    holes = covered.count(0)
    if holes:
        holed += 1; hole_bytes += holes
        out.append((r["lang"], r["name"][:28], r["end"], holes))
if graphs == 0:
    print("⛔ REFUSE(2): --dump-zeta produced no parsable graph on any of the 3 witnesses"); sys.exit(2)
print("examined %d graph(s) across 3 frontends" % graphs)
if holed:
    print("%-8s %-28s %8s %8s" % ("LANG", "GRAPH", "REGION", "UNNAMED"))
    for lang, name, end, h in out[:20]: print("%-8s %-28s %8d %8d" % (lang, name, end, h))
    print("⛔ GATE FAIL: %d of %d graph(s) reserve %d byte(s) no field covers" % (holed, graphs, hole_bytes))
    sys.exit(1)
print("GATE OK: %d graph(s) tile their region exactly -- an activation frame reserves only what it names" % graphs)
PYEOF

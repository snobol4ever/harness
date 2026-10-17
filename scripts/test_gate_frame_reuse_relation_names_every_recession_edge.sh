#!/bin/bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ RUNG 0 OF frame-slot-reuse-a-live-range-in-a-byrd-graph-extends-to-every-point-reachable-by-recession
# (cto, CEO-684 slice 2).  RUNG 0 IS AN INSTRUMENT, NOT AN OPTIMISATION: --dump-zeta now prints, per graph, the
# INTERFERENCE RELATION over every result slot -- who writes it (spine position), who last reads it, and whether
# any box that can recede sits between the two -- with every recession edge treated as a live edge.  A slot may
# be reused only when the relation can NAME, for a candidate, the absence of any beta landing between its last
# read and the next write.  Until that relation exists and can be READ there is nothing to be conservative WITH.
# ⛔ THE FAILURE MODE THIS LADDER IS DESIGNED AGAINST IS SILENCE, NOT A CRASH: a wrong reuse replaces a value
# with a later one and only an answer-grading test that happens to walk that path can see it.  So the instrument
# is graded on WITNESSES whose recession structure is known by construction, one per class, language-blind:
#   Prolog  frame_r1_witness.pl   -- a staged call (q/1) is a choice point: its own result is PINNED self, always.
#   Icon    every write(1, 1 to 3) -- the literal 1 is written BEFORE the generator `to` and read by write AFTER
#                                  it: the generator is the GUARD and the relation must name IR_TO for it.
#   SNOBOL4 S BREAK('c') . T      -- a pattern box is beta-capable: its result is PINNED self.
# And on the census identity every graph must satisfy: results = candidates + pinned + elided.
# ⛔ WHAT THIS GATE DOES NOT ASSERT, deliberately: the guard on r/1's arithmetic call ($ax_sub) and the
# every-loop pins are the CONSERVATIVE reading and later rungs will narrow them with measured witnesses; pinning
# those here would teach the next rung to keep a false pin.  Only edges that are choice points BY CONSTRUCTION
# (a staged call, a generator, a pattern box) are asserted.
# FAIL-ONCE HOOK: GATE_ZETA_DIR=<dir> grades pre-made w.pl/w.icn/w.sno .zeta files instead of fresh dumps; the
# red-before for this gate was the same three dumps with every reuse line stripped (166 findings, rc=1).
# ⛔ REFUSES rc=2 when --dump-zeta yields no parsable graph on any witness -- a runner that cannot measure never
# prints the success shape.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
cd "$ROOT" || exit 2
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp ../harness/scripts/fixtures/frame_r1_witness.pl "$T/w.pl"
cat > "$T/w.icn" <<'ICEOF'
procedure main()
   every write(1, 1 to 3);
end
ICEOF
cat > "$T/w.sno" <<'SNEOF'
        S = 'abcabc'
        S BREAK('c') . T
        OUTPUT = T
END
SNEOF
for w in w.pl w.icn w.sno; do timeout -k 5 20s ./scrip --dump-zeta "$T/$w" </dev/null > "$T/$w.zeta" 2>/dev/null; done
ZETA_DIR="${GATE_ZETA_DIR:-$T}"
python3 - "$ZETA_DIR" <<'PYEOF'
import sys, os, re
T = sys.argv[1]
ghdr = re.compile(r"^;\s*graph\s+(\d+)\s+'([^']*)'\s+—\s+slots=(\d+)\s+region_end=(\d+)")
summ = re.compile(r"^;\s+reuse\s+'([^']*)'\s+(.*)$")
row  = re.compile(r"^;\s+reuse\s+\+(\d+)\s+(\S+)\s+(.*)$")
graphs = 0; bad = []; docs = {}
for w in ("w.pl", "w.icn", "w.sno"):
    p = os.path.join(T, w + ".zeta")
    if not os.path.exists(p): continue
    cur = None; rows = []; got = {}
    for line in open(p, errors="replace"):
        m = ghdr.match(line)
        if m:
            cur = m.group(2); rows = []; got[cur] = {"rows": rows, "summary": None}; graphs += 1; continue
        if cur is None: continue
        m = summ.match(line)
        if m:
            kv = dict((k, int(v)) for k, v in re.findall(r"(\w+)=(\d+)", m.group(2)))
            got[cur]["summary"] = kv; continue
        m = row.match(line)
        if m: rows.append((int(m.group(1)), m.group(2), m.group(3)))
    docs[w] = got
    for name, g in got.items():
        s = g["summary"]
        if s is None: bad.append("%s %s: no reuse summary line" % (w, name)); continue
        if s.get("results") != s.get("candidates", 0) + s.get("pinned", 0) + s.get("elided", 0):
            bad.append("%s %s: census identity broken: %s" % (w, name, s))
if graphs == 0:
    print("⛔ REFUSE(2): --dump-zeta produced no parsable graph on any of the 3 witnesses"); sys.exit(2)
def rows_of(w, pat):
    return [r for name, g in docs.get(w, {}).items() if re.search(pat, name) for r in g["rows"]]
pl = rows_of("w.pl", r"^r/1$")
if not pl: bad.append("w.pl: r/1 graph not found")
else:
    staged = [r for r in pl if r[1] == "IR_CALL_PROC_STAGED"]
    if not staged: bad.append("w.pl r/1: no IR_CALL_PROC_STAGED result in the relation")
    for off, op, rest in staged:
        if "PINNED self" not in rest: bad.append("w.pl r/1: staged call at +%d is not PINNED self: %s" % (off, rest))
    if not any("CANDIDATE" in r[2] for r in pl): bad.append("w.pl r/1: no CANDIDATE at all -- the relation is not narrowing anything")
ic = rows_of("w.icn", r"^main$")
if not ic: bad.append("w.icn: main graph not found")
elif not any(r[1] == "IR_LIT_INTEGER" and "PINNED guard" in r[2] and "IR_TO" in r[2] for r in ic):
    bad.append("w.icn main: the literal read across the generator is not PINNED guard naming IR_TO")
sn = rows_of("w.sno", r"^main$")
if not sn: bad.append("w.sno: main graph not found")
elif not any(r[1].startswith("IR_MATCH_") and "PINNED self" in r[2] for r in sn):
    bad.append("w.sno main: no pattern box result reads PINNED self")
print("examined %d graph(s) across 3 frontends" % graphs)
if bad:
    for b in bad[:20]: print("  " + b)
    print("⛔ GATE FAIL: %d finding(s) -- the reuse relation does not name every recession edge it must" % len(bad)); sys.exit(1)
print("GATE OK: the reuse relation names the staged call, the generator guard and the pattern box on %d graph(s), and every graph's census adds up" % graphs)
PYEOF

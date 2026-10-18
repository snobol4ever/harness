#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_pl_ctx_leaf_thunks_cannot_drop_a_ball.sh -- A PROLOG LEAF WHOSE C HELPER CAN SET A BALL MUST BE
# REGISTERED WITH THE THUNK THAT READS ONE. rtx_plunify.s has two thunk macros over the same C calling
# convention: PL_CTX_LEAF(nm) and PL_CTX_LEAF_BALL(nm, modop). Only the second stores 0 to CTX_BALL before the
# call and loads it back after, turning a non-zero ball into DT_FAIL with r15 set. The first neither
# initialises that slot nor reads it. So a C helper registered under the PLAIN macro can set cx->ball with a
# perfectly correct ISO error and the goal will simply FAIL: the ball goes into an uninitialised stack slot
# and is never looked at again, and the helper's own do-not-overwrite guard is reading garbage on the way in.
#
# ⛔ WHY THIS EXISTS AND WHY A GATE RATHER THAN A RULE (cto 2026-09-13, from hq_C's succ/plus ask):
# hq_C cured rt_pl_succ_plus_cell to raise the four ISO errors succ/2 and plus/3 owe, in both modes, and
# NOTHING CHANGED -- because succ and plus sit under the plain macro. The C side looks complete and correct
# and is neither. That is the defining property of this class: THE CONTRACT LIVES ONLY IN HAND-WRITTEN ASM,
# so it is invisible to every grep of the compiler's own C sources, and each side reads as finished alone.
# RULES.md answers exactly this with a check rather than a memory -- a claim spanning two sites must be held
# by an instrument, because the next helper that learns to throw will go silent for a sitting otherwise.
#
# ⛔⭐ AND IT EXISTS BECAUSE MY OWN FIRST AUDIT OF THIS CLASS WAS WRONG, which is the strongest argument for
# automating it. I resolved each plain leaf by grepping by_name_dispatch.c for the literal `PL_CX_LEAF_HEAD(nm,`
# and reported the class as TWO NAMES. Twenty-odd names came back NO-HEAD and I read that as nothing-to-see
# rather than as could-not-resolve. They were not absent: PL_IN_LEAF, PL_OUT_CX_LEAF, PL_ATOM_OP_LEAF and
# PL_READ_TERM_LEAF each expand TO PL_CX_LEAF_HEAD with the name token-pasted, so the string I grepped for
# never appears in the source. The real count was ELEVEN -- succ, plus, and the nine inbound stream leaves
# (get/peek/unget char/code/byte _s), every one of which calls pl_stream_idx_ball and drops a real
# existent_error or domain_error on the floor. An instrument that reports success while failing to look is
# the recurring defect the INSTRUMENT LAWS exist to catch, and I shipped one before I shipped this.
#
# METHOD, and the preprocessor is the point: regexes over macro DEFINITIONS cannot see token pasting, so this
# gate runs the C PREPROCESSOR over the runtime sources and reads only fully-expanded function bodies. Every
# rt_pl_dop_<nm>_c is then a real definition whatever macro produced it. It extracts brace-balanced bodies,
# builds a call graph, marks the functions that write a ball (cx->ball =, plc_sp_ball, rt_pl_ball_*), and
# propagates reachability. A plain leaf that can reach a ball write is reported WITH ITS SHORTEST PATH, so the
# reader audits the finding instead of taking the verdict's word for it.
#
# ⛔ EVERY PLAIN LEAF MUST RESOLVE TO A BODY THIS GATE ACTUALLY READ. An unresolved name is the failure mode
# that produced the wrong count above, so it is rc=2 REFUSED, never a quiet pass. Same for a preprocessor
# failure: this gate would rather say it cannot measure than report a green it did not earn.
#
# ⛔ IT RESOLVES ITS SUBJECT FROM ITS OWN TREE (ROOT), NOT FROM S4E_HOME (coo 2026-09-13): a gate that resolves
# through S4E_HOME grades the MAIN tree no matter which tree invoked it, so a green run in a side tree is a
# statement about a tree you did not change. This gate reads the sources beside itself.
#
# WAIVERS: ../harness/scripts/pl_ctx_leaf_ball_waivers.txt, one `<name> <reason>` per line. A waiver is for a REACH that
# is provably not a real path -- the graph is an over-approximation and says so. A waiver with no reason is
# rejected. Curing a leaf means moving it to PL_CTX_LEAF_BALL, never adding it here.
# EXIT 0 every ball-capable leaf reads its ball; 1 at least one drops it (named, with path); 2 REFUSED.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SRC="$ROOT/src"
ASM="$SRC/runtime/rtx/rtx_plunify.s"
WAIVERS="$HERE/pl_ctx_leaf_ball_waivers.txt"
[ -r "$ASM" ] || { echo "⛔ GATE REFUSED (rc=2): cannot read $ASM -- nothing was checked" >&2; exit 2; }
command -v gcc >/dev/null 2>&1 || { echo "⛔ GATE REFUSED (rc=2): no gcc, so no preprocessor -- nothing was checked" >&2; exit 2; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
INC="-I$SRC -I$SRC/ir -I$SRC/lower -I$SRC/emitter -I$SRC/runtime/core -I$SRC/runtime/builtins -I$SRC/runtime -I$SRC/runtime/rt -I$SRC/parsers/snobol4 -I$SRC/parsers/raku -I$SRC/optimizer -I$SRC/templates/bb -I$SRC/templates/xa -I$SRC/templates/x86"
UNITS="$SRC/runtime/by_name_dispatch.c $SRC/runtime/unification.c"
: > "$TMP/all.i"
for f in $UNITS; do
    [ -r "$f" ] || { echo "⛔ GATE REFUSED (rc=2): cannot read $f -- nothing was checked" >&2; exit 2; }
    gcc -E $INC "$f" >> "$TMP/all.i" 2>"$TMP/cpp.err" || {
        echo "⛔ GATE REFUSED (rc=2): the preprocessor failed on $f -- nothing was checked" >&2
        sed -n '1,6p' "$TMP/cpp.err" >&2; exit 2; }
done
python3 - "$TMP/all.i" "$ASM" "$WAIVERS" <<'PY'
import collections, io, os, re, sys
ppath, apath, wpath = sys.argv[1], sys.argv[2], sys.argv[3]
raw = io.open(ppath, encoding='utf-8', errors='replace').read()
asm = io.open(apath, encoding='utf-8', errors='replace').read()

def mask_literals(t):
    out = list(t); i = 0; n = len(t)
    while i < n:
        c = t[i]
        if c in "'\"":
            q = c; j = i + 1
            while j < n:
                if t[j] == '\\': j += 2; continue
                if t[j] == q: break
                j += 1
            for k in range(i + 1, min(j, n)):
                if out[k] != '\n': out[k] = ' '
            i = j + 1; continue
        i += 1
    return ''.join(out)

src = mask_literals(raw)

plain, balled = set(), set()
for line in asm.split('\n'):
    s = line.strip()
    if s.startswith('#define'):
        continue
    m = re.match(r'PL_CTX_LEAF\(([A-Za-z0-9_]+)\)', s)
    if m:
        plain.add(m.group(1)); continue
    m = re.match(r'PL_CTX_LEAF_BALL\(([A-Za-z0-9_]+)\s*,', s)
    if m:
        balled.add(m.group(1))
if not plain and not balled:
    print("⛔ GATE REFUSED (rc=2): parsed ZERO thunk registrations out of %s -- the macro spelling changed and "
          "this gate is reading nothing. Fix the parse before trusting a green." % os.path.basename(apath),
          file=sys.stderr)
    sys.exit(2)

bodies = {}
for m in re.finditer(r'\b([A-Za-z_][A-Za-z0-9_]*)\s*\(', src):
    depth, k = 1, m.end()
    while k < len(src) and depth:
        c = src[k]
        if c == '(': depth += 1
        elif c == ')': depth -= 1
        k += 1
    p = k
    while p < len(src) and src[p] in ' \t\n': p += 1
    if p >= len(src) or src[p] != '{': continue
    d, q = 0, p
    while q < len(src):
        if src[q] == '{': d += 1
        elif src[q] == '}':
            d -= 1
            if not d: break
        q += 1
    bodies.setdefault(m.group(1), src[p:q + 1])

BALL = re.compile(r'->\s*ball\s*=|\bplc_sp_ball\s*\(|\brt_pl_ball_[A-Za-z0-9_]*\s*\(')
names = set(bodies)
direct = {n for n, b in bodies.items() if BALL.search(b)}
calls = {n: sorted(set(re.findall(r'\b([A-Za-z_][A-Za-z0-9_]*)\s*\(', b)) & names) for n, b in bodies.items()}

def shortest_ball_path(start):
    if start not in bodies: return None
    q = collections.deque([(start, [start])]); seen = {start}
    while q:
        n, path = q.popleft()
        if n in direct: return path
        for c in calls.get(n, ()):
            if c not in seen:
                seen.add(c); q.append((c, path + [c]))
    return None

waived = {}
if os.path.exists(wpath):
    for ln, raw in enumerate(io.open(wpath, encoding='utf-8', errors='replace'), 1):
        s = raw.strip()
        if not s or s.startswith('#'): continue
        parts = s.split(None, 1)
        if len(parts) < 2 or not parts[1].strip():
            print("⛔ GATE REFUSED (rc=2): %s line %d waives '%s' with NO REASON. A waiver without a reason is "
                  "a silenced measurement." % (os.path.basename(wpath), ln, parts[0]), file=sys.stderr)
            sys.exit(2)
        waived[parts[0]] = parts[1].strip()

unresolved = sorted(n for n in plain if 'rt_pl_dop_%s_c' % n not in bodies)
if unresolved:
    print("⛔ GATE REFUSED (rc=2): %d plain leaf/leaves did not resolve to a body this gate read: %s\n"
          "   This is the exact failure that produced a wrong count before this gate existed -- an\n"
          "   unresolved name is NOT a clean name. Add the defining translation unit to UNITS and re-run."
          % (len(unresolved), ', '.join(unresolved)), file=sys.stderr)
    sys.exit(2)

bad, waived_hit = [], []
for n in sorted(plain):
    path = shortest_ball_path('rt_pl_dop_%s_c' % n)
    if not path: continue
    (waived_hit if n in waived else bad).append((n, path))

print("PL_CTX_LEAF thunk ball audit: %d plain, %d ball-reading, 0 unresolved, %d waived"
      % (len(plain), len(balled), len(waived_hit)))
for n, path in waived_hit:
    print("   waived  %-22s %s\n            reason: %s" % (n, ' > '.join(path), waived[n]))
if not bad:
    print("PASS: no leaf registered PL_CTX_LEAF can reach a ball write%s."
          % (" that is not waived with a reason" if waived_hit else ""))
    sys.exit(0)
print("\n⛔ FAIL: %d leaf/leaves are registered PL_CTX_LEAF but their helper can set a ball, so the ball is\n"
      "   written into an uninitialised stack slot and never read -- the goal FAILS where ISO wants a throw.\n"
      "   Cure: move the name to PL_CTX_LEAF_BALL(<name>, MOD_OP_...) in rtx_plunify.s and mint its tag in\n"
      "   src/ir/descr_tags.inc. Do NOT waive it." % len(bad))
for n, path in bad:
    print("   %-22s %s" % (n, ' > '.join(path)))
sys.exit(1)
PY
rc=$?
exit $rc

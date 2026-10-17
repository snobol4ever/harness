#!/usr/bin/env python3
# util_pattern_fuzz.py — ⭐ PHASE 2 OF THE GRAMMAR-DRIVEN GENERATOR (s183, HQ Fable).
#
#   python3 ../harness/scripts/util_pattern_fuzz.py [--n 1000] [--seed 7] [--depth 4] [--out DIR] [--keep-green]
#
# ⛔ WHY THIS EXISTS.  harness/HARNESS-GEN.md (session G-10, 2026-03-31) built a grammar-driven random
# generator for SNOBOL4 ARITHMETIC and explicitly RESERVED the pattern pool `p q r` for "Phase 2".  Phase 2 was
# never built, and that is exactly the gap Lon named at s183: hand-written probe grids all pass while beauty
# fails, because a hand-written grid only contains the shapes its author already thought of.  A random grammar
# walk contains the ones nobody thought of.
#
# ⭐ THE DESIGN POINT IS DEDUPLICATION BY SHAPE, INHERITED FROM HARNESS-GEN.md's OWN RULE ("one representative
# per distinct expression shape").  Thousands of random programs collapse into a handful of CLASSES: each red is
# canonicalised (every literal -> 'L', every charset -> 'C', every integer -> 'N') and only the FIRST witness of
# each canonical shape is kept.  Without this the output is a thousand near-duplicates and unreadable.
#
# ⛔ TWO CLASSIFIER TRAPS, BOTH HIT ON THIS TOOL'S FIRST RUN AND BOTH FIXED HERE, RECORDED SO A READER TRUSTS
# THE NUMBERS: (1) subprocess reports a killing signal as a NEGATIVE returncode, so a SIGSEGV is -11, NOT 139 --
# a `rc == 139` test silently books every crash as a generic non-zero exit; (2) an oracle that ERRORS still
# exits 0 and prints its diagnostic, so "output is non-empty" is not "oracle succeeded" -- the output must be
# exactly `match` or `nomatch` or the row is ORACLE-BAD.  The first run showed 9 rows as `rc-11` and several
# ORACLE-BAD rows carrying a filename echo, which is what surfaced both.
# ⛔ THE ORACLE IS THE JUDGE AND ITS EXIT STATUS IS CHECKED FIRST.  Live sbl SIGSEGVs on some legal shapes (90
# rows in the s183 batch-4 run); those are ORACLE-BAD and are NEVER counted as SCRIP verdicts.  A harness that
# compared blindly would book them as phantom passes or phantom fails depending which way it fell.
import argparse, os, random, re, subprocess, sys, collections
S4E = os.environ.get('S4E_HOME') or os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SCRIP = os.path.join(S4E, 'SCRIP', 'scrip')
# ⛔ FIXED 2026-09-05 (seat20, row fuzz-crash-class-and-port-trace-refs-over-the-three-open-languages):
# this used to hardcode SBL = S4E/x64/bin/sbl, the exact per-root fallback lib_oracle_flags.sh's own header
# says was DELETED on purpose (Lon s261: "Ensure that no root have x64. Everyone must share... Do not use
# symlinks"). On a root with no such clone (every seat root as of this sweep) it refused outright; on a
# root that happened to have a stray one it would have silently graded against a private, possibly-diverged
# copy -- exactly the hazard that ruling exists to prevent. Route through the one shared accessor instead.
def _sbl_correctness_bin():
    d = os.path.dirname(os.path.abspath(__file__))
    p = subprocess.run(['bash', '-c', 'source "%s/lib_oracle_flags.sh" && sbl_correctness_bin' % d],
                        capture_output=True, text=True)
    if p.returncode != 0 or not p.stdout.strip():
        sys.stderr.write(p.stderr)
        sys.exit("⛔ ORACLE ABSENT: sbl_correctness_bin() could not resolve the shared correctness oracle "
                  "(see its own refusal above). Every verdict would be a plausible FALSE table.")
    return p.stdout.strip()
def _sbl_lang_flags():
    d = os.path.dirname(os.path.abspath(__file__))
    p = subprocess.run(['bash', '-c', 'source "%s/lib_oracle_flags.sh" && sbl_lang_flags' % d],
                        capture_output=True, text=True)
    return p.stdout.strip().split() if p.returncode == 0 and p.stdout.strip() else ['-bf']
SBL = _sbl_correctness_bin(); SBL_FLAGS = _sbl_lang_flags()
LITS = ["'a'", "'ab'", "'abc'", "'+'", "''"]
CSETS = ["'ab'", "'abc'", "'+'", "' '"]
INTS = ["0", "1", "2", "3"]
SUBJECTS = ["'aa a'", "'ab+ab'", "'abcabc'", "'a+a+a'", "'aaa'", "''", "'a b c'", "'ab'"]
def leaf(rnd):
    k = rnd.choice(['lit','any','notany','span','break','breakx','len','pos','rpos','tab','rtab','rem','arb','bal'])
    if k=='lit':    return rnd.choice(LITS)
    if k=='any':    return "ANY(%s)"    % rnd.choice(CSETS)
    if k=='notany': return "NOTANY(%s)" % rnd.choice(CSETS)
    if k=='span':   return "SPAN(%s)"   % rnd.choice(CSETS)
    if k=='break':  return "BREAK(%s)"  % rnd.choice(CSETS)
    if k=='breakx': return "BREAKX(%s)" % rnd.choice(CSETS)
    if k=='len':    return "LEN(%s)"    % rnd.choice(INTS)
    if k=='pos':    return "POS(%s)"    % rnd.choice(INTS)
    if k=='rpos':   return "RPOS(%s)"   % rnd.choice(INTS)
    if k=='tab':    return "TAB(%s)"    % rnd.choice(INTS)
    if k=='rtab':   return "RTAB(%s)"   % rnd.choice(INTS)
    return {'rem':'REM','arb':'ARB','bal':'BAL'}[k]
def expr(rnd, d, defers):
    """Recursive pattern-expression walk.  `defers` collects auxiliary rule definitions (the defer chain)."""
    if d <= 0: return leaf(rnd)
    k = rnd.choice(['cat','alt','arbno','fence','cap','defer','leaf','leaf'])
    if k=='leaf':  return leaf(rnd)
    if k=='cat':   return "%s %s" % (expr(rnd,d-1,defers), expr(rnd,d-1,defers))
    if k=='alt':   return "(%s | %s)" % (expr(rnd,d-1,defers), rnd.choice([expr(rnd,d-1,defers), "''"]))
    if k=='arbno': return "ARBNO(%s)" % expr(rnd,d-1,defers)
    if k=='fence': return "FENCE(%s)" % expr(rnd,d-1,defers)
    if k=='cap':   return "(%s) %s v%d" % (expr(rnd,d-1,defers), rnd.choice(['.','$']), len(defers))
    nm = "G%d" % len(defers); defers.append((nm, expr(rnd,d-1,defers))); return "*%s" % nm
def canon(s):
    s = re.sub(r"'[^']*'", "L", s); s = re.sub(r"\bG\d+\b", "G", s)
    s = re.sub(r"\bv\d+\b", "v", s); s = re.sub(r"\((\d+)\)", "(N)", s)
    return re.sub(r"\s+", " ", s).strip()
def build(rnd, depth):
    defers = []; body = expr(rnd, depth, defers); subj = rnd.choice(SUBJECTS)
    head = rnd.choice(["POS(0) ", ""]); tail = rnd.choice([" RPOS(0)", "", " RPOS(0)"])
    lines = ["          %-13s =  %s" % (nm, d) for nm, d in defers]
    lines.append("          P             =  %s" % body)
    lines.append("          %s %s*P%s                          :S(OK)F(NO)" % (subj, head, tail))
    lines += ["OK        OUTPUT = 'match'                      :(END)",
              "NO        OUTPUT = 'nomatch'", "END"]
    return "\n".join(lines) + "\n", canon(body + "|" + head + "|" + tail)
def run(path, exe, extra=None, tmo=6):
    try: p = subprocess.run([exe, path] if extra is None else [exe]+extra+[path],
                            stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=tmo)
    except subprocess.TimeoutExpired: return 124, ''
    return p.returncode, p.stdout
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--n', type=int, default=1000); ap.add_argument('--seed', type=int, default=7)
    ap.add_argument('--depth', type=int, default=4); ap.add_argument('--out', default='/tmp/patfuzz')
    ap.add_argument('--keep-green', action='store_true')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True); rnd = random.Random(a.seed)
    seen = {}; tally = collections.Counter(); reds = []
    for i in range(a.n):
        src, shape = build(rnd, a.depth)
        f = os.path.join(a.out, "pf_%05d.sno" % i)
        open(f, 'w').write(src)
        # ⛔ FIXED 2026-09-05 (seat20, same row): was hardcoded ['-b'], the FOLDING arm -- CLAUDE.md's own
        # FACT RULE (s189) is that -bf is the ONLY correct language arm to grade SCRIP against, precisely
        # because -b case-folds names and SCRIP does not. The fuzzed pattern names (v0, v1, G0, G1...) are
        # exactly the shape a folding mismatch could misjudge as a false DIFF/FALSE-ACCEPT that has nothing
        # to do with a real compiler defect.
        orc, oout = run(f, SBL, SBL_FLAGS)
        if orc != 0 or oout.strip() not in ('match', 'nomatch'):
            tally['ORACLE-BAD'] += 1
            if not a.keep_green: os.remove(f)
            continue                                   # ⛔ never a SCRIP verdict
        rc, sout = run(f, SCRIP)
        if   rc in (139, -11): v = 'SEGV'          # subprocess reports SIGNALS AS NEGATIVE; -11 is SIGSEGV
        elif rc == 124:         v = 'HANG'
        elif rc < 0:            v = 'SIG%d' % (-rc)  # any other fatal signal, named not lumped
        elif rc != 0:           v = 'rc%d' % rc
        elif sout == oout: v = 'AGREE'
        else: v = 'FALSE-ACCEPT' if sout.strip() == 'match' else 'DIFF'
        tally[v] += 1
        if v == 'AGREE':
            if not a.keep_green: os.remove(f)
            continue
        key = (v, shape)
        if key in seen: seen[key] += 1; os.remove(f); continue   # dedup: keep only the FIRST of each shape
        seen[key] = 1; reds.append((v, shape, f, oout.strip().replace('\n','/'), sout.strip().replace('\n','/')))
    print("=== PATTERN FUZZ: n=%d seed=%d depth=%d ===" % (a.n, a.seed, a.depth))
    for k, c in tally.most_common(): print("  %-14s %d" % (k, c))
    print("=== DISTINCT RED SHAPES: %d (from %d red runs) ===" % (len(reds), sum(c for (v,_),c in seen.items())))
    for v, shape, f, o, s in reds:
        print("  [%-12s] x%-4d %s" % (v, seen[(v,shape)], os.path.basename(f)))
        print("      shape : %s" % shape[:150])
        print("      oracle=%-14s scrip=%s" % (o[:14], s[:20]))
main()

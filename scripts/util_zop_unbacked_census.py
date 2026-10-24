#!/usr/bin/env python3
"""util_zop_unbacked_census.py -- THE UNBACKED-KEY CENSUS: every cell read that x86_zop resolves through the frame for a KEY WITH NO FRAME BYTES
BEHIND IT (zls_key_unbacked: a keys-only graph, or a key past a home-frame graph's resident region), counted by box kind over a set of programs
(cfo 2026-10-24, D3 -- the Prolog home-frame switch, row 233, CEO-1945; the ceo's MODE line of 12:2x: hq_prolog and hq_icon tally the unbacked
reads by kind and give each screaming kind its own carve).

THE INSTRUMENT IS A SCRIPT'S OWN SWITCH, NEVER A SEAM IN SCRIP (RULES.md, CEO-1680): the tree under test keeps its FATAL abort -- the first
unbacked read kills the compile, which is the scream Lon wants -- and this script builds a SCRATCH WORKTREE of this root's SCRIP (a git
worktree beside a harness worktree under <root>/.scratch/zop-census/, never a symlink: CEO-1820), carries the seat's UNCOMMITTED src diff
onto it, swaps that one FATAL block for a stderr count line, builds it, compiles every program with it and counts the lines. The seat's own
tree is never touched. The worktree persists between runs (an incremental rebuild), --prune removes it.

THE COUNT LINE: ZOP_UNBACKED off=<key> op=<IR op> regime=<x86_zop regime> zres=<armed> own=<zls_off of the box> k_own=<its own carve>
gs=<graph serial> ai=<g->all index> -- gs and ai name the PLAN_ROW of `<worktree>/scrip --dump-plan <program>` (PLAN graph=... serial=<gs>,
PLAN_ROW ... all=<ai>), so a seat can read every scream beside its plan row; --lines prints them.

USE:  python3 harness/scripts/util_zop_unbacked_census.py [--op IR_KIND]... [--lines] [--empty-prolog] [--timeout S] [--prune] PROGRAM...
      --op IR_KIND      the kinds this run grades (repeatable); rc 0 iff their lines read 0 -- without it, rc 0 iff every line reads 0
      --empty-prolog    adds the empty Prolog program (:- initialization(main). main.) -- the prelude alone
      --lines           prints every count line under its program
      --prune           removes the scratch worktrees and exits
PRINTS: ZOP_UNBACKED_CENSUS program=<name> rc=<compile rc> total=<n> <IR_KIND>=<n> ...   (one per program, kinds by count)
        ZOP_UNBACKED_CENSUS_TOTAL programs=<p> total=<n> graded=<g> ops=<kinds|all> by_op=<IR_KIND>:<n>,... tree=<SCRIP HEAD>[+dirty] worktree=<path> build_s=<wall>
EXIT:   0 the graded count is 0 · 1 a graded line remains · 2 could not measure (no SCRIP, no FATAL block to swap, the worktree would not
        build, a program did not compile -- its rc is printed -- or no program named).
"""
import fcntl, os, re, resource, shutil, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
SCRIP = os.path.join(ROOT, "SCRIP")
HARNESS = os.path.join(HERE, "..")
CENSUS = os.path.join(ROOT, ".scratch", "zop-census")
WT, WH = os.path.join(CENSUS, "SCRIP"), os.path.join(CENSUS, "harness")
ASM = os.path.join("src", "templates", "x86", "x86_asm.h")
ANCHOR = 'extern "C" int zd_k_own(IR_t * nd);\n'
HELPER = ("static inline int zopc_ai(const IR_t * nd) { if (!g_emit_cfg || !nd) return -1; for (int k = 0; k < g_emit_cfg->n; k++) if (g_emit_cfg->all[k] == nd) return k;"
          " return -1; }\n")
COUNT = ('    if (r != 2 && zls_key_unbacked(g_emit_cfg, off)) fprintf(stderr, "ZOP_UNBACKED off=%d op=%d regime=%d zres=%d own=%d k_own=%d gs=%d ai=%d\\n", off,'
         ' _.node ? (int) _.node->op : -1, r, _.op_zres, _.node ? zls_off(_.node) : -1, _.node ? zd_k_own(_.node) : -1, g_emit_cfg ? g_emit_cfg->serial : -1, zopc_ai(_.node));\n')
FATAL = re.compile(r"^    if \(r != 2 && zls_key_unbacked\(g_emit_cfg, off\)\)\n        \{ fprintf\(stderr,\n(?:.*\n)*?.*abort\(\); \}\n", re.M)
LINE = re.compile(r"^ZOP_UNBACKED off=(-?\d+) op=(-?\d+) ")
AS_LIMIT = 8192000000
def refuse(why):
    print("ZOP_UNBACKED_CENSUS REFUSE(2): " + why); sys.exit(2)
def git(cwd, *a, check=True):
    p = subprocess.run(["git", "-C", cwd] + list(a), capture_output=True, text=True)
    if check and p.returncode != 0: refuse("git %s in %s: %s" % (" ".join(a), cwd, p.stderr.strip()[-400:]))
    return p
def worktree(repo, path):
    head = git(repo, "rev-parse", "HEAD").stdout.strip()
    if os.path.isdir(os.path.join(path, ".git")) or os.path.isfile(os.path.join(path, ".git")):
        git(path, "reset", "-q", "--hard"); git(path, "clean", "-qfd", "--", "src"); git(path, "checkout", "-q", "--detach", head)
    else:
        os.makedirs(os.path.dirname(path), exist_ok=True); git(repo, "worktree", "prune"); git(repo, "worktree", "add", "-q", "--detach", path, head)
    return head
def carry_diff(repo, path, paths):
    d = git(repo, "diff", "HEAD", "--binary", "--", *paths).stdout
    if d.strip():
        p = subprocess.run(["git", "-C", path, "apply", "--whitespace=nowarn"], input=d, capture_output=True, text=True)
        if p.returncode != 0: refuse("the working tree's diff did not apply onto the worktree: %s" % p.stderr.strip()[-400:])
    for f in git(repo, "ls-files", "--others", "--exclude-standard", "--", *paths).stdout.split("\n"):
        if f:
            dst = os.path.join(path, f); os.makedirs(os.path.dirname(dst), exist_ok=True); shutil.copyfile(os.path.join(repo, f), dst)
    return bool(d.strip())
def swap_fatal(path):
    p = os.path.join(path, ASM); s = open(p, encoding="utf-8").read()
    if "ZOP_UNBACKED off=%d" in s:
        if "zopc_ai(" not in s and "ai=%d" not in s: pass
        return "already-counting"
    if len(FATAL.findall(s)) != 1: refuse("x86_asm.h holds %d FATAL x86_zop blocks to swap, not one" % len(FATAL.findall(s)))
    if s.count(ANCHOR) != 1: refuse("x86_asm.h has no single zd_k_own anchor to hang the helper on")
    s = FATAL.sub(lambda m: COUNT, s).replace(ANCHOR, ANCHOR + HELPER)
    open(p, "w", encoding="utf-8").write(s); return "swapped"
def op_names(path):
    src = open(os.path.join(path, "src", "ir", "IR.h"), encoding="utf-8").read()
    m = re.search(r"typedef enum \{(.*?)\}", src, re.S); names, val = {}, 0
    for tok in m.group(1).split(","):
        tok = tok.strip()
        if not tok: continue
        nm, _, eq = tok.partition("=")
        if eq.strip(): val = int(eq.strip(), 0)
        names[val] = nm.strip(); val += 1
    return names
def run_slot():
    if os.environ.get("S4E_RUN_SLOT_HELD"): return None
    n = max(1, int(os.environ.get("S4E_RUN_SLOTS", "8"))); d = "/tmp/s4e-run-slots"; os.makedirs(d, exist_ok=True)
    for i in range(n):
        f = open(os.path.join(d, "slot%d" % i), "a")
        try: fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB); return f
        except OSError: f.close()
    f = open(os.path.join(d, "slot%d" % (os.getpid() % n)), "a"); fcntl.flock(f, fcntl.LOCK_EX); return f
def limit_as():
    resource.setrlimit(resource.RLIMIT_AS, (AS_LIMIT, AS_LIMIT))
def compile_one(path, prog, timeout):
    slot = run_slot()
    try:
        p = subprocess.run([os.path.join(path, "scrip"), "--compile", "-o", "/dev/null", prog], cwd=path, stdin=subprocess.DEVNULL, capture_output=True, text=True,
                           errors="replace", timeout=timeout, preexec_fn=limit_as, env=dict(os.environ, S4E_RUN_SLOT_HELD="1"))
        return p.returncode, p.stderr
    except subprocess.TimeoutExpired as e:
        return "HANG", (e.stderr or b"").decode(errors="replace") if isinstance(e.stderr, bytes) else (e.stderr or "")
    finally:
        if slot: slot.close()
def main():
    args = sys.argv[1:]; ops = []; lines = False; empty = False; timeout = 300; progs = []
    while args:
        a = args.pop(0)
        if a == "--op":
            if not args: refuse("--op takes an IR kind")
            ops.append(args.pop(0))
        elif a == "--lines": lines = True
        elif a == "--empty-prolog": empty = True
        elif a == "--timeout":
            if not args or not args[0].isdigit(): refuse("--timeout takes seconds")
            timeout = int(args.pop(0))
        elif a == "--prune":
            for repo, path in ((SCRIP, WT), (HARNESS, WH)):
                if os.path.isdir(path): git(repo, "worktree", "remove", "--force", path, check=False)
            print("ZOP_UNBACKED_CENSUS pruned %s" % CENSUS); sys.exit(0)
        elif a.startswith("-"): refuse("unknown switch %s" % a)
        else: progs.append(os.path.abspath(a))
    if not os.path.isdir(os.path.join(SCRIP, "src")): refuse("no SCRIP beside this harness at %s" % SCRIP)
    if empty:
        os.makedirs(CENSUS, exist_ok=True); e = os.path.join(CENSUS, "empty.pl"); open(e, "w").write(":- initialization(main).\nmain.\n"); progs.insert(0, e)
    if not progs: refuse("no program named (PROGRAM... or --empty-prolog)")
    for p in progs:
        if not os.path.isfile(p): refuse("no such program %s" % p)
    head = worktree(SCRIP, WT); worktree(os.path.normpath(HARNESS), WH)
    dirty = carry_diff(SCRIP, WT, ["src", "Makefile", "bootstrap", "tools"])
    how = swap_fatal(WT)
    t0 = time.time(); b = subprocess.run(["make", "-j8"], cwd=WT, capture_output=True, text=True, errors="replace"); wall = time.time() - t0
    if b.returncode != 0:
        sys.stdout.write("\n".join((b.stdout + b.stderr).split("\n")[-20:]) + "\n"); refuse("the census worktree did not build (make rc %d)" % b.returncode)
    names = op_names(WT); grand = {}; total = 0; graded = 0; failed = []
    for prog in progs:
        rc, err = compile_one(WT, prog, timeout); by = {}; raw = []
        for ln in err.split("\n"):
            m = LINE.match(ln)
            if not m: continue
            k = names.get(int(m.group(2)), "op%s" % m.group(2)); by[k] = by.get(k, 0) + 1; grand[k] = grand.get(k, 0) + 1; raw.append(ln)
        n = sum(by.values()); total += n; graded += n if not ops else sum(by.get(o, 0) for o in ops)
        if rc != 0: failed.append("%s rc=%s" % (os.path.basename(prog), rc))
        print("ZOP_UNBACKED_CENSUS program=%s rc=%s total=%d %s" % (os.path.basename(prog), rc, n, " ".join("%s=%d" % kv for kv in sorted(by.items(), key=lambda kv: -kv[1]))))
        if lines:
            for ln in raw: print("  " + ln)
    print("ZOP_UNBACKED_CENSUS_TOTAL programs=%d total=%d graded=%d ops=%s by_op=%s tree=%s%s worktree=%s swap=%s build_s=%.1f"
          % (len(progs), total, graded, ",".join(ops) if ops else "all", ",".join("%s:%d" % kv for kv in sorted(grand.items(), key=lambda kv: -kv[1])) or "-", head[:9],
             "+dirty" if dirty else "", WT, how, wall))
    if failed: refuse("a program did not compile under the count line: " + "; ".join(failed))
    sys.exit(0 if graded == 0 else 1)
if __name__ == "__main__":
    main()

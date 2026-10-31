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
      --core LANG       adds every CORE entry of corpus/tests/LANG/PARTITION.tsv (CEO-1676), each materialized once through corpus_suite_harness.py extract
                        under <root>/.scratch/zop-census/core-LANG/ (re-extracted when the suite container is newer); repeatable
      --master LANG     adds EVERY entry of corpus/tests/LANG/ALL.csv (the whole master, stdin sidecar and companions beside each), repeatable; "all" is the seven
      --ref REF         measures that SCRIP ref (a bare branch name tries origin/<name>, a sha works) in a scratch root keyed by its sha,
                        <root>/.scratch/zop-census/ref-<sha12>/{SCRIP,harness,corpus}, the corpus sparse; the seat's diff is not carried; a ref root unused for 24 h is removed
      --workers N       compiles N programs at a time (default 8, the most; every compile also takes a run slot of the box-wide pool, CEO-1894)
      --board           prints per-language board lines and no per-program lines: UNBACKED_BOARD lang=<l> programs=<n> screaming=<s> reads=<r>, UNBACKED_KIND lang=<l> op=<op>
                        reads=<r> programs=<p>, UNBACKED_BASE/UNBACKED_OWN (what an EMPTY source of the language reads -- Prolog's prelude, once per program -- and the reads
                        past it), UNBACKED_NOTE (compiles that failed for any reason are counted, never read as clean; --board does not refuse on them)
      --tsv FILE        with --board, writes every read as lang<TAB>entry<TAB>op<TAB>off
      --empty-prolog    adds the empty Prolog program (:- initialization(main). main.) -- the prelude alone
      --lines           prints every count line under its program
      --prune           removes the scratch worktrees and exits
PRINTS: ZOP_UNBACKED_CENSUS program=<name> rc=<compile rc> total=<n> <IR_KIND>=<n> ...   (one per program, kinds by count)
        ZOP_UNBACKED_CENSUS_TOTAL programs=<p> total=<n> graded=<g> ops=<kinds|all> by_op=<IR_KIND>:<n>,... tree=<SCRIP HEAD>[+dirty] worktree=<path> build_s=<wall>
EXIT:   0 the graded count is 0 · 1 a graded line remains · 2 could not measure (no SCRIP, no FATAL block to swap, the worktree would not
        build, a program did not compile -- its rc is printed -- or no program named).
"""
import concurrent.futures, csv, fcntl, os, re, shutil, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
SCRIP = os.path.join(ROOT, "SCRIP")
HARNESS = os.path.join(HERE, "..")
CENSUS = os.path.join(ROOT, ".scratch", "zop-census")
CORPUS = os.path.join(ROOT, "corpus")
WT, WH, WC = os.path.join(CENSUS, "SCRIP"), os.path.join(CENSUS, "harness"), os.path.join(CENSUS, "corpus")
SPARSE = ["tests", "library", "include", "packages/icon"]
MASTERS = ("snobol4", "icon", "prolog", "raku", "pascal", "snocone", "rebus")
LANG = {}
STALE_S = 24 * 3600
ASM = os.path.join("src", "templates", "x86", "x86_zeta.cpp")
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
def tree(repo, path, rev, sparse):
    if not (os.path.isdir(os.path.join(path, ".git")) or os.path.isfile(os.path.join(path, ".git"))):
        os.makedirs(os.path.dirname(path), exist_ok=True); git(repo, "worktree", "prune"); git(repo, "worktree", "add", "-q", "--detach", "--no-checkout", path, rev)
        if sparse: git(path, "sparse-checkout", "set", "--cone", *sparse)
        git(path, "checkout", "-q", "--detach", rev)
    elif git(path, "rev-parse", "HEAD").stdout.strip() != rev: git(path, "checkout", "-q", "--detach", rev)
    if sparse: git(path, "sparse-checkout", "set", "--cone", *sparse)
def resolve_ref(ref):
    for c in (ref, "origin/" + ref):
        p = git(SCRIP, "rev-parse", "--verify", "--quiet", c + "^{commit}", check=False)
        if p.returncode == 0: return p.stdout.strip()
    git(SCRIP, "fetch", "--quiet", "origin", re.sub(r"^origin/", "", ref), check=False)
    git(SCRIP, "fetch", "--quiet", "origin", "+refs/tags/%s:refs/tags/%s" % (ref, ref), check=False)
    for c in (ref, "origin/" + ref):
        p = git(SCRIP, "rev-parse", "--verify", "--quiet", c + "^{commit}", check=False)
        if p.returncode == 0: return p.stdout.strip()
    refuse("the ref %r does not resolve in %s (not local, not origin/%s, not a tag, not fetchable)" % (ref, SCRIP, ref))
def drop_root(base):
    for n, repo in (("SCRIP", SCRIP), ("harness", HARNESS), ("corpus", CORPUS)): git(repo, "worktree", "remove", "--force", os.path.join(base, n), check=False)
    shutil.rmtree(base, ignore_errors=True)
    for repo in (SCRIP, HARNESS, CORPUS): git(repo, "worktree", "prune", check=False)
def ref_roots():
    return [os.path.join(CENSUS, d) for d in sorted(os.listdir(CENSUS)) if d.startswith("ref-") and os.path.isdir(os.path.join(CENSUS, d))] if os.path.isdir(CENSUS) else []
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
    if len(FATAL.findall(s)) != 1: refuse("x86_zeta.cpp holds %d FATAL x86_zop blocks to swap, not one" % len(FATAL.findall(s)))
    if s.count(ANCHOR) != 1: refuse("x86_zeta.cpp has no single zd_k_own anchor to hang the helper on")
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
    import random, time
    n = max(1, int(os.environ.get("S4E_RUN_SLOTS", "8"))); d = os.environ.get("S4E_RUN_SLOT_DIR") or "/tmp/s4e-run-slots"; os.makedirs(d, exist_ok=True)
    while True:
        for i in range(n):
            f = open(os.path.join(d, "slot%d" % i), "a")
            try: fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB); return f
            except OSError: f.close()
        time.sleep(0.25 + random.random() * 0.25)
def compile_one(path, prog, timeout):
    slot = run_slot()
    try:
        p = subprocess.run(["bash", "-c", 'ulimit -v %d; ulimit -c 0; exec "$@"' % (AS_LIMIT // 1024), "bash", os.path.join(path, "scrip"), "--compile", '--out=/dev/null', prog], cwd=path,
                           stdin=subprocess.DEVNULL, capture_output=True, text=True, errors="replace", timeout=timeout, env=dict(os.environ, S4E_RUN_SLOT_HELD="1", SNO_LIB=os.path.join(CORPUS, "include")))
        return p.returncode, p.stderr
    except subprocess.TimeoutExpired as e:
        return "HANG", (e.stderr or b"").decode(errors="replace") if isinstance(e.stderr, bytes) else (e.stderr or "")
    finally:
        if slot: slot.close()
SUITE_EXTS = (".sno", ".spt", ".sbl", ".sc", ".reb", ".icn", ".pl", ".raku", ".pas", ".scrip")
def harness_mod():
    sys.path.insert(0, HERE)
    import corpus_suite_harness
    return corpus_suite_harness
def suite_of(lang):
    d = os.path.join(CORPUS, "tests", lang)
    if not os.path.isdir(d): refuse("no corpus/tests/%s at %s" % (lang, d))
    suites = [f for f in os.listdir(d) if f.startswith("ALL.") and os.path.splitext(f)[1] in SUITE_EXTS]
    if len(suites) != 1: refuse("no single suite container ALL.<ext> under %s (found %s)" % (d, suites))
    return d, os.path.join(d, suites[0]), os.path.join(d, "ALL.ref"), os.path.splitext(suites[0])[1]
def materialize(lang, names, kind):
    d, suite, ref, ext = suite_of(lang); out = os.path.join(CENSUS, kind + "-" + lang); os.makedirs(out, exist_ok=True); h = harness_mod()
    def one(nm):
        p = os.path.join(out, nm + ext)
        if not (os.path.isfile(p) and os.path.getmtime(p) >= os.path.getmtime(suite)):
            x = subprocess.run([sys.executable, os.path.join(HERE, "corpus_suite_harness.py"), "extract", suite, ref, nm, p, "--out-in", p + ".in"], capture_output=True, text=True, errors="replace")
            if x.returncode != 0 or not os.path.isfile(p): return p, (x.stdout + x.stderr).strip().split("\n")[-1:]
        h._copy_companions(open(p, encoding="utf-8", errors="replace").read(), d, out)
        return p, None
    with concurrent.futures.ThreadPoolExecutor(8) as ex: res = list(ex.map(one, names))
    for nm, (p, bad) in zip(names, res):
        if bad is not None: refuse("could not extract %s entry %s of %s: %s" % (kind, nm, lang, bad))
        LANG[p] = lang
    return [p for p, _ in res]
def core_programs(lang):
    d = os.path.join(CORPUS, "tests", lang); part = os.path.join(d, "PARTITION.tsv")
    if not os.path.isfile(part): refuse("no partition for %s at %s" % (lang, part))
    names = [ln.split("\t")[0] for ln in open(part, encoding="utf-8") if not ln.startswith("#") and ln.split("\t")[1:2] == ["core"]]
    if not names: refuse("no core entry in %s" % part)
    return materialize(lang, names, "core")
def master_programs(lang):
    csvp = os.path.join(CORPUS, "tests", lang, "ALL.csv")
    if not os.path.isfile(csvp): refuse("no ALL.csv for %s at %s" % (lang, csvp))
    names = [r["entry"] for r in csv.DictReader(open(csvp, newline="", encoding="utf-8"))]
    if not names: refuse("no entry in %s" % csvp)
    return materialize(lang, names, "master")
def main():
    global WT, WH, WC
    args = sys.argv[1:]; ops = []; lines = False; empty = False; timeout = 300; progs = []; cores = []; masters = []; ref = ""; workers = 8; board = False; tsv = ""
    while args:
        a = args.pop(0)
        if a == "--op":
            if not args: refuse("--op takes an IR kind")
            ops.append(args.pop(0))
        elif a == "--core":
            if not args: refuse("--core takes a language")
            cores.append(args.pop(0))
        elif a == "--master":
            if not args or (args[0] != "all" and args[0] not in MASTERS): refuse("--master takes a language (%s) or all" % " ".join(MASTERS))
            l = args.pop(0); masters.extend(MASTERS if l == "all" else [l])
        elif a == "--ref":
            if not args: refuse("--ref takes a SCRIP ref")
            ref = args.pop(0)
        elif a == "--workers":
            if not args or not args[0].isdigit(): refuse("--workers takes a count")
            workers = max(1, min(8, int(args.pop(0))))
        elif a == "--board": board = True
        elif a == "--tsv":
            if not args: refuse("--tsv takes a file")
            tsv = os.path.abspath(args.pop(0))
        elif a == "--lines": lines = True
        elif a == "--empty-prolog": empty = True
        elif a == "--timeout":
            if not args or not args[0].isdigit(): refuse("--timeout takes seconds")
            timeout = int(args.pop(0))
        elif a == "--prune":
            for repo, path in ((SCRIP, WT), (HARNESS, WH), (CORPUS, WC)):
                if os.path.isdir(path): git(repo, "worktree", "remove", "--force", path, check=False)
            for base in ref_roots(): drop_root(base)
            print("ZOP_UNBACKED_CENSUS pruned %s" % CENSUS); sys.exit(0)
        elif a.startswith("-"): refuse("unknown switch %s" % a)
        else: progs.append(os.path.abspath(a))
    if not os.path.isdir(os.path.join(SCRIP, "src")): refuse("no SCRIP beside this harness at %s" % SCRIP)
    if empty:
        os.makedirs(CENSUS, exist_ok=True); e = os.path.join(CENSUS, "empty.pl"); open(e, "w").write(":- initialization(main).\nmain.\n"); progs.insert(0, e)
    for lang in cores: progs.extend(core_programs(lang))
    for lang in masters: progs.extend(master_programs(lang))
    if not progs: refuse("no program named (PROGRAM..., --core LANG, --master LANG or --empty-prolog)")
    for p in progs:
        if not os.path.isfile(p): refuse("no such program %s" % p)
    corpus_head = git(CORPUS, "rev-parse", "HEAD").stdout.strip(); lock = None
    if ref:
        head = resolve_ref(ref); base = os.path.join(CENSUS, "ref-" + head[:12]); os.makedirs(base, exist_ok=True); os.utime(base)
        for old in ref_roots():
            if old != base and time.time() - os.path.getmtime(old) > STALE_S: drop_root(old)
        lock = open(base + ".lock", "a"); fcntl.flock(lock, fcntl.LOCK_EX)
        WT, WH, WC = [os.path.join(base, n) for n in ("SCRIP", "harness", "corpus")]
        tree(SCRIP, WT, head, None); tree(HARNESS, WH, git(HARNESS, "rev-parse", "HEAD").stdout.strip(), None); tree(CORPUS, WC, corpus_head, SPARSE)
        dirty = False; make = ["make", "-j8", "OBJ=" + os.path.join(base, "obj")]
    else:
        head = worktree(SCRIP, WT); worktree(os.path.normpath(HARNESS), WH); tree(CORPUS, WC, corpus_head, SPARSE)
        dirty = carry_diff(SCRIP, WT, ["src", "Makefile", "bootstrap", "tools"]); make = ["make", "-j8"]
    how = swap_fatal(WT)
    t0 = time.time(); b = subprocess.run(make, cwd=WT, capture_output=True, text=True, errors="replace"); wall = time.time() - t0
    if b.returncode != 0:
        sys.stdout.write("\n".join((b.stdout + b.stderr).split("\n")[-20:]) + "\n"); refuse("the census worktree did not build (make rc %d)" % b.returncode)
    names = op_names(WT); grand = {}; total = 0; graded = 0; failed = []; langs = {}; sites = []
    def work(prog):
        rc, err = compile_one(WT, prog, timeout); rd = []; raw = []; first = ""
        for ln in err.split("\n"):
            m = LINE.match(ln)
            if m:
                rd.append((int(m.group(2)), int(m.group(1))))
                if lines: raw.append(ln)
            elif not first and ln.strip(): first = ln.strip()[:160]
        return rc, rd, raw, first
    base_reads = {}
    if board:
        for lang in sorted({LANG[p] for p in progs if p in LANG}):
            e = os.path.join(CENSUS, "empty-" + lang + suite_of(lang)[3]); os.makedirs(CENSUS, exist_ok=True); open(e, "w").close(); base_reads[lang] = work(e)[1]
    with concurrent.futures.ThreadPoolExecutor(workers) as ex: results = list(ex.map(work, progs))
    for prog, (rc, rd, raw, first) in zip(progs, results):
        by = {}
        for op, off in rd:
            k = names.get(op, "op%s" % op); by[k] = by.get(k, 0) + 1; grand[k] = grand.get(k, 0) + 1
        n = sum(by.values()); total += n; graded += n if not ops else sum(by.get(o, 0) for o in ops)
        if rc != 0: failed.append("%s rc=%s" % (os.path.basename(prog), rc))
        if not board:
            print("ZOP_UNBACKED_CENSUS program=%s rc=%s total=%d %s" % (os.path.basename(prog), rc, n, " ".join("%s=%d" % kv for kv in sorted(by.items(), key=lambda kv: -kv[1]))))
            for ln in raw: print("  " + ln)
            continue
        lang = LANG.get(prog, "-"); L = langs.setdefault(lang, {"programs": 0, "screaming": 0, "reads": 0, "own": 0, "own_p": 0, "bad": 0, "hang": 0, "first": "", "err": "", "kinds": {}})
        L["programs"] += 1; nb = len(base_reads.get(lang, []))
        if rc == "HANG": L["hang"] += 1
        if rc != 0:
            L["bad"] += 1
            if not L["first"]: L["first"], L["err"] = os.path.basename(prog).rsplit(".", 1)[0], ("HANG" if rc == "HANG" else first)
        if n:
            L["screaming"] += 1; L["reads"] += n; L["own"] += max(0, n - nb); L["own_p"] += 1 if n > nb else 0
            for k, c in by.items(): kk = L["kinds"].setdefault(k, [0, 0]); kk[0] += c; kk[1] += 1
            sites.extend("%s\t%s\t%s\t%d" % (lang, os.path.basename(prog).rsplit(".", 1)[0], names.get(op, "op%s" % op), off) for op, off in rd)
    if board:
        if tsv: open(tsv, "w").write("\n".join(sites) + ("\n" if sites else ""))
        for lang in [l for l in MASTERS if l in langs] + [l for l in langs if l not in MASTERS]:
            L = langs[lang]; print("UNBACKED_BOARD lang=%s programs=%d screaming=%d reads=%d" % (lang, L["programs"], L["screaming"], L["reads"]))
            for k, (c, pc) in sorted(L["kinds"].items(), key=lambda kv: (-kv[1][0], kv[0])): print("UNBACKED_KIND lang=%s op=%s reads=%d programs=%d" % (lang, k, c, pc))
            bl = base_reads.get(lang, [])
            if bl:
                print("UNBACKED_BASE lang=%s reads=%d kinds=%d" % (lang, len(bl), len({op for op, _ in bl}))); print("UNBACKED_OWN lang=%s reads=%d programs=%d" % (lang, L["own"], L["own_p"]))
            print('UNBACKED_NOTE lang=%s compile_rc_nonzero=%d hang=%d first=%s err="%s"' % (lang, L["bad"], L["hang"], L["first"] or "-", L["err"].replace('"', "'")))
    print("ZOP_UNBACKED_CENSUS_TOTAL programs=%d total=%d graded=%d ops=%s by_op=%s tree=%s%s worktree=%s swap=%s build_s=%.1f"
          % (len(progs), total, graded, ",".join(ops) if ops else "all", ",".join("%s:%d" % kv for kv in sorted(grand.items(), key=lambda kv: -kv[1])) or "-", head[:9],
             "+dirty" if dirty else "", WT, how, wall))
    if failed and not board: refuse("a program did not compile under the count line: " + "; ".join(failed))
    sys.exit(0 if graded == 0 else 1)
if __name__ == "__main__":
    main()

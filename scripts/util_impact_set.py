#!/usr/bin/env python3
"""util_impact_set.py --root DIR --commit REV [--base REV] [--proof [--why]] [--table F] [--scripts DIR] [--corpus DIR] [--repo NAME]
THE CHANGE-IMPACT SET OF ONE COMMIT AND THE PROOF IT OWES (DESIGN-PLAN box-budget step 3, CTO-474/475/478, the coo 2026-11-04; box-scheduler step 13,
CTO-496, the president 2026-11-05). It guesses no second map: the languages and features come from the ONE carrier map the landing selector already
uses (test_area_smoke.sh --list-only over area_map.tsv), and the proof from the declared table impact_proof.tsv beside it.

Without --proof, one line (base defaults to commit^), then one SHELL line per named feature:
  IMPACT lang=<a,b,..|none> core=<N> shells=<M> shared=<K> files=<F> base=<rev> commit=<rev> dirty=<0|1>
    lang: the languages the range touches (every master language when a shared node is touched); core: the core entries of those masters
    (PARTITION.tsv rows whose part is core); shells: the feature shells the range names.
With --proof, the proof sized by what the commit touches (a Makefile line owes the build gate, not the eight smokes):
  PROOF arms=<A> smokes=<S> gates=<G> owes=<tokens> langs=<a,b|none> shared=<K> files=<F> unwired=<U> nosmoke=<a,b|-> base=<rev> commit=<rev> dirty=<0|1>
  ARM <kind> <command>      one per command the lander runs; kind is build, preflight, area, smoke or gate; A counts them, S the smokes, G the gates
  FILE <repo-relative path> <carrier> <owes>     (--why) the table row that decided each touched file
--commit must be the tree's HEAD: the carrier map reads the working tree, and dirty=1 says uncommitted edits are counted in.
rc 0 printed; rc 2 refused (no root, no commit, a table row or declared script missing, the area smoke refused or printed no map).
"""
import fnmatch, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPOS = ("SCRIP", "harness", "corpus", ".github")
TOKENS = {"-", "build", "preflight", "area", "refgates", "buildgates", "self"}

def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv and sys.argv.index(name) + 1 < len(sys.argv) else default

def refuse(tag, why):
    print("%s REFUSE(2): %s" % (tag, why))
    sys.exit(2)

def git(root, *a):
    return subprocess.run(["git", "-C", root] + list(a), capture_output=True, text=True)

def commit_of(root, rev, tag, what):
    r = git(root, "rev-parse", "--verify", "-q", rev + "^{commit}")
    if r.returncode != 0:
        refuse(tag, "%s %s is not a commit in %s" % (what, rev, root))
    return r.stdout.strip()

def load_table(path, tag):
    if not os.path.isfile(path):
        refuse(tag, "no proof table at %s" % path)
    rules, directives = [], {}
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line.strip() or line.startswith("#"):
            continue
        c = line.split("\t")
        if len(c) != 3 or not all(x.strip() for x in c):
            refuse(tag, "%s:%d is not repo<TAB>carrier<TAB>owes" % (path, n))
        if c[0] == "@":
            directives[c[1]] = c[2].split()
            continue
        if c[0] not in REPOS:
            refuse(tag, "%s:%d names repo %s, not one of %s" % (path, n, c[0], " ".join(REPOS)))
        owes = set(c[2].split(","))
        if not owes <= TOKENS:
            refuse(tag, "%s:%d owes %s: not in %s" % (path, n, ",".join(sorted(owes - TOKENS)), ",".join(sorted(TOKENS))))
        rules.append((c[0], c[1], owes))
    return rules, directives

def carrier_matches(carrier, rel):
    if carrier == ".":
        return True
    if carrier.endswith("/"):
        return rel.startswith(carrier)
    return fnmatch.fnmatchcase(rel, carrier)

def rule_for(rules, repo, rel, tag):
    best = None
    for r, carrier, owes in rules:
        if r == repo and carrier_matches(carrier, rel) and (best is None or len(carrier) > len(best[0])):
            best = (carrier, owes)
    if best is None:
        refuse(tag, "no row of the proof table covers %s:%s (every repo carries a `.` catch-all row)" % (repo, rel))
    return best

def area_impact(root, corpus, base_sha, tag):
    env = dict(os.environ, AREA_SMOKE_BASE=base_sha, AREA_SMOKE_ROOT=root, S4E_HOME=os.path.dirname(root))
    p = subprocess.run(["bash", os.path.join(HERE, "test_area_smoke.sh"), "--list-only"], cwd=root, capture_output=True, text=True, env=env, timeout=300)
    out = p.stdout + p.stderr
    if "AREA_SMOKE REFUSE" in out:
        refuse(tag, "the area smoke refused: %s" % next(l for l in out.splitlines() if "AREA_SMOKE REFUSE" in l)[:300])
    maps = [l[len("AREA_SMOKE_MAP "):] for l in out.splitlines() if l.startswith("AREA_SMOKE_MAP ")]
    if not maps and "AREA_SMOKE" not in out:
        refuse(tag, "test_area_smoke.sh --list-only printed no AREA_SMOKE line")
    tests = os.path.join(corpus, "tests")
    masters = sorted(d for d in os.listdir(tests) if os.path.isfile(os.path.join(tests, d, "PARTITION.tsv"))) if os.path.isdir(tests) else []
    langs, feats, shared, files = set(), set(), 0, set()
    for m in maps:
        f, _, rhs = m.partition(" -> ")
        files.add(f.strip())
        for t in rhs.split():
            if t == "*": shared += 1
            elif t == "-": pass
            elif t.startswith("lang:"): langs.add(t[5:])
            else: feats.add(t)
    if shared:
        langs |= set(masters)
    core = 0
    for l in sorted(langs):
        pp = os.path.join(tests, l, "PARTITION.tsv")
        if os.path.isfile(pp):
            core += sum(1 for r in open(pp, encoding="utf-8", errors="replace") if r.rstrip("\n").split("\t")[1:2] == ["core"])
    return dict(langs=langs, feats=feats, shared=shared, files=files, core=core)

def wired_gates(scripts, tag):
    p = os.path.join(scripts, "gate_wiring.tsv")
    if not os.path.isfile(p):
        refuse(tag, "no gate_wiring.tsv at %s: a WIRED gate cannot be told from debt" % p)
    return {c[0] for c in (l.rstrip("\n").split("\t") for l in open(p, encoding="utf-8") if not l.startswith("#")) if len(c) > 1 and c[1] == "WIRED"}

def gate_texts(scripts):
    out = {}
    for n in sorted(os.listdir(scripts)):
        if n.startswith("test_gate_") and n.endswith(".sh"):
            out[n] = open(os.path.join(scripts, n), encoding="utf-8", errors="replace").read()
    return out

def need_script(scripts, name, why, tag):
    if not os.path.isfile(os.path.join(scripts, name)):
        refuse(tag, "%s names %s, which is not a file in %s" % (why, name, scripts))
    return name

def main():
    if "-h" in sys.argv or "--help" in sys.argv:
        print(__doc__.strip()); return 0
    proof = "--proof" in sys.argv
    tag = "PROOF" if proof else "IMPACT"
    root = os.path.abspath(arg("--root", "SCRIP"))
    home = os.path.dirname(root)
    corpus = os.path.abspath(arg("--corpus", os.path.join(home, "corpus")))
    scripts = os.path.abspath(arg("--scripts", HERE))
    table = os.path.abspath(arg("--table", os.path.join(scripts, "impact_proof.tsv")))
    repo = arg("--repo", os.path.basename(root))
    if not os.path.exists(os.path.join(root, ".git")):
        refuse(tag, "no git tree at %s" % root)
    head = commit_of(root, arg("--commit", "HEAD"), tag, "commit")
    tip = git(root, "rev-parse", "HEAD").stdout.strip()
    if head != tip:
        refuse(tag, "--commit %s is not the tree's HEAD %s: the carrier map reads the working tree, so check the commit out first" % (head[:9], tip[:9]))
    dirty = 1 if git(root, "status", "--porcelain", "--untracked-files=no").stdout.strip() else 0
    base = commit_of(root, arg("--base", head + "^"), tag, "base")
    if not proof:
        a = area_impact(root, corpus, base, tag)
        print("IMPACT lang=%s core=%d shells=%d shared=%d files=%d base=%s commit=%s dirty=%d" % (",".join(sorted(a["langs"])) or "none", a["core"], len(a["feats"]), a["shared"], len(a["files"]), base[:9], head[:9], dirty))
        for f in sorted(a["feats"]):
            print("SHELL %s" % f)
        return 0
    if repo not in REPOS:
        refuse(tag, "root %s is not one of %s (pass --repo)" % (os.path.basename(root), " ".join(REPOS)))
    rules, directives = load_table(table, tag)
    mb = git(root, "merge-base", head, base).stdout.strip() or base
    d = git(root, "diff", "--name-only", "--no-renames", "-z", mb, head)
    files = sorted(f for f in d.stdout.split("\0") if f)
    decided = [(f,) + rule_for(rules, repo, f, tag) for f in files]
    owes = set().union(*[o for _, _, o in decided]) - {"-"} if decided else set()
    arms, nosmoke, unwired = [], [], 0
    def arm(kind, cmd):
        if (kind, cmd) not in arms:
            arms.append((kind, cmd))
    if "build" in owes:
        arm("build", "cd SCRIP && make -j8")
    if "preflight" in owes:
        arm("preflight", "cd SCRIP && make preflight")
    langs, shared = set(), 0
    if any("area" in o for _, _, o in decided):
        a = area_impact(root, corpus, base, tag)
        langs, shared = a["langs"], a["shared"]
        if a["langs"] or a["feats"] or a["shared"]:
            arm("area", "cd SCRIP && bash ../harness/scripts/test_area_smoke.sh")
        names = directives.get("shared-smokes", []) if shared else sorted(langs)
        if shared and not names:
            refuse(tag, "a shared node is touched and the table declares no @ shared-smokes")
        for l in names:
            if shared or os.path.isfile(os.path.join(scripts, "test_smoke_%s.sh" % l)):
                arm("smoke", "bash harness/scripts/%s" % need_script(scripts, "test_smoke_%s.sh" % l, "the @ shared-smokes directive", tag))
            else:
                nosmoke.append(l)
    if "buildgates" in owes:
        for g in directives.get("buildgates", []):
            arm("gate", "bash harness/scripts/%s" % need_script(scripts, g, "the @ buildgates directive", tag))
    for f, _, o in decided:
        base_name = os.path.basename(f)
        if "self" in o and os.path.isfile(os.path.join(scripts, base_name)) and f == "scripts/" + base_name:
            arm("gate", "bash harness/scripts/%s" % base_name)
    if any("refgates" in o for _, _, o in decided):
        wired, texts = wired_gates(scripts, tag), gate_texts(scripts)
        named = set()
        for f, _, o in decided:
            if "refgates" in o:
                named |= {g for g, t in texts.items() if f in t and g != os.path.basename(f)}
        unwired = len(named - wired)
        for g in sorted(named & wired):
            arm("gate", "bash harness/scripts/%s" % g)
    smokes, gates = sum(1 for k, _ in arms if k == "smoke"), sum(1 for k, _ in arms if k == "gate")
    print("PROOF arms=%d smokes=%d gates=%d owes=%s langs=%s shared=%d files=%d unwired=%d nosmoke=%s base=%s commit=%s dirty=%d"
          % (len(arms), smokes, gates, ",".join(sorted(owes)) or "-", ",".join(sorted(langs)) or "none", shared, len(files), unwired, ",".join(sorted(nosmoke)) or "-", base[:9], head[:9], dirty))
    for kind, cmd in arms:
        print("ARM %s %s" % (kind, cmd))
    if "--why" in sys.argv:
        for f, carrier, o in decided:
            print("FILE %s %s %s" % (f, carrier, ",".join(sorted(o))))
    return 0

if __name__ == "__main__":
    sys.exit(main())

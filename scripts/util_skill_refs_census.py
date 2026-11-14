#!/usr/bin/env python3
"""util_skill_refs_census.py -- EVERY NAME A SKILL SPEAKS IS A LIVE NAME (DESIGN-PLAN skills-complete, the cio 2026-11-07; Lon in the cio's window
09:1x, verbatim: "I suspect you'll need to fully scrutinze the set of skill files, their granularity, their completeness and accuracy." / "Do we have
skill files partitioned properly. Are they tied properly to what triggers them when they are needed and no when they are not needed?").

The skills in the skills folder of the .github repo, <name>/{SKILL.md,reference.md}, are the one knowledge store of thirty seats, so a file, script, bus verb or flag a
skill names that the live tree does not have misleads every seat (the 2026-11-07 audit: 254 missing references, GOAL-CEO.md cited as a file in
eleven skills, box_controller.sh named as the live controller, a status column reading "open" for steps already green). This census reads every
skill against the tree the way the fleet-needs reports asked (knowledge drift, class 10 of the three-month history) and is the probe of steps 0, 1,
3 and 8 of the plan (the skills_complete STEPS.tsv in the designs of the harness repo).

  --check [--only SKILL]   one line `SKILL_REFS files=F refs=N missing=M unknown_verb=V missing_flag=G allowed=A` then one `MISSING <skill>:<line> <kind> <token>`
                           line per gap; rc 0 when M, V and G are all 0; rc 1 otherwise; rc 2 when the skills dir or the bus script is absent
  --descriptions           `SKILL_DESCRIPTIONS skills=S total_chars=C over_cap=O gated_unmarked=U` (cap --desc-cap, default 240 chars; a skill the
                           gate names must say "REQUIRED by the skill gate"); rc 0 when O and U are 0
  --tables                 `SKILL_TABLES plans_missing=P verbs_missing=V` (every STEPS.tsv plan of the corpus repo with a test_design_*_steps.sh harness is
                           named in design-plans/SKILL.md; every top-level case label of s4e_msg.sh is named in fleet-bus/SKILL.md section 2); rc 0 when both 0
  --tsv OUT                also write every reference as skill, token, kind, status, line
  --allow FILE             the allow list (default SKILL_REFS_ALLOW.tsv in the scripts of the harness repo): `token<TAB>reason`, one per placeholder a skill uses on
                           purpose (a pattern such as _steps.sh); an allowed token counts in allowed=, never in missing=
  --self-test              plants a scratch skills dir (one live file, one missing file, one dead verb, one dead flag, one allowed placeholder) in four scratch
                           repo directories and reads it: rc 0 when the counts come out 1/1/1/1 and a clean skill reads 0
  --scrip DIR --corpus DIR --harness DIR --github DIR
                           the four repo directories the names are looked up in (the absolute model, harness_paths.py: each defaults to S4E_SCRIP,
                           S4E_CORPUS, S4E_HARNESS and S4E_GITHUB, else the one-disk checkout, else the sibling under --root)
  --root DIR               the root: its top-level files and the sibling fallback of the four directories (default S4E_HOME, else this script's grandparent)
A token under /home/resources is a ledger and counts ok when the path exists. A token with no slash is looked for under the usual script and
corpus dirs, then by basename anywhere under the four repos (a real file named without its path is ok). A token with a glob or placeholder character
(* < > { }) is skipped. The three exit codes are the gate law (skill gates-and-witnesses section 1).
"""
import os, re, sys, glob, tempfile

EXT = r"(?:sh|py|tsv|md|c|h|s|cpp|inc|csv|txt|pl|icn|sno|sc|pas|raku)"
FILE_RE = re.compile(r"[A-Za-z0-9_./\-]+\." + EXT + r"\b")
VERB_RE = re.compile(r"s4e_msg\.sh\s+([a-z][a-z_-]*)\b")
FLAG_RE = re.compile(r"([A-Za-z0-9_./\-]+\.(?:sh|py))((?:\s+[^\s`]+){0,6}?)\s+(--[a-z][a-z0-9-]*)")
REPOS = ("SCRIP", "corpus", "harness", ".github")
REPO_FLAGS = {"SCRIP": "--scrip", "corpus": "--corpus", "harness": "--harness", ".github": "--github"}
SEARCH = [("", ""), ("harness", "scripts"), (".github", "scripts"), (".github", ""), ("SCRIP", ""), ("corpus", ""), ("harness", ""), ("SCRIP", "src"), ("SCRIP", "src/runtime/rt"), ("SCRIP", "src/runtime/rtx"), ("corpus", "tests"), ("corpus", "packages")]  # one-disk: not a path
SKIP_WORDS = {"ALL.sh", "e.g.", "i.e.", "vs.", "etc.", "x86_64.s", "s4e.sh", "v2.0"}


def root_of(argv):
    if "--root" in argv:
        return os.path.abspath(argv[argv.index("--root") + 1])
    return os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def dirs_of(argv, root):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import harness_paths
    live = {"SCRIP": harness_paths.scrip(root), "corpus": harness_paths.corpus(root), "harness": harness_paths.harness(root), ".github": harness_paths.github(root)}
    return {r: os.path.abspath(argv[argv.index(REPO_FLAGS[r]) + 1]) if REPO_FLAGS[r] in argv else str(live[r]) for r in REPOS}


def read_allow(path):
    allow = {}
    if path and os.path.isfile(path):
        for ln in open(path, errors="replace"):
            if not ln.strip() or ln.startswith("#"):
                continue
            parts = ln.rstrip("\n").split("\t")
            allow[parts[0]] = parts[1] if len(parts) > 1 else ""
    return allow


def bus_verbs(bus):
    verbs = set()
    if not os.path.isfile(bus):
        return verbs
    for ln in open(bus, errors="replace"):
        m = re.match(r"^  ([a-z][a-z_|-]*)\)\s", ln)   # the top-level case labels sit at exactly two spaces; nested cases deeper
        if m:
            for v in m.group(1).split("|"):
                verbs.add(v)
    return verbs


class Census:
    def __init__(self, dirs, root, skills_dir, bus, allow):
        self.dirs, self.root, self.skills_dir, self.bus, self.allow = dirs, root, skills_dir, bus, allow
        self.verbs = bus_verbs(bus)
        self.basenames = set()
        for extra in ("/home/resources/progress", "/home/resources/postoffice", "/home/resources/manuals"):
            for dp, dn, fn in os.walk(extra):
                if "/archive" in dp or "/tasks" in dp or "/claims" in dp:
                    continue
                for f in fn:
                    self.basenames.add(f)
        if os.path.isdir(root):
            for f in os.listdir(root):
                if os.path.isfile(os.path.join(root, f)):
                    self.basenames.add(f)
        for top in self.dirs.values():
            for dp, dn, fn in os.walk(top):
                if "/.git/" in dp or dp.endswith("/.git") or "/objdir" in dp or "/out/" in dp or "/.claude/" in dp:
                    continue
                for f in fn:
                    self.basenames.add(f)

    def at(self, rel):
        first, _, rest = rel.partition("/")
        if first in self.dirs:
            return os.path.join(self.dirs[first], rest)
        return os.path.join(self.root, rel)

    def under(self, repo, sub, name):
        return self.at(name) if repo == "" else os.path.join(self.dirs[repo], sub, name)

    def exists(self, tok):
        t = tok.strip("`'\",;:()<>")
        t = re.sub(r"^\./", "", t)
        if any(c in t for c in "*<>{}") or t.startswith(("_", ".", "-")) or re.fullmatch(r"([a-z]|prog|foo|bar|name)\.[a-z]+", t) or "//" in t:
            return "glob"   # a shape (_suite.sh, .task.md) or an example name (prog.sno, w.pl), never a file
        t = re.sub(r"\.(c|cpp|s|py|sh)/\.h$", r".\1", t)   # the pair form x.c/.h names x.c and x.h
        if t.startswith("/"):
            return "ok" if os.path.exists(t) or os.path.basename(t) in self.basenames else "missing"
        cands = [self.at(t)] + [self.under(r, s, t) for r, s in SEARCH[1:]] if "/" in t else [self.under(r, s, t) for r, s in SEARCH]
        for c in cands:
            if os.path.exists(c):
                return "ok"
        return "ok" if os.path.basename(t) in self.basenames else "missing"

    def script_path(self, scr):
        base = os.path.basename(scr)
        for r, s in SEARCH:
            c = self.under(r, s, scr if "/" in scr else base)
            if os.path.isfile(c):
                return c
        for top in self.dirs.values():
            for dp, dn, fn in os.walk(top):
                if "/.git/" in dp or dp.endswith("/.git") or "/.claude/" in dp:
                    continue
                if base in fn:
                    return os.path.join(dp, base)
        return None

    def rows(self, only=None):
        out = []
        paths = sorted(glob.glob(os.path.join(self.skills_dir, "*", "SKILL.md")) + glob.glob(os.path.join(self.skills_dir, "*", "reference.md")))
        for path in paths:
            skill = os.path.relpath(path, self.skills_dir)
            if only and not skill.startswith(only + "/"):
                continue
            for i, ln in enumerate(open(path, errors="replace").read().split("\n"), 1):
                ln = re.sub(r"https?://\S+", "", ln)
                toks = set()
                for m in FILE_RE.finditer(ln):
                    t = m.group(0)
                    if t in SKIP_WORDS or re.fullmatch(r"\d+(\.\d+)+", t) or re.fullmatch(r"[0-9.]+s", t):
                        continue
                    toks.add(t)
                for t in sorted(toks):
                    st = self.exists(t)
                    if st == "glob":
                        continue
                    if st == "missing" and t in self.allow:
                        st = "allowed"
                    out.append((skill, t, "file", st, i))
                for m in VERB_RE.finditer(" ".join(re.findall(r"`([^`\n]+)`", ln))):
                    v = m.group(1)
                    out.append((skill, "s4e_msg.sh " + v, "verb", "ok" if v in self.verbs else "unknown-verb", i))
                for m in FLAG_RE.finditer(ln):
                    scr, flag = m.group(1), m.group(3)
                    if scr + " " + flag in self.allow:
                        out.append((skill, scr + " " + flag, "flag", "allowed", i)); continue
                    sp = self.script_path(scr)
                    if sp is None:
                        continue   # the file row above already reads missing
                    body = open(sp, errors="replace").read()
                    ok = flag in body
                    if not ok and os.path.basename(sp) == "s4e_msg.sh":
                        ok = any(flag in open(h, errors="replace").read() for h in glob.glob(os.path.join(self.dirs["harness"], "scripts", "s4e_*.sh")))  # one-disk: not a path
                    out.append((skill, scr + " " + flag, "flag", "ok" if ok else "missing-flag", i))
        return out, len(paths)


def check(c, only, tsv):
    rows, files = c.rows(only)
    if tsv:
        with open(tsv, "w") as f:
            f.write("skill\ttoken\tkind\tstatus\tline\n")
            for r in rows:
                f.write("\t".join(map(str, r)) + "\n")
    m = sum(1 for r in rows if r[3] == "missing"); v = sum(1 for r in rows if r[3] == "unknown-verb")
    g = sum(1 for r in rows if r[3] == "missing-flag"); a = sum(1 for r in rows if r[3] == "allowed")
    print("SKILL_REFS files=%d refs=%d missing=%d unknown_verb=%d missing_flag=%d allowed=%d" % (files, len(rows), m, v, g, a))
    seen = set()
    for skill, t, k, st, i in rows:
        if st in ("missing", "unknown-verb", "missing-flag") and (skill, t) not in seen:
            seen.add((skill, t)); print("MISSING %s:%d %s %s" % (skill, i, k, t))
    return 0 if m == 0 and v == 0 and g == 0 else 1


def frontmatter_description(path):
    txt = open(path, errors="replace").read()
    m = re.search(r"^description:\s*(.*?)(?=\n[a-z_-]+:|\n---)", txt, re.S | re.M)
    return re.sub(r"\s+", " ", m.group(1)).strip() if m else ""


def gated_skills(harness):
    gate = os.path.join(harness, "scripts", "s4e_skill_gate.py")
    if not os.path.isfile(gate):
        return set()
    body = open(gate, errors="replace").read()
    m = re.search(r"RULES\s*=\s*\[(.*?)\n\]", body, re.S)
    return set(re.findall(r'"([a-z][a-z0-9-]*)"', m.group(1))) if m else set()


def descriptions(c, cap):
    skills = sorted(glob.glob(os.path.join(c.skills_dir, "*", "SKILL.md")))
    gated = gated_skills(c.dirs["harness"]); total = over = unmarked = 0
    for p in skills:
        name = os.path.basename(os.path.dirname(p)); d = frontmatter_description(p); total += len(d)
        if len(d) > cap:
            over += 1; print("OVER_CAP %s %d chars" % (name, len(d)))
        if name in gated and "REQUIRED by the skill gate" not in d:
            unmarked += 1; print("GATED_UNMARKED %s" % name)
    print("SKILL_DESCRIPTIONS skills=%d total_chars=%d over_cap=%d gated_unmarked=%d cap=%d" % (len(skills), total, over, unmarked, cap))
    return 0 if over == 0 and unmarked == 0 else 1


def tables(c):
    plans = []
    for st in glob.glob(os.path.join(c.dirs["corpus"], "**", "STEPS.tsv"), recursive=True):  # one-disk: not a path
        d = os.path.basename(os.path.dirname(st))
        if glob.glob(os.path.join(c.dirs["harness"], "scripts", "test_design_%s_steps.sh" % d)):  # one-disk: not a path
            plans.append(d)
    dp = os.path.join(c.skills_dir, "design-plans", "SKILL.md")
    body = open(dp, errors="replace").read() if os.path.isfile(dp) else ""
    pm = [d for d in sorted(plans) if ("/%s/" % d) not in body and d.replace("_", "-") not in body]
    for d in pm:
        print("PLAN_MISSING %s" % d)
    fb = os.path.join(c.skills_dir, "fleet-bus", "SKILL.md")
    fbody = open(fb, errors="replace").read() if os.path.isfile(fb) else ""
    sec = re.search(r"## 2\..*?(?=\n## 3\.)", fbody, re.S)
    sec = sec.group(0) if sec else ""
    vm = [v for v in sorted(c.verbs) if not re.search(r"(?<![a-z_-])%s(?![a-z_-])" % re.escape(v), sec)]
    for v in vm:
        print("VERB_MISSING %s" % v)
    print("SKILL_TABLES plans=%d plans_missing=%d verbs=%d verbs_missing=%d" % (len(plans), len(pm), len(c.verbs), len(vm)))
    return 0 if not pm and not vm else 1


def self_test():
    d = tempfile.mkdtemp(prefix="s4e-skill-refs.")
    dirs = {r: os.path.join(d, "repo-" + r.strip(".")) for r in REPOS}
    for p in dirs.values():
        os.makedirs(p)
    scripts = os.path.join(dirs["harness"], "scripts"); os.makedirs(scripts); os.makedirs(os.path.join(d, "skills/one")); os.makedirs(os.path.join(d, "skills/clean"))  # one-disk: not a path
    open(os.path.join(scripts, "live.sh"), "w").write("#!/bin/bash\ncase $1 in --real) ;; esac\n")
    open(os.path.join(scripts, "s4e_msg.sh"), "w").write("case $1 in\n  send) ;;\n  next) ;;\nesac\n")
    open(os.path.join(d, "skills/one/SKILL.md"), "w").write("---\ndescription: x\n---\nrun `live.sh --real` then `live.sh --gone`; `gone.sh`; `s4e_msg.sh send`; `s4e_msg.sh fly`; `prog_steps.sh`\n")
    open(os.path.join(d, "skills/clean/SKILL.md"), "w").write("---\ndescription: y\n---\n`live.sh --real` and `s4e_msg.sh next`\n")
    allow = {"prog_steps.sh": "a placeholder"}
    c = Census(dirs, d, os.path.join(d, "skills"), os.path.join(scripts, "s4e_msg.sh"), allow)
    rows, files = c.rows("one")
    got = {k: sum(1 for r in rows if r[3] == k) for k in ("missing", "unknown-verb", "missing-flag", "allowed")}
    want = {"missing": 1, "unknown-verb": 1, "missing-flag": 1, "allowed": 1}
    rows2, _ = c.rows("clean")
    clean = all(r[3] == "ok" for r in rows2) and len(rows2) == 4
    ok = got == want and clean
    print("SKILL_REFS_SELFTEST planted=%s read=%s clean_ok=%s -> %s" % (want, got, clean, "ok" if ok else "RED"))
    return 0 if ok else 1


def main(argv):
    if "--self-test" in argv:
        return self_test()
    root = root_of(argv)
    dirs = dirs_of(argv, root)
    skills_dir = os.path.join(dirs[".github"], "skills"); bus = os.path.join(dirs["harness"], "scripts", "s4e_msg.sh")  # one-disk: not a path
    if not os.path.isdir(skills_dir) or not os.path.isfile(bus):
        print("REFUSE(2) [util_skill_refs_census]: no skills dir at %s or no bus at %s" % (skills_dir, bus), file=sys.stderr); return 2
    allow_path = argv[argv.index("--allow") + 1] if "--allow" in argv else os.path.join(dirs["harness"], "scripts", "SKILL_REFS_ALLOW.tsv")  # one-disk: not a path
    c = Census(dirs, root, skills_dir, bus, read_allow(allow_path))
    if "--descriptions" in argv:
        return descriptions(c, int(argv[argv.index("--desc-cap") + 1]) if "--desc-cap" in argv else 240)
    if "--tables" in argv:
        return tables(c)
    only = argv[argv.index("--only") + 1] if "--only" in argv else None
    tsv = argv[argv.index("--tsv") + 1] if "--tsv" in argv else None
    return check(c, only, tsv)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

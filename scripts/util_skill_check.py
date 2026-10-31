#!/usr/bin/env python3
"""util_skill_check.py <name>... -- A FLEET SKILL IS WELL-FORMED AND CARRIES ITS SEVEN PARTS (ceo CEO-2071). Reads .github/skills/<name>/SKILL.md
beside this harness. GREEN rc 0 when the file exists, opens with YAML frontmatter whose `name:` equals the folder and whose `description:` is 40 to
1024 characters, is 3 to 40 KB, and carries the seven section markers a seat needs: the oracle (## 1), the manuals under /home/resources/manuals
(## 2), the source map (## 3), the ARCH pages (## 4), the suites and their runners (## 5), the debugging order (## 6) and the rulings (## 7).
RED rc 1 names each missing part. REFUSE rc 2 with no name. The DONE-WHEN of every skill row; red on an absent skill by construction.
--parser-constructs <name> (CEO-2075): greps each SCRIP/bootstrap/parser_*.sc for the construct families a parser-as-pattern is made of (the
Compiland shape, Shift and Reduce, immediate and deferred assignment, the memo table, the counter stack, PushVal, tail loops, the token convention,
keyword lookups, FENCE, FLUSH, ARBNO, cursor pairs, the anchored nested match, the preprocess stage, the driver tail, the module wrapper, the library,
the no-functions rule, the proving gates) and RED rc 1 names every family a parser carries that the skill does not name.
"""
import glob, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
MARKS = ["## 1", "## 2", "## 3", "## 4", "## 5", "## 6", "## 7", "/home/resources/manuals", "ARCH-", "harness/scripts", "monitor_run.sh"]
def check(name):
    p = os.path.join(ROOT, ".github", "skills", name, "SKILL.md")
    if not os.path.exists(p):
        return ["no file %s" % p]
    t = open(p, encoding="utf-8").read()
    why = []
    m = re.match(r"---\n(.*?)\n---\n", t, re.S)
    if not m:
        why.append("no frontmatter")
    else:
        fm = m.group(1)
        n = re.search(r"^name:\s*(\S+)\s*$", fm, re.M)
        d = re.search(r"^description:\s*(.+)$", fm, re.M)
        if not n or n.group(1) != name: why.append("frontmatter name != %s" % name)
        if not d or not (40 <= len(d.group(1)) <= 1024): why.append("description missing or not 40..1024 chars")
    sz = len(t.encode())
    if not (3072 <= sz <= 40960): why.append("size %d not in 3..40 KB" % sz)
    for k in MARKS:
        if k not in t: why.append("missing '%s'" % k)
    return why
FAMILIES = [
    ("compiland", r"Compiland\s*=", ["Compiland", "POS(0)", "RPOS(0)"]),
    ("shift-reduce", r"\*Shift\(|\*Reduce\(", ["Shift(", "Reduce("]),
    ("deferred-vs-immediate", r"\$ \w+|\. \*", ["IMMEDIATE", "DEFERRED"]),
    ("memo-table", r"\[thx\]", ["memo table", "[thx]"]),
    ("counter-stack", r"PushCounter|IncCounter|nTop\(\)|PopCounter", ["PushCounter", "IncCounter", "nTop()", "PopCounter"]),
    ("push-val", r"PushVal\(|PopVal\(", ["PushVal", "PopVal"]),
    ("tail-loop", r"\w+t\s*=\s*FENCE\(", ["TAIL LOOP", "RIGHT RECURSION"]),
    ("token-convention", r"\$' '\s*=|\$'  '\s*=", ["$' '", "$'  '"]),
    ("keyword-lookup", r"IDENT\(tx,|\w+T\[tx\]", ["IDENT(tx", "TABLE"]),
    ("fence", r"FENCE\(", ["FENCE"]),
    ("flush", r"FLUSH", ["FLUSH"]),
    ("arbno", r"ARBNO\(", ["ARBNO", "SHORTEST FIRST"]),
    ("cursor-pair", r"@\w+ .*@\w+", ["two cursors"]),
    ("anchored-nested-match", r"\? \(POS\(0\)", ["ANCHORED"]),
    ("preprocess-stage", r"^\w+PP:", ["PREPROCESS STAGE"]),
    ("driver-tail", r"^\w+Parse:|ModLinked", ["DRIVER TAIL", "ModLinked"]),
    ("module-wrapper", r"ModTree|ModEnd", ["mod_head.sc", "mod_tail.sc", "ModTree"]),
    ("library", r"tree\(|Push\(|Pop\(", ["ShiftReduce.sc", "counter.sc", "stack.sc", "tree.sc", "semantic.sc", "tdump.sc"]),
    ("no-functions", r"^function ", ["DEFINE NO FUNCTIONS", "test_gate_bootstrap_parsers_define_no_functions.sh"]),
    ("proving", None, ["run_scrip_parser.sh", "test_bootstrap_parsers.py", "test_gate_snocone_parsers_match_the_c_parsers_tree_for_tree.sh",
                       "test_gate_bootstrap_parse_stage_ir_identity.sh", "util_parser_sc_census.py", "util_parser_sc_grade.sh"]),
]
def parser_constructs(name):
    p = os.path.join(ROOT, ".github", "skills", name, "SKILL.md")
    if not os.path.exists(p):
        print("RED  %s: no file %s" % (name, p)); return 1
    t = open(p, encoding="utf-8").read()
    parsers = sorted(glob.glob(os.path.join(ROOT, "SCRIP", "bootstrap", "parser_*.sc")))
    if not parsers:
        print("REFUSE(2): no SCRIP/bootstrap/parser_*.sc beside this harness"); return 2
    srcs = {os.path.basename(f): open(f, encoding="utf-8", errors="replace").read() for f in parsers}
    rc = 0
    for fam, rx, terms in FAMILIES:
        where = [b for b, s in srcs.items() if rx is None or re.search(rx, s, re.M)]
        if not where:
            print("skip %s: no parser carries it" % fam); continue
        missing = [k for k in terms if k not in t]
        if missing:
            print("RED  %s: parsers %s carry it, the skill lacks %s" % (fam, " ".join(where), " ".join(missing))); rc = 1
        else:
            print("OK   %s (%d parsers)" % (fam, len(where)))
    return rc
def main(names):
    if names and names[0] == "--parser-constructs":
        if len(names) != 2:
            print("REFUSE(2): usage: util_skill_check.py --parser-constructs <skill-name>"); return 2
        return parser_constructs(names[1])
    if not names:
        print("REFUSE(2): usage: util_skill_check.py <skill-name>... | --parser-constructs <skill-name>"); return 2
    rc = 0
    for n in names:
        why = check(n)
        print(("OK   %s" % n) if not why else ("RED  %s: %s" % (n, "; ".join(why))))
        rc = rc or (1 if why else 0)
    return rc
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

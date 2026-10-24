#!/usr/bin/env python3
# util_zeta_accessor_census.py -- THE ADDRESS-FORM CENSUS: EVERY SITE OF THE TEMPLATES AND THE EMITTER THAT ADDRESSES A CELL BY A FORM OF ITS OWN, COUNTED
# DOWN TO THE ONE ACCESSOR, ZCELL, THAT READS THE PLAN'S ZETA COLUMN (ceo CEO-1943/1944; Lon 2026-10-24 11:0x CDT, in-chat to the ceo, verbatim: "You must
# find a way to in the code templates, emitter and planner, to switch easily between the THREE ZETAS."). A cell's home is ONE fact, the plan row's zeta
# column (SPINE on RSP by default, ACTIVATION-FRAME on RBP when the planner's unbounded test forces it, STANDING through the RBP chain), and every site
# reaches a cell through ZCELL(owner, word, width) or ZCELL_ADDR(owner, word), which read the owner's plan row and emit the SPINE, ACT or STANDING form
# (ARCH-THREE-ZETAS-EMISSION.md section 2 and section 10 chunk 3b-2, the cto). Each counted form reaches a cell by an offset or a predicate of its own, a
# second decider beside the plan; the re-pointing of the templates at ZCELL makes the total fall, and nothing may make it rise.
# THE FORMS are the ceo's list of 2026-10-24 11:2x: x86_zop, x86_zref, ZRES, ZRES_SPINE, ZOPQ, ZOPD, ZOPQS, FR, FRQ, the rbp and rsp RDQ and RDD forms,
# x86_rsp_load64, x86_rsp_store64, x86_frame_*, xop_frame_slot, zls_frame_off, gen_frame_top, and (the ceo's ruling of 11:3x, one sentence: a helper that
# hands a template a cell operand and picks its own zeta -- rsp, rbp, the frame, the chain -- is a direct form, and only ZCELL and ZCELL_ADDR are not)
# ZRESD (RDD rbp or x86_zref), XSAQ (RDQ rbp or FRQ), ZLOC (x86_zref), ZTOS and ZTOSD (x86_ztos) and x86_ztos itself. A SITE is a line under SCRIP/src/templates or
# SCRIP/src/emitter where the form's name starts a word; a line holding it twice is one site, a line holding two forms is a site of each, and the total is
# the sum over the forms (the ceo's `grep -rF FORM src/templates src/emitter | wc -l` reading, word-bounded so that FR( is not read inside another name).
# The definitions count too. THE ALLOWED FORM is ZCELL and ZCELL_ADDR: their sites print as the RISING line beside the falling total, and the lines of
# their own definitions (from the head to the brace that closes it) are not counted, being the one place the direct forms may remain.
# THE CEILING is the first reading of these twenty-five forms, 1899 at SCRIP 65c05d8d0 and at the D0 parent e840d8e39 (the cuts before it: 10-24 11:1x
# harness f226390, the ceo's first fourteen forms, 480; 11:2x 3707cd2, nineteen forms down to ZCELL, 1871; each rise a RE-CUT of the census, never a
# regression): x86_zop 10, x86_zref 36, ZRES 112, ZRES_SPINE 4, ZOPQ 153, ZOPD 22, ZOPQS 7, FR 51, FRQ 1053, RDQ("rbp" 67, RDD("rbp" 23, RDQ("rsp" 112,
# RDD("rsp" 17, x86_rsp_load64 59, x86_rsp_store64 65, x86_frame_ 60, xop_frame_slot 14, zls_frame_off 3, gen_frame_top 3, ZRESD 9, XSAQ 13, ZLOC 1,
# ZTOS 1, ZTOSD 1, x86_ztos 3; ZCELL 0. A landing that lowers the total lowers CEILING here in the same landing (the census prints FALLEN and the number).
# USE: python3 harness/scripts/util_zeta_accessor_census.py [--at-most N] [--rev REV]   (N defaults to CEILING; --rev reads SCRIP's commit REV, not the tree)
# PRINTS: one line per form (its sites, then file:line,line,... grouped by file), the ZCELL line, and
#         ZETA_ACCESSOR_FORMS total=<n> forms=<f> ceiling=<c> bar=at-most-<N> zcell=<z> zcell_body=<b> files=<k> tree=<worktree|REV>
# EXIT: 0 total <= N; 1 total > N (a direct form came back, or N is below what is left); 2 could not measure (no SCRIP, no such REV, no source read).
import os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SCRIP = os.path.normpath(os.path.join(HERE, "..", "..", "SCRIP"))
DIRS = ("src/templates", "src/emitter")
EXTS = (".c", ".cpp", ".h", ".inc")
FORMS = [("x86_zop(", r"\bx86_zop\("), ("x86_zref(", r"\bx86_zref\("), ("ZRES(", r"\bZRES\("), ("ZRES_SPINE(", r"\bZRES_SPINE\("), ("ZOPQ(", r"\bZOPQ\("),
         ("ZOPD(", r"\bZOPD\("), ("ZOPQS(", r"\bZOPQS\("), ("FR(", r"\bFR\("), ("FRQ(", r"\bFRQ\("), ('RDQ("rbp"', r'\bRDQ\("rbp"'), ('RDD("rbp"', r'\bRDD\("rbp"'),
         ('RDQ("rsp"', r'\bRDQ\("rsp"'), ('RDD("rsp"', r'\bRDD\("rsp"'), ("x86_rsp_load64(", r"\bx86_rsp_load64\("), ("x86_rsp_store64(", r"\bx86_rsp_store64\("),
         ("x86_frame_", r"\bx86_frame_\w"), ("xop_frame_slot(", r"\bxop_frame_slot\("), ("zls_frame_off(", r"\bzls_frame_off\("), ("gen_frame_top()", r"\bgen_frame_top\(\)"),
         ("ZRESD(", r"\bZRESD\("), ("XSAQ(", r"\bXSAQ\("), ("ZLOC(", r"\bZLOC\("), ("ZTOS(", r"\bZTOS\("), ("ZTOSD(", r"\bZTOSD\("), ("x86_ztos(", r"\bx86_ztos\(")]
ALLOWED = re.compile(r"\bZCELL(?:_ADDR)?\(")
ALLOWED_HEAD = re.compile(r"^\s*(?:static\s+|inline\s+|extern\s+)*[A-Za-z_][\w\s\*&:<>,]*?\bZCELL(?:_ADDR)?\s*\(")
CEILING = 1899
args = sys.argv[1:]
at_most = CEILING
rev = None
if "--at-most" in args:
    try: at_most = int(args[args.index("--at-most") + 1])
    except (IndexError, ValueError): print("REFUSE(2): --at-most takes a whole number"); sys.exit(2)
if "--rev" in args:
    try: rev = args[args.index("--rev") + 1]
    except IndexError: print("REFUSE(2): --rev takes a SCRIP commit"); sys.exit(2)
def git(*a):
    return subprocess.run(["git", "-C", SCRIP] + list(a), capture_output=True)
texts = {}
if rev is None:
    for d in DIRS:
        top = os.path.join(SCRIP, d)
        if not os.path.isdir(top): print("REFUSE(2): no %s at %s" % (d, top)); sys.exit(2)
        for root, _, files in os.walk(top):
            for f in sorted(files):
                if f.endswith(EXTS):
                    p = os.path.join(root, f)
                    try: texts[os.path.relpath(p, SCRIP)] = open(p, encoding="utf-8", errors="replace").read().split("\n")
                    except OSError: pass
else:
    ls = git("ls-tree", "-r", "--name-only", rev, "--", *DIRS)
    if ls.returncode != 0: print("REFUSE(2): SCRIP has no commit %s: %s" % (rev, ls.stderr.decode(errors="replace").strip())); sys.exit(2)
    for path in ls.stdout.decode().split("\n"):
        if path.endswith(EXTS):
            show = git("show", "%s:%s" % (rev, path))
            if show.returncode == 0: texts[path] = show.stdout.decode("utf-8", errors="replace").split("\n")
if not texts: print("REFUSE(2): no template or emitter source read under %s%s" % (SCRIP, " at " + rev if rev else "")); sys.exit(2)
# THE ACCESSOR'S OWN BODY: a definition of ZCELL or ZCELL_ADDR opens a body on its head line or continues past it (a prototype ends in ";" with no "{");
# its lines run from the head to the "}" that brings the brace depth back to zero.
body = {}
for path, lines in texts.items():
    i = 0
    while i < len(lines):
        m = ALLOWED_HEAD.match(lines[i])
        if m and ("{" in lines[i][m.end():] or not lines[i].rstrip().endswith(";")):
            depth, opened, j = 0, False, i
            while j < len(lines):
                depth += lines[j].count("{") - lines[j].count("}")
                opened = opened or "{" in lines[j]
                body.setdefault(path, set()).add(j)
                if opened and depth <= 0: break
                j += 1
            i = j
        i += 1
ANY = re.compile("|".join(rx for _, rx in FORMS) + "|" + ALLOWED.pattern)
cand = {path: [(i, ln) for i, ln in enumerate(lines) if i not in body.get(path, set()) and ANY.search(ln)] for path, lines in texts.items()}
def sites_of(rx):
    sites = {}
    for path in sorted(cand):
        hits = [str(i + 1) for i, ln in cand[path] if rx.search(ln)]
        if hits: sites[path] = hits
    return sites
def show(label, sites):
    n = sum(len(h) for h in sites.values())
    print("  %-18s %4d  %s" % (label, n, " ".join("%s:%s" % (p, ",".join(h)) for p, h in sites.items())))
    return n
total = 0
for label, rx in FORMS: total += show(label, sites_of(re.compile(rx)))
zcell = show("ZCELL (allowed)", sites_of(ALLOWED))
zbody = sum(len(s) for s in body.values())
print("ZETA_ACCESSOR_FORMS total=%d forms=%d ceiling=%d bar=at-most-%d zcell=%d zcell_body=%d files=%d tree=%s"
      % (total, len(FORMS), CEILING, at_most, zcell, zbody, len(texts), rev or "worktree"))
if total < CEILING: print("FALLEN: the total is %d, below CEILING %d -- lower CEILING to %d in this script in the landing that made it fall" % (total, CEILING, total))
sys.exit(0 if total <= at_most else 1)

#!/usr/bin/env python3
# util_zeta_accessor_census.py -- THE ADDRESS-FORM CENSUS: EVERY SITE OF THE TEMPLATES AND THE EMITTER THAT ADDRESSES A CELL BY A FORM OF ITS OWN, COUNTED
# UNTIL ONE ACCESSOR READS THE PLAN'S ZETA COLUMN (ceo CEO-1943/1944; Lon 2026-10-24 11:0x CDT, in-chat to the ceo, verbatim: "You must find a way to in
# the code templates, emitter and planner, to switch easily between the THREE ZETAS."). A cell's home is ONE fact, the plan row's zeta column (SPINE on
# RSP by default, ACTIVATION-FRAME on RBP when the planner's unbounded test forces it, STANDING through the RBP chain), and every site reaches a cell
# through ONE ACCESSOR that reads it (ARCH-THREE-ZETAS-EMISSION.md section 2, ZCELL). Each form below chooses rsp or rbp by a predicate of its own, so
# every site naming one is a second decider; the re-pointing of the templates at the accessor makes this total fall, and nothing may make it rise.
# THE FORMS are the ceo's census of 2026-10-24 10:5x at SCRIP 65c05d8d0, counted the way it was counted (`grep -rF FORM src/templates src/emitter | wc -l`):
# a SITE is a line under SCRIP/src/templates or SCRIP/src/emitter holding the form's text, a line holding it twice is one site, a line holding two forms is a
# site of each, and the total is the sum over the forms. The definitions of the forms count too: the accessor deletes them or keeps them as its own body.
# THE CEILING is the first reading, 480 at SCRIP 65c05d8d0 (the same 480 at the D0 parent e840d8e39): RDQ("rbp" 67, RDD("rbp" 23, RDQ("rsp" 112,
# RDD("rsp" 17, x86_rsp_load64( 59, x86_rsp_store64( 65, x86_frame_ 60, x86_zref( 36, xop_frame_slot( 14, x86_zop( 10, ZOPQS( 7, ZRES_SPINE( 4,
# zls_frame_off( 3, gen_frame_top() 3. A landing that lowers the total lowers CEILING here in the same landing (the census says FALLEN and names the
# number); when the ceo names the accessor, its own definition becomes the one allowed site and the census counts the direct forms left.
# USE: python3 harness/scripts/util_zeta_accessor_census.py [--at-most N] [--rev REV]   (N defaults to CEILING; --rev reads SCRIP's commit REV, not the tree)
# PRINTS: one line per form (its sites, then file:line,line,... grouped by file) and ZETA_ACCESSOR_FORMS total=<n> forms=<f> ceiling=<c> bar=at-most-<N>
# EXIT: 0 total <= N; 1 total > N (a direct form came back, or N is below what is left); 2 could not measure (no SCRIP, no such REV, no source read).
import os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SCRIP = os.path.normpath(os.path.join(HERE, "..", "..", "SCRIP"))
DIRS = ("src/templates", "src/emitter")
EXTS = (".c", ".cpp", ".h", ".inc")
FORMS = ['RDQ("rbp"', 'RDD("rbp"', 'RDQ("rsp"', 'RDD("rsp"', "x86_rsp_load64(", "x86_rsp_store64(", "x86_frame_", "x86_zref(", "xop_frame_slot(",
         "x86_zop(", "ZOPQS(", "ZRES_SPINE(", "zls_frame_off(", "gen_frame_top()"]
CEILING = 480
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
total = 0
for form in FORMS:
    sites = {}
    for path in sorted(texts):
        hits = [str(i + 1) for i, ln in enumerate(texts[path]) if form in ln]
        if hits: sites[path] = hits
    n = sum(len(h) for h in sites.values())
    total += n
    print("  %-18s %4d  %s" % (form, n, " ".join("%s:%s" % (p, ",".join(h)) for p, h in sites.items())))
print("ZETA_ACCESSOR_FORMS total=%d forms=%d ceiling=%d bar=at-most-%d files=%d tree=%s" % (total, len(FORMS), CEILING, at_most, len(texts), rev or "worktree"))
if total < CEILING: print("FALLEN: the total is %d, below CEILING %d -- lower CEILING to %d in this script in the landing that made it fall" % (total, CEILING, total))
sys.exit(0 if total <= at_most else 1)

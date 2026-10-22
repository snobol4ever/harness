#!/usr/bin/env python3
# util_placement_predicates_census.py -- THE EMITTER'S PLACEMENT PREDICATES, COUNTED BY NAME UNTIL THE LAST SWITCH READS 0 (ceo CEO-1919; the cto's
# ARCH-THREE-ZETAS-EMISSION.md section 9.1, which names this census and its floor of 27; Lon 2026-10-22 16:0x, in-chat to the ceo, verbatim: "how complete
# is the new PLANNER design?" -- the answer had no instrument for the predicates). CEO-1895's programme deletes "the emitter's 27 placement predicates
# ... as each switch lands": each answers "frame slot or not" at emission, a second decider beside the PLANNER. This counts, per name, whether a
# DEFINITION still exists anywhere under SCRIP/src and how many places NAME it (calls and declarations), grouped as section 9.1 groups them.
# USE: python3 harness/scripts/util_placement_predicates_census.py [--at-most N]    (N defaults to the floor, 27; --at-most 0 is the programme's end)
# PRINTS: one line per predicate (alive/deleted, its file:line, its reference count) and PLACEMENT_PREDICATES alive=<n>/27 ... refs=<m>
# EXIT: 0 alive <= N; 1 alive > N (a predicate came back, or the bar is lower than what is deleted); 2 could not measure (no SCRIP/src).
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(HERE, "..", "..", "SCRIP", "src"))
GROUPS = [
    ("snobol4 capture and match frame", ["earn_hazard_in", "alt_arm_member", "cap_in_alt_arm", "cap_in_repeat_body", "alt_branch_has_nested_alt",
                                         "alt_arms_push", "cap_save_cond_gap_has_alt", "fence_frame_candidate", "frame_need_of"]),
    ("blob frame slots", ["arbno_reentry_hazard", "arbno_frame_candidate", "leaf_frame_member", "blob_arm_leaf_fc", "xop_hazard_kind",
                          "choice_body_member", "xop_frame_member", "choice_frame_candidate", "frame_slot_is_candidate"]),
    ("retention and value homes", ["icn_retaining_kind", "xop_retains", "xop_arms_retain", "xop_walk_hazard", "xop_consumer_hazard",
                                   "icn_xop_frame_member", "pl_xop_frame_member", "xop_frame_slot", "alt_arm_complex"]),
]
FLOOR = 27
args = sys.argv[1:]
at_most = FLOOR
if "--at-most" in args:
    try: at_most = int(args[args.index("--at-most") + 1])
    except (IndexError, ValueError): print("REFUSE(2): --at-most takes a whole number"); sys.exit(2)
if not os.path.isdir(SRC): print("REFUSE(2): no SCRIP/src at %s" % SRC); sys.exit(2)
texts = {}
for root, _, files in os.walk(SRC):
    for f in files:
        if f.endswith((".c", ".cpp", ".h", ".inc")):
            p = os.path.join(root, f)
            try: texts[p] = open(p, encoding="utf-8", errors="replace").read().split("\n")
            except OSError: pass
if not texts: print("REFUSE(2): no C or C++ source under %s" % SRC); sys.exit(2)
def scan(name):
    word = re.compile(r"\b%s\b" % re.escape(name))
    head = re.compile(r"^\s*(?:static\s+|inline\s+|extern\s+)*[A-Za-z_][\w\s\*&:<>,]*?\b%s\s*\(" % re.escape(name))
    where, refs = None, 0
    for p, lines in texts.items():
        for i, ln in enumerate(lines):
            if not word.search(ln): continue
            refs += len(word.findall(ln))
            m = head.match(ln)
            # A DEFINITION opens a body on its own line (the 200-column rule puts a whole function on one line: "static int f(...) { ...; }")
            # or continues onto the next; a prototype ends in ";" with no "{" after the parameter list.
            if where is None and m and ("{" in ln[m.end():] or not ln.rstrip().endswith(";")):
                where = "%s:%d" % (os.path.relpath(p, os.path.dirname(SRC)), i + 1)
    return where, refs
alive = 0; total_refs = 0; per = []
for gname, names in GROUPS:
    galive = 0
    for n in names:
        where, refs = scan(n)
        total_refs += refs
        if where: alive += 1; galive += 1
        print("  %-28s %-8s %-40s refs=%d" % (n, "alive" if where else "deleted", where or "-", refs))
    per.append("%s %d/%d" % (gname, galive, len(names)))
print("PLACEMENT_PREDICATES alive=%d/%d (%s) refs=%d bar=at-most-%d" % (alive, FLOOR, ", ".join(per), total_refs, at_most))
sys.exit(0 if alive <= at_most else 1)

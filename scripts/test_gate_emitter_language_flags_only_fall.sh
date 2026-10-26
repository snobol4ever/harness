#!/usr/bin/env bash
# test_gate_emitter_language_flags_only_fall.sh -- LANGUAGE IDENTITY STOPS AT LOWER, AS THREE RATCHETS (ceo CEO-1836/1838/1840;
# Lon 2026-10-18, in-chat to the ceo, verbatim: "How much of the emitter is language specific? Did you know that is not allowed past
# the lower stage. Will you fix that?" -- "which global specifies lanuage? which global struct specifies language. DELETE those
# OUTRIGHT!" -- "there needs to be proper design of the IR/IR_t graph such that after the lower is finished ALL language specific
# things are indicated by the internal representation which manifests in varying EMITTER patterns, and sometime different runtime
# calls." -- "Will you be able to properly design IR, BB, such that the templates are perfectly granular and which has all language
# specific variances encoded within?"). The design is ARCH-IR-CARRIES-EVERY-LANGUAGE-VARIANCE.md. This gate measures it three ways:
#
# 1. DELETED: the language flags Lon deleted (icn_cells_graph, emit_pl_frame, zls_g_pl_frame, pl_frame, icn_retain) never return
#    anywhere under src/, parser and lower included. Their BEHAVIOUR took registered names the same day (cell_frame, resumable_frame,
#    frame_retained: ARCH-IR-CARRIES-EVERY-LANGUAGE-VARIANCE.md section 2), set by a lowerer because a construct is in the source.
# 2. GRAPH_FACT: every read of a registered graph fact in src/emitter and src/templates, per fact, against its floor. A graph fact is
#    the coarse form of a variance; the granular form is a node kind or a node attribute read by one box. The campaign moves reads from
#    the graph to the node, so a floor may only FALL; the landing that removes reads lowers the floor in the same push.
# 3. LANG_PREFIX: every language-prefixed identifier (icn_ pl_ rk_ sno_ pas_ snc_ reb_ ...) in src/emitter and src/templates, per
#    prefix, against its floor: the honest count of "how much of the emitter is language specific". May only fall; zero is the goal.
# Live CODE only: comments and string literals are stripped before counting.
# rc 0 green, rc 1 a deleted name returned or a count above its floor, rc 2 cannot measure (no SCRIP beside harness, or fewer than
# 100 emitter/template files). Fail-once: a floor set one below today's count reads RED (ceo, 2026-10-18 15:2x CDT, in the ledger).
# FLOORS measured 2026-10-18 16:2x CDT on the restore merged with hq_prolog's 8a5973d0b/f049ef7a8 (its restore reads emit_resumable_frame()
# at three more sites and zls_g_resumable_frame() at four more than the pre-deletion tree did; zframe_graph one more through x86_resumable_frame).
# RE-FLOORED 2026-10-22 15:4x CDT by the cto on the coo's red of 15:3x (CEO-1895): zls_g_resumable_frame 10 -> 12, the one retains table's
# unresolved-callee-in-a-resumable-frame rule (planner_retains and its home view, SCRIP e351e13d4/dace004b6) MOVED out of src/planner/frame_layout.c's
# deleted zls_home_dyn, which this gate does not count, into src/planner, where ARCH-ZETA-ONE-COORDINATE 3.5 (i.b) puts the decision -- it goes
# with the Prolog switch's per-predicate retains fact; home_frame 0 -> 2, zst_plan admitting the Pascal switch's home-frame graphs and giving them a
# second hosting pass (SCRIP 2eb1aadd9, 6e1dd9a8b) -- both go when zst_plan's regime returns are deleted (3.5 WHAT THIS REPLACES). The other five
# reads above the floor were CURED, not floored: x86_zop's ZSM call reads the branch it sits in (zframe_graph, frame_retained and icn_frame_rbp
# were re-derived beside it, from bcd2ef252), planner.h's duplicate zls_g_resumable_frame prototype, and the uplevel skip reads the declared reason.
# RE-FLOORED 2026-10-25 00:xx CDT by the cfo, in its name, on the cto's read of 7affeda58 (CEO-1954/1971; the planner half 0d3a92f14 and the emitter half 7affeda58 both
# read graph_fact_reads 218 over 177): THE PLACEMENT RECORD moved the emitter's placement reads into src/planner (planner_home_icn, planner_home_pl, zd_place) --
# spine_cells 26 -> 37 (zeta_plan.cpp 24), emit_resumable_frame 19 -> 21 (zeta_plan.cpp 15), zls_g_resumable_frame 12 -> 16 (zeta_plan.cpp 4), body_root 21 -> 24
# (act_words.cpp 3), home_frame 2 -> 9 (zeta_plan.cpp 8), zls_g_home_frame 2 -> 16 (zeta_plan.cpp 6, emit.cpp 7, x86_asm.h 2), root_graph 21 -> 22 (emit.cpp 13,
# xa_flat.cpp 6, bb_glue_flat.cpp 2); frame_retained FELL 6 -> 5 (the emitter half's deletion) and the floor follows it down. The planner's reads are the one decider
# reading the lowerer's coarse facts and FALL as each regime switch replaces zd_pl_home()/zls_g_home_frame/zls_g_resumable_frame with the retains table and node
# facts (ARCH-PROLOG-ACTIVATION-LIFETIME.md section 3, ARCH-THREE-ZETAS 6.3 step (d)); the emitter's zls_g_home_frame 9 and root_graph 22 are debt named to those
# same landings. A floor may only fall from here.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" 2>/dev/null && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
python3 - "$SCRIP" <<'PYEOF'
import re, sys, glob, os
root = sys.argv[1]
DELETED = ("icn_cells_graph", "emit_pl_frame", "zls_g_pl_frame", "pl_frame", "icn_retain")
GRAPH_FACT = {"zframe_graph": 30, "cell_frame": 38, "spine_cells": 37, "resumable_frame": 0, "emit_resumable_frame": 21, "zls_g_resumable_frame": 16, "frame_retained": 5, "root_graph": 22, "body_root": 24, "home_frame": 9, "zls_g_home_frame": 16}
LANG_PREFIX = {"icn": 97, "pl": 165, "rk": 37, "sno": 41, "pas": 10, "snc": 0, "reb": 0, "raku": 0, "plw": 0}
files = []
for pat in ("src/emitter/*.cpp", "src/emitter/*.h", "src/planner/*.cpp", "src/planner/*.h", "src/templates/**/*.cpp", "src/templates/**/*.h", "src/templates/**/*.inc"):
    files += glob.glob(os.path.join(root, pat), recursive=True)
if len(files) < 100:
    print("REFUSE(2): examined %d emitter/template files, fewer than 100 -- an empty tree must not read as clean" % len(files)); sys.exit(2)
def strip(s):
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.S); s = re.sub(r"//[^\n]*", "", s); return re.sub(r'"(\\.|[^"\\])*"', '""', s)
src = {f: strip(open(f, encoding="utf-8", errors="replace").read()) for f in files}
red = 0
allsrc = [f for pat in ("src/**/*.c", "src/**/*.cpp", "src/**/*.h", "src/**/*.inc") for f in glob.glob(os.path.join(root, pat), recursive=True)]
for k in DELETED:
    hits = []
    for f in allsrc:
        n = len(re.findall(r"\b%s\b" % k, strip(open(f, encoding="utf-8", errors="replace").read())))
        if n: hits.append("%s %d" % (os.path.relpath(f, root), n))
    red |= bool(hits)
    print("EMIT_LANG_FLAG_DELETED flag=%s reads=%d%s" % (k, len(hits), ("  RETURNED in " + ", ".join(hits[:3])) if hits else ""))
tg = 0
for k, floor in GRAPH_FACT.items():
    where = {}
    for f, s in src.items():
        n = len(re.findall(r"\b%s\b" % k, s))
        if n: where[os.path.relpath(f, root)] = n
    n = sum(where.values()); tg += n; over = n > floor; red |= over
    top = ", ".join("%s %d" % (p, c) for p, c in sorted(where.items(), key=lambda x: -x[1])[:3])
    print("EMIT_GRAPH_FACT fact=%s reads=%d floor=%d%s  [%s]" % (k, n, floor, " ABOVE-FLOOR" if over else "", top))
tl = 0
for k, floor in LANG_PREFIX.items():
    where = {}
    for f, s in src.items():
        n = len(re.findall(r"\b%s_[A-Za-z0-9_]+" % k, s))
        if n: where[os.path.relpath(f, root)] = n
    n = sum(where.values()); tl += n; over = n > floor; red |= over
    top = ", ".join("%s %d" % (p, c) for p, c in sorted(where.items(), key=lambda x: -x[1])[:3])
    print("EMIT_LANG_PREFIX prefix=%s_ identifiers=%d floor=%d%s  [%s]" % (k, n, floor, " ABOVE-FLOOR" if over else "", top))
print("EMIT_LANG_TOTAL graph_fact_reads=%d graph_fact_floor=%d lang_prefixed=%d lang_prefixed_floor=%d files=%d" % (tg, sum(GRAPH_FACT.values()), tl, sum(LANG_PREFIX.values()), len(files)))
if red:
    print("GATE RED [emitter_language_flags_only_fall]: language identity grew past lower -- a deleted flag returned, a graph fact gained a reader, or a language-prefixed identifier was added to the emitter or a template; express the variance as a node kind or node attribute set by the lowerer (ARCH-IR-CARRIES-EVERY-LANGUAGE-VARIANCE.md)"); sys.exit(1)
print("GATE OK [emitter_language_flags_only_fall]: no deleted flag returned, no graph fact gained a reader, no language prefix grew; lower a floor in the landing that removes reads")
PYEOF

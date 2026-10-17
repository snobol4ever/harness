#!/usr/bin/env python3
"""util_gc_event_coverage.py -- SCRIP'S GC EVENT SPACE, AND WHICH EVENTS THE CORPUS ACTUALLY EXERCISES.

Row gc-event-coverage-is-the-criterion-not-collection-count (coo, 2026-09-21, MODE TENET, CEO-1029).

WHY THE AXIS CHANGED. A stress setting only tests the gc-points where a collection ACTUALLY OCCURS, and that
subset need not differ between executions -- so COLLECTION COUNT is the wrong axis. Measured on this tree:
bench_icnstr_concat_table.icn at SCRIP_HEAP_MB=1 gives 38781 collections at stress 1, 32015 at stress 5 and
10006 at stress 16, and hq_raku found 36 silently-wrong Raku programs at stress 16 that stress 1, 3 and 5 all
called GREEN. FEWER COLLECTIONS FOUND MORE DEFECTS. GCFuzz names the right axis: EVENT COVERAGE -- a coverage
criterion over GC EVENTS. A configuration that raises no new event coverage is not worth running; one that
raises it is worth keeping.

⛔ THE DENOMINATOR IS THE WHOLE POINT OF THIS INSTRUMENT, SO IT IS PRINTED THREE WAYS AND NEVER ONE.
This row exists because a green instrument was measuring the wrong axis. Ratcheting a SUBSET and letting it
read as "the event space" would be that same offence one level up, so the report carries, by name and never as
a count alone (CEO-997 batch 30 clause 2):
  OBSERVABLE  -- the event has telemetry the collector already emits, so it can be exercised and counted here.
  OWED        -- the event is real and the collector does not distinguish it. NAMED, never silently dropped.
  ABSENT      -- the event does not exist in this collector at all. Carrying a bucket that can never fill
                 would read as permanent 0% coverage of a thing that cannot happen, so it is named ABSENT and
                 its absence is ASSERTED: the day a code path appears, this instrument REDS and demands the
                 event be reclassified rather than quietly keeping a stale map.

⛔ THIS INSTRUMENT EDITS NO src/. Under CEO-723 this seat holds no cure lane; every OBSERVABLE event below is
read from telemetry that is already in the tree, and every OWED event is a one-line ask to the seat that owns
the collector, not a change made here.
"""
import argparse, io, os, re, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")
GCHEAP = os.path.join(ROOT, "src", "runtime", "rt", "gc_heap.c")

# ---------------------------------------------------------------------------------------------------------
# THE EVENT SPACE. Each OBSERVABLE event names the telemetry line that proves it and the field read from it,
# with the gc_heap.c site the field is printed at, so a reader can re-derive the mapping rather than trust it.
# key, human name, [ZGC-style marker], field, gc_heap.c print site, what a nonzero value means
OBSERVABLE = [
    ("collection_at_safe_point", "a collection runs at a safe point",
     "[ZGC] regeneration", r"regeneration #(\d+)", "gc_heap.c:1252",
     "emitted code reached a poll and collected"),
    ("arena_grow", "the heap commits more of its cap",
     "[ZHP] arena=", r"grew=(\d+)KB", "gc_heap.c:175",
     "the heap committed more pages under load. ⛔ THIS EVENT'S TELEMETRY WAS RENAMED UNDER THE INSTRUMENT "
     "(aaa77634c, 2026-09-22): the old reserve-and-soft-end shape printed `[ZHP] soft end -> N MB committed "
     "of M MB reserved (grown N MB total)` and the hard-cap shape prints `[ZHP] lazy commit -> N KB of a M KB "
     "hard cap`. This entry now reads the SUMMARY line's own grew= field instead, which is printed on every "
     "run and is 0 exactly when nothing grew, so it cannot be confused with an absent line"),
    ("slide_with_displacement", "the slide moves at least one live block",
     "[ZGC-WALK]", r"moved=(\d+)B", "gc_heap.c:1248",
     "a live block changed address, which is the only way a stale pointer can be exposed"),
    ("slide_without_displacement", "a live block survives the slide WITHOUT moving",
     "[ZGC-WALK]", r"unmoved=(\d+)", "gc_heap.c:1403",
     "a live block kept its base across the slide -- the zero-displacement population, which by construction "
     "cannot expose a stale pointer. Counted PER BLOCK by w_unm in all three slide arms (:1403, :1412, :1422), "
     "so it is the discriminator slide_with_displacement lacks: moved= is aggregate BYTES and cannot say how "
     "many blocks stayed put"),
    ("mark_worklist_growth", "the mark worklist grows past its initial capacity",
     "[ZGC] regeneration", r"wl_depth_max=(\d+)", "gc_heap.c:1252",
     "the marker queued a nontrivial frontier (the worklist reallocs at 4096, gc_heap.c:669)"),
    ("interior_pointer_fixup", "an interior pointer is fixed up",
     "[ZGC] regeneration", r"interior=(\d+)", "gc_heap.c:1252",
     "a reference pointed into the middle of a block, not at its head (gc_heap.c:682, :726)"),
    ("fill_block_insertion", "a fill block is inserted",
     "[ZGC] regeneration", r"\(fill (\d+)\)", "gc_heap.c:1252",
     "the collector laid down HB_FILL to keep the title chain walkable"),
    ("cell_forwarding_fixup", "a registered cell is forwarded",
     "[ZGC] regeneration", r"forwarded=(\d+)", "gc_heap.c:1252",
     "a recorded slot was rewritten to a block's new address"),
    ("block_marked", "a block is marked live",
     "[ZGC] regeneration", r"marked=(\d+)", "gc_heap.c:1252",
     "the mark phase reached at least one block"),
    ("mark_multi_round", "the mark phase needs more than one round",
     "[ZGC-MARK]", r"rounds=(\d+)", "gc_heap.c:1205",
     "the worklist drained and refilled, so the object graph is deeper than one sweep"),
    ("coexpression_stack_visit", "a co-expression stack is visited",
     "[GC-COEXPR]", r"ctxs=(\d+)", "gc_heap.c:1179",
     "a parked co-expression context was walked as mapped frames, not swept"),
    ("visitor_kind_descr", "the DESCR visitor kind is reached",
     "[GC-WALK]", r"i_descr=(\d+)", "gc_heap.c:1095",
     "a frame interior word was read by its sealed kind table as a descriptor"),
    ("visitor_kind_ptr_gc", "the PTR_GC visitor kind is reached",
     "[GC-WALK]", r"i_ptr=(\d+)", "gc_heap.c:1095",
     "a frame interior word was read as a raw collected pointer"),
    ("blob_frame_walk", "an emitted blob frame is walked by its static map",
     "[GC-BLOB]", r"frames=(\d+)", "gc_heap.c:1178",
     "the compile-time frame map was consulted for an emitted activation"),
    ("dvec_visit", "a descriptor vector is visited",
     "[GC-DVEC]", r"elems=(\d+)", "gc_heap.c:1251",
     "a DVEC element run was walked"),
    ("quarantine_arm", "vacated ground is armed PROT_NONE",
     "[ZGC-TRAP]", r"arms=(\d+)", "gc_heap.c:1256",
     "the poison trap armed, so a stale read faults instead of returning plausible bytes"),
]

# ⛔ REAL EVENTS THE COLLECTOR CANNOT DISTINGUISH TODAY. Printed by name on every run, never dropped.
OWED = [
    ("per_visitor_kind_raw_and_gap", "the RAW and GAP frame-interior kinds are reached",
     "[GC-WALK] prints i_raw and i_gap, so the words are COUNTED -- but RAW and PTR_CODE are by contract never "
     "visited (they are skipped, not walked), so a nonzero i_raw proves the kind was ENCOUNTERED and not that a "
     "visitor RAN. The event 'each visitor kind reached' is therefore only half-readable: the two visiting "
     "kinds (DESCR, PTR_GC) are covered above; the two non-visiting kinds have no visitor to reach. OWED: a "
     "ruling on whether an encountered-but-skipped kind is an event at all, which is the cto's call, not mine."),
]

# ⛔ EVENTS NAMED IN THE ROW'S GOAL THAT DO NOT EXIST IN THIS COLLECTOR. Each carries the assertion that keeps
# the map honest: a (description, list-of-(pattern, file) that must NOT appear) -- if one appears, we RED.
ABSENT = [
    ("arena_shrink", "the arena returns committed memory",
     "VERIFIED ABSENT on this tree: g_hp_end is only ever ADVANCED (`g_hp_end += want`, gc_heap.c:160) or "
     "INITIALISED (`g_hp_end = g_hp_arena + g_hp_chunk`, gc_heap.c:179). The single munmap in the file "
     "(gc_heap.c:502) is gcbk_drop, which frees the COLLECTOR'S OWN BOOKKEEPING blocks (mark worklist, live "
     "arrays) and never the object arena. There is no shrink path, so this is not an uncovered event -- it is "
     "an event that cannot occur. ASSERTED below so that the day a shrink lands, this instrument reds.",
     [r"g_hp_end\s*-=", r"g_hp_end\s*=\s*g_hp_end\s*-"]),
]

# ---------------------------------------------------------------------------------------------------------
# ⛔⭐ LAYOUT SENSITIVITY, MEASURED HERE, AND IT IS WHY THE PROBE SET IS PINNED RATHER THAN CONVENIENT.
# A COVERAGE READING IS A PROPERTY OF (program, stress, INVOCATION) AND NOT OF THE PROGRAM ALONE. Measured on
# hb_nv.sno at SCRIP_HEAP_MB=1 SCRIP_GC_STRESS=1, one binary, one tree, the ONLY difference the spelling of the
# path handed to ./scrip:
#     ../harness/scripts/gc_witnesses/hb_nv.sno            -> interior=1   (the event IS reached)
#     ./scripts/gc_witnesses/hb_nv.sno          -> interior=0   (two characters longer; the event is NOT reached)
#     /home/claude_coo/harness/scripts/.../hb_nv.sno -> interior=0
# Three runs each, no variation within a spelling. The source path is itself a heap block, so its length shifts
# every block after it, and whether any reference lands INTERIOR to a block is decided by that incidental shift.
# ⛔ THE CONSEQUENCE FOR THIS INSTRUMENT: an event reached by ONE witness at ONE marginal count is not a fact
# about the corpus, it is a fact about how that run was spelled -- and a ratchet resting on it would red or green
# depending on whether a caller wrote `../harness/scripts/x` or `./scripts/x`. So every probe here is chosen for being
# ROBUST: each was re-run under all three spellings above and reached its event at the same count every time.
# ⭐ AND THE SAME MEASUREMENT IS A FINDING FOR THE FLEET, not just a caveat for this file: two seats running the
# same witness at the same stress from roots of different name length ARE EXERCISING DIFFERENT GC EVENTS, and
# nothing in any board line says so. That is the row's own thesis one level down -- the configuration has to be
# named, or the number is about something nobody wrote down.
# ---------------------------------------------------------------------------------------------------------
# THE PROBES. Small, already-in-tree witnesses, each run at the tiny arena so collection is forced. A probe
# that will not run is REFUSED (rc=2) and never silently skipped -- an instrument that reports success while
# doing nothing is the recurring failure (RULES.md THE INSTRUMENT LAWS).
PROBES = [
    ("hb_nv.sno",                        "3", "1", {}),
    ("hb_coexpr_create.icn",             "3", "1", {}),
    ("hb_arr.sno",                       "3", "5", {}),
    ("hb_nested_match_outer_subject.sno", "3", "1", {}),   # the only ROBUST interior_pointer_fixup probe (see below)
    ("hb_eval_names.sno",                "3", "1", {}),   # the only ROBUST blob_frame_walk probe
    ("hb_arena_grow.sno",                "3", "1", {}),   # the ONLY probe that reaches arena_grow: a LIVE set
                                                          # larger than the window, so the collector cannot
                                                          # reclaim its way out and the soft end must advance
    ("hb_nv.sno",                        "3", "1", {"SCRIP_GC_PLANT_FLIP": "1", "SCRIP_HEAP_KB": "512"}),  # reaches
                                                          # fill_block_insertion: the plant lays HB_FILL at the
                                                          # arena start (gc_heap.c:1405) every collection
    ("hb_dvec_sort_match.sno",           "3", "1", {}),   # the quarantine_arm probe (cfo 2026-09-26): the five
                                                          # above reached it only while the lowerer's lc_vec
                                                          # garbage sat on the collected heap -- 957efcc7c moved
                                                          # it to the compile-time arena, no collection vacated
                                                          # a whole page and arms= read 0 (hb_nv.sno 68 -> 0,
                                                          # bisected). This one arms 26 times at stress 1 under
                                                          # four spellings and two root lengths, 0.3 s.
]

# ⛔ WHAT BOUNDS A "NOT EXERCISED" VERDICT. hq_P's law: A NULL RESULT BOUNDS THE PROBE, NOT THE THING PROBED.
# An event this five-probe set does not reach may simply be an event these five programs do not perform, which
# is a fact about the probe set and NOT about the corpus. So for every event the probe set misses, the bound is
# printed with the verdict: the evidence below is a sweep of the ENTIRE gc_witnesses pool (all 96 .sno and .icn
# witnesses) at SCRIP_HEAP_MB=1 SCRIP_GC_STRESS=1 on tree e6f0f7f99, run by the coo 2026-09-21.
SWEPT = {
    "arena_grow":
        "SWEPT (coo 2026-09-21, tree e6f0f7f99): all 96 gc_witnesses at SCRIP_HEAP_MB=1 stress 1 read `grown N "
        "MB total` = 0. That verdict was CORRECT and its diagnosis was exact -- every witness in the pool "
        "allocates heavily and RETAINS ALMOST NOTHING, so the collector reclaims faster than they allocate and "
        "the window is never outgrown. CURED 2026-09-22 (cfo) by supplying the missing SHAPE rather than more "
        "probes: hb_arena_grow.sno holds a LIVE set larger than the window (20000 array elements, ~2.09 MB, "
        "summed afterwards so the set is genuinely live) and reads `soft end -> 3 MB committed (grown 2 MB "
        "total)`. If this event ever reads NOT EXERCISED again, that probe has regressed -- check it before "
        "concluding anything about the collector.",
    "fill_block_insertion":
        "SWEPT (coo 2026-09-21, tree e6f0f7f99): all 96 gc_witnesses at SCRIP_HEAP_MB=1 stress 1 read `(fill "
        "N)` = 0 across every collection. CURED 2026-09-22 (cfo), and the sweep's NULL was a property of the "
        "ENVIRONMENT, not of the pool: HB_FILL is laid down on three paths and the two that fire reliably are "
        "both knob-gated -- the plant prefix (gc_heap.c:1405) and the forced-relocation gaps (:1416) -- while "
        "the unforced path (:1422) needs a block to stay put with a gap before it, which compaction rarely "
        "leaves. The sweep set neither knob, so it could not have reached the event with any witness. hb_nv.sno "
        "at SCRIP_GC_PLANT_SHIFT=4096 reads max fill=244; SCRIP_GC_RELOC=1 reads 18. This is hq_P's law landing "
        "on its own instrument: A NULL RESULT BOUNDS THE PROBE, and here the probe was bounded by its ENV.",
}

TELEM_ENV = {
    "SCRIP_ZETA_TELEM": "1",     # [ZGC], [ZGC-WALK], [ZGC-MARK], [ZGC-TRAP], [ZHP] soft end
    "SCRIP_GC_COVERAGE": "1",    # [GC-COV]
    "SCRIP_GC_MAPS": "1",        # [GC-WALK], [GC-BLOB], [GC-COEXPR]
    "SCRIP_GC_POISON": "1",      # arms the quarantine so quarantine_arm can be reached
    "SCRIP_HEAP_MB": "1",        # the tiny arena: without it most probes never collect at all
    "SCRIP_HEAP_MAX_MB": "512",
}


def run_probe(scrip, wdir, name, mode, stress, timeout_s, extra=None):
    src = os.path.join(wdir, name)
    if not os.path.isfile(src):
        return None, "no such witness: %s" % src
    env = dict(os.environ)
    env.update(TELEM_ENV)
    env["SCRIP_GC_STRESS"] = stress
    if extra:
        env.update(extra)
    stdin = open(os.devnull, "rb")
    inf = os.path.join(wdir, os.path.splitext(name)[0] + ".in")
    if os.path.isfile(inf):
        stdin.close()
        stdin = open(inf, "rb")
    try:
        p = subprocess.run([scrip, src], stdin=stdin, stdout=subprocess.DEVNULL,
                           stderr=subprocess.PIPE, env=env, timeout=timeout_s)
    except subprocess.TimeoutExpired:
        return None, "timed out after %ss" % timeout_s
    finally:
        stdin.close()
    return p.stderr.decode("utf-8", "replace"), None


def marker_liveness(events):
    """⛔ A MARKER THAT NO LONGER EXISTS IN THE RUNTIME IS A RENAME, NOT AN UNEXERCISED EVENT.
    This guard exists because arena_grow silently stopped being reachable when aaa77634c renamed its
    telemetry: the event still happened (262 lazy-commit events on hb_arena_grow.sno, grew=1048KB) but the
    instrument was grepping for text with ZERO occurrences in the tree, and the ratchet reported COVERAGE
    FELL -- which reads as a collector regression and is a completely different verdict. Returns the list of
    (key, missing-literal) so the caller can REFUSE(2) and name it."""
    src = ""
    for root, _d, fs in os.walk(os.path.join(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP"), "src", "runtime")):
        for f in fs:
            if f.endswith((".c", ".h")):
                try:
                    src += io.open(os.path.join(root, f), encoding="utf-8", errors="replace").read()
                except OSError:
                    pass
    if not src:
        return []          # no source to check against: say nothing rather than refuse wrongly
    dead = []
    for key, _n, marker, field, _s, _m in events:
        if marker not in src:
            dead.append((key, marker))
            continue
        lit = re.split(r"[(\\\[]", field)[0]
        if len(lit) >= 4 and lit not in src:
            dead.append((key, lit))
    return dead


def scan(text, events):
    """Return {key: max nonzero value seen}. A field present but zero is NOT an exercise."""
    hit = {}
    for key, _n, marker, field, _site, _means in events:
        rx = re.compile(field)
        best = 0
        for line in text.splitlines():
            if marker not in line:
                continue
            m = rx.search(line)
            if m:
                try:
                    v = int(m.group(1))
                except ValueError:
                    continue
                if v > best:
                    best = v
        if best > 0:
            hit[key] = best
    return hit


def check_absent():
    """Every ABSENT event must STAY absent. Returns list of (key, pattern) that now appear."""
    broke = []
    try:
        with open(GCHEAP, "r", errors="replace") as f:
            src = f.read()
    except OSError:
        return None
    for key, _n, _why, pats in ABSENT:
        for pat in pats:
            if re.search(pat, src):
                broke.append((key, pat))
    return broke


def read_floor(path):
    if not os.path.isfile(path):
        return None
    keys = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                keys.append(line.split()[0])
    return keys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--floor", default=os.path.join(HERE, "gc_event_coverage.floor"))
    ap.add_argument("--raise-floor", action="store_true",
                    help="rewrite the floor to today's coverage (a deliberate act, never automatic)")
    ap.add_argument("--timeout", type=int, default=60)
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args()

    scrip = os.environ.get("SCRIP_BIN", os.path.join(ROOT, "scrip"))
    if not os.access(scrip, os.X_OK):
        print("⛔ REFUSE(2): no scrip binary at %s" % scrip)
        return 2
    wdir = os.path.join(HERE, "gc_witnesses")
    if not os.path.isdir(wdir):
        print("⛔ REFUSE(2): no witness directory at %s" % wdir)
        return 2

    dead = marker_liveness(OBSERVABLE)
    if dead:
        print("⛔ REFUSE(2): %d event marker(s) name telemetry that NO LONGER EXISTS in src/runtime --" % len(dead))
        for k, lit in dead:
            print("     %-30s looks for %r, which has zero occurrences in the tree" % (k, lit))
        print("   THIS IS A RENAME, NOT A COVERAGE LOSS. An event whose telemetry was renamed is still")
        print("   happening; grepping for the old text would report COVERAGE FELL and read as a collector")
        print("   regression. Re-point the marker at the current text, then re-run.")
        return 2

    t0 = time.time()
    exercised, by_probe, ran = {}, {}, 0
    for name, mode, stress, extra in PROBES:
        txt, err = run_probe(scrip, wdir, name, mode, stress, a.timeout, extra)
        if err is not None:
            print("⛔ REFUSE(2): probe %s could not run -- %s" % (name, err))
            return 2
        ran += 1
        hits = scan(txt, OBSERVABLE)
        label = name if not extra else name + "+" + ",".join(sorted(extra))
        by_probe[label] = hits
        for k, v in hits.items():
            if v > exercised.get(k, 0):
                exercised[k] = v

    total = len(OBSERVABLE)
    covered = [e for e in OBSERVABLE if e[0] in exercised]
    uncovered = [e for e in OBSERVABLE if e[0] not in exercised]

    if not a.quiet:
        print("GC EVENT COVERAGE -- the axis is EVENT COVERAGE, not collection count")
        print("  probes: %d run at SCRIP_HEAP_MB=1 (%s), %.1fs" %
              (ran, ", ".join("%s@stress%s" % (n, s) for n, _m, s, _e in PROBES), time.time() - t0))
        print("  OBSERVABLE EVENT SPACE: %d events, %d EXERCISED, %d NOT EXERCISED"
              % (total, len(covered), len(uncovered)))
        for key, nm, _mk, _f, site, means in OBSERVABLE:
            if key in exercised:
                who = [p for p in by_probe if key in by_probe[p]]
                print("    ✅ %-28s max=%-10d %s  [%s]  by: %s"
                      % (key, exercised[key], nm, site, ",".join(who)))
        for key, nm, _mk, _f, site, means in OBSERVABLE:
            if key not in exercised:
                print("    ❌ %-28s NOT EXERCISED by any probe -- %s  [%s]" % (key, nm, site))
                print("       a nonzero value would mean: %s" % means)
                bound = SWEPT.get(key)
                if bound:
                    for ln in _wrap(bound, 104):
                        print("       %s" % ln)
                else:
                    print("       ⛔ UNBOUNDED: no sweep evidence is recorded for this event, so this verdict "
                          "bounds THE PROBE SET and says nothing about the corpus (hq_P's law). Sweep the pool "
                          "and record the result in SWEPT before reading this line as a hole.")
        print("  OWED -- real events this collector cannot distinguish (%d), NAMED not dropped:" % len(OWED))
        for key, nm, why in OWED:
            print("    ⛔ %-28s %s" % (key, nm))
            for ln in _wrap(why, 106):
                print("       %s" % ln)
        print("  ABSENT -- named in the row's goal, does not exist in this collector (%d):" % len(ABSENT))
        for key, nm, why, _p in ABSENT:
            print("    ∅  %-28s %s" % (key, nm))
            for ln in _wrap(why, 106):
                print("       %s" % ln)
        print("  DENOMINATOR IDENTITY: EXERCISED %d + NOT-EXERCISED %d == OBSERVABLE %d; "
              "OWED %d and ABSENT %d are outside it BY NAME, above."
              % (len(covered), len(uncovered), total, len(OWED), len(ABSENT)))

    broke = check_absent()
    if broke is None:
        print("⛔ REFUSE(2): cannot read %s to re-assert the ABSENT events" % GCHEAP)
        return 2

    rc = 0
    if broke:
        for key, pat in broke:
            print("  ⛔ RED: event '%s' was recorded ABSENT, but %s now matches /%s/. The event space CHANGED. "
                  "Reclassify it as OBSERVABLE with its telemetry, or as OWED with the reason -- do not leave a "
                  "stale map." % (key, os.path.basename(GCHEAP), pat))
        rc = 1

    floor_path = a.floor
    if a.raise_floor:
        with open(floor_path, "w") as f:
            f.write("# gc_event_coverage.floor -- THE RATCHET. Every key here was EXERCISED when it was written;\n")
            f.write("# if any stops being exercised, test_gate_gc_event_coverage_reports_and_ratchets.sh REDS.\n")
            f.write("# Raised deliberately with `util_gc_event_coverage.py --raise-floor`, never automatically.\n")
            for key, _nm, _mk, _f, _s, _m in OBSERVABLE:
                if key in exercised:
                    f.write("%s\n" % key)
        print("  floor rewritten: %d event(s) -> %s" % (len(exercised), floor_path))
        return rc

    floor = read_floor(floor_path)
    if floor is None:
        print("⛔ REFUSE(2): no ratchet floor at %s -- create it with --raise-floor" % floor_path)
        return 2
    fell = [k for k in floor if k not in exercised]
    rose = [e[0] for e in OBSERVABLE if e[0] in exercised and e[0] not in floor]
    if fell:
        print("  ⛔ RED: COVERAGE FELL. %d event(s) in the floor are no longer exercised: %s"
              % (len(fell), " ".join(fell)))
        rc = 1
    else:
        print("  ✅ RATCHET HOLDS: all %d floor event(s) still exercised." % len(floor))
    if rose:
        print("  ⭐ COVERAGE ROSE above the floor: %s -- rerun with --raise-floor to lock it in."
              % " ".join(rose))
    return rc


def _wrap(s, w):
    out, cur = [], ""
    for word in s.split():
        if len(cur) + len(word) + 1 > w:
            out.append(cur)
            cur = word
        else:
            cur = (cur + " " + word).strip()
    if cur:
        out.append(cur)
    return out


if __name__ == "__main__":
    sys.exit(main())

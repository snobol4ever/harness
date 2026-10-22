#!/usr/bin/env python3
"""util_queue_order_census.py [census] | classify [--apply] [--out FILE] -- THE WORK LIST IS THE BOARD IN LON'S ORDER (Lon 2026-10-22,
in-chat to the ceo: "put RBP/RSP priority lower than getting all language to 100% (1) completness, (2) correctness, and this task will be
part of the (3) speed improvements."; ceo CEO-1886/1887 line 1).

Every live QUEUE row carries a CLASS, derived from its topic and its baton's DONE-WHEN, and its RANK is its class, so the rank-sorted
picker (`s4e_msg.sh next`) serves Lon's order with no new column and no bus change:
  completeness  rank 1   a program a suite ships that is not graded (UNGRADED, NEEDS_DRIVER, runner wiring, a refused feature)
  correctness   rank 1   a suite entry, a gate, a ladder rung or an oracle diff that reads red  (rank 0 stays 0: a blocking-gate red)
  instrument    rank 2   the harness, the bus, a census, a runner's own defect
  law           rank 2   a ruling, a digest, a GOAL/ARCH page
  speed         rank 3   a bench bar, a multiple, callgrind, and the whole RSP/RBP placement programme
  bootstrap     rank 3   the Snocone bootstrap parsers replacing the C parsers (after speed, CEO-1562)
`classify` prints the proposal (class, old rank, new rank per row) and with --apply writes `CLASS: <class>` into each baton (after its
LINKS line, replacing an older CLASS line) and the new rank into QUEUE.tsv in binary under the bus's .mint.lock, touching only the rank
byte of the rows it classes; owner and state cells are never written (CEO-755c). `census` (the default) reads: every live row's baton
carries a CLASS line that agrees with its rank; no claim sits on a seat whose newest transcript is older than 48 h; and prints the
counts. rc 0 clean · rc 1 a violation named · rc 2 could not read.
"""
import sys, os, re, glob, time, fcntl
PO = "/home/resources/postoffice"
Q = PO + "/QUEUE.tsv"
TASKS = PO + "/tasks"
LIVE = ("FREE", "CLAIMED", "ASSIGNED", "PARKED-AWAITING", "BLOCKED-ON", "PARKED-UMBRELLA", "PARKED-LON-HOLD", "GRANT-NEEDED", "PARKED", "RESTRICTED")
RANK = {"completeness": 1, "correctness": 1, "instrument": 2, "law": 2, "speed": 3, "bootstrap": 3}
SEAT_ROOT = {"ceo": "ceo", "cto": "cto", "coo": "coo", "cfo": "cfo"}
STALE_H = 48
def rows():
    out = []
    for l in open(Q, "rb").read().decode("utf-8").split("\n"):
        f = l.split("\t")
        if len(f) >= 4 and f[0].isdigit(): out.append(f)
    return out
def baton(topic):
    p = "%s/%s.task.md" % (TASKS, topic)
    try: return open(p, encoding="utf-8", errors="replace").read()
    except OSError: return None
def donewhen(t):
    m = re.search(r"^DONE-WHEN:[ \t]*(.*)$", t, re.M)
    return m.group(1) if m else ""
def classify(topic, t):
    dw = donewhen(t).lower(); tl = topic.lower(); goal = (t.split("\n", 2)[1] if t.count("\n") > 1 else "").lower()
    if re.match(r"^(law|rules|protocol|digest|announce)-", tl) or (dw and re.search(r"grep .*(GOAL-|RULES\.md|ARCH-|MASTER-PLAN)", donewhen(t)) and not re.search(r"test_gate_|corpus_suite_harness|\./scrip", dw)): return "law"
    if re.search(r"bootstrap|parser-sc|parsers-match|self-hosted-parser|the-seven-self-hosted", tl): return "bootstrap"
    if re.search(r"^(instruments?|harness|gate|coo|s4e|donewhen|regen|bus|postoffice|queue|census|handoff|runner|modules|fleet|relay)-|-instrument-|the-loop-|the-dispatch-probe|results-tsv|score-row|suite-table-shows|housekeeping", tl) or re.search(r"selftest|util_queue_|util_gate_wiring|s4e_msg\.sh|util_suite_banner|util_score_row", dw): return "instrument"
    if re.search(r"-speed-|speed-|bench|perf|callgrind|clock|prealloc|pre-alloc|placement|-rsp-|-rbp-|rsp-spine|frame-regime|frame-home|rbp-home|zd-check|zd-planner|zetas-|multiple-of|instructions-in|slower|faster|times-|-x-spitbol|-percent-of", tl) or re.search(r"bench_|placement_census|no_spine_preallocation|frame_homes_agree|rsp_reset_by_port|zd_check|callgrind|lib_perf_fmt", dw): return "speed"
    if re.search(r"ungraded|ungradable|needs-driver|driver-rows|drivers?-for|inventory|runner-wiring|grades-the-|oracle-invocation|denominator|no-way-to|shipped|reach-their-full|is-graded|get-graded|ported-to", tl) or re.search(r"UNGRADED\.tsv|UNGRADABLE\.tsv|NEEDS_DRIVER|INVENTORY", donewhen(t)): return "completeness"
    return "correctness"
def transcript_age_h(seat):
    root = SEAT_ROOT.get(seat, seat[3:] if seat.startswith("hq_") else seat)
    fs = glob.glob("/home/satirical/.claude/projects/-home-claude-%s/*.jsonl" % root)
    if not fs: return None
    return (time.time() - max(os.path.getmtime(f) for f in fs)) / 3600.0
def census():
    bad = 0; counts = {}; unclassed = []; mismatch = []; stale = []
    for f in rows():
        rank, topic, owner, state = f[0], f[1], f[2], f[3]
        st = state.split(":")[0]
        if st not in LIVE: continue
        t = baton(topic)
        if t is None: print("REFUSE(2): no baton for %s" % topic); return 2
        m = re.search(r"^CLASS:[ \t]*([a-z]+)", t, re.M)
        if not m: unclassed.append(topic); continue
        c = m.group(1); counts[c] = counts.get(c, 0) + 1
        want = RANK.get(c)
        if want is None or (int(rank) != want and not (want == 1 and rank == "0")): mismatch.append((topic, c, rank))
        if st in ("CLAIMED", "ASSIGNED"):
            seat = state.split(":", 1)[1] if ":" in state else owner
            age = transcript_age_h(seat)
            if age is not None and age > STALE_H: stale.append((topic, seat, int(age)))
    print("QUEUE_ORDER_BOARD classed=%d unclassed=%d rank_mismatch=%d stale_claims=%d  %s" % (sum(counts.values()), len(unclassed), len(mismatch), len(stale), " ".join("%s=%d" % kv for kv in sorted(counts.items()))))
    for x in unclassed[:40]: print("  UNCLASSED %s" % x)
    for x in mismatch[:40]: print("  RANK %s is %s but class %s" % (x[0], x[2], x[1]))
    for x in stale: print("  STALE CLAIM %s on %s (transcript %d h old)" % x)
    return 1 if (unclassed or mismatch or stale) else 0
def do_classify(apply, out):
    plan = []
    for f in rows():
        rank, topic, owner, state = f[0], f[1], f[2], f[3]
        st = state.split(":")[0]
        if st not in LIVE: continue
        t = baton(topic)
        if t is None: print("REFUSE(2): no baton for %s" % topic); return 2
        c = classify(topic, t)
        new = RANK[c]
        if new == 1 and rank == "0": new = 0
        plan.append((topic, c, rank, new, st, owner))
    counts = {}
    for p in plan: counts[p[1]] = counts.get(p[1], 0) + 1
    print("CLASSIFY rows=%d  %s  rank_changes=%d%s" % (len(plan), " ".join("%s=%d" % kv for kv in sorted(counts.items())), sum(1 for p in plan if int(p[2]) != p[3]), "" if apply else "  (dry run)"))
    if out:
        with open(out, "w", encoding="utf-8") as o:
            for p in sorted(plan, key=lambda p: (p[1], p[0])): o.write("%-13s %s->%s %-16s %-11s %s\n" % (p[1], p[2], p[3], p[4], p[5], p[0]))
        print("  listing: %s" % out)
    if not apply: return 0
    stamp = time.strftime("%Y-%m-%d %H:%M")
    for topic, c, old, new, st, owner in plan:
        p = "%s/%s.task.md" % (TASKS, topic); t = open(p, encoding="utf-8", errors="replace").read()
        line = "CLASS: %s (util_queue_order_census.py classify, %s, CEO-1887 line 1: rank %d is the class)" % (c, stamp, new)
        if re.search(r"^CLASS:.*$", t, re.M): nt = re.sub(r"^CLASS:.*$", line, t, count=1, flags=re.M)
        elif re.search(r"^LINKS:.*$", t, re.M): nt = re.sub(r"^(LINKS:.*)$", lambda m: m.group(1) + "\n" + line, t, count=1, flags=re.M)
        else: nt = t.rstrip("\n") + "\n" + line + "\n"
        if nt != t: open(p, "w", encoding="utf-8").write(nt)
    LK = PO + "/.mint.lock"
    for _i in range(100):
        try: os.mkdir(LK); break
        except FileExistsError: time.sleep(0.1)
    else:
        print("REFUSE(2): %s is held by a bus verb for 10 s -- batons carry CLASS, no rank written; re-run classify --apply" % LK); return 2
    try:
        data = open(Q, "rb").read(); lines = data.split(b"\n"); want = {p[0]: p[3] for p in plan}; n = 0
        for i, l in enumerate(lines):
            f = l.split(b"\t")
            if len(f) >= 4 and f[0].isdigit() and f[1].decode("utf-8", "replace") in want:
                nr = str(want[f[1].decode("utf-8", "replace")]).encode()
                if f[0] != nr: f[0] = nr; lines[i] = b"\t".join(f); n += 1
        bak = Q + ".bak." + time.strftime("%Y%m%d-%H%M%S") + "-ceo-1887-classify"
        open(bak, "wb").write(data); open(Q, "wb").write(b"\n".join(lines))
    finally:
        os.rmdir(LK)
    print("  APPLIED: %d batons carry CLASS, %d ranks rewritten, backup %s" % (len(plan), n, bak))
    return 0
if __name__ == "__main__":
    a = sys.argv[1:]
    if a and a[0] == "classify":
        out = a[a.index("--out") + 1] if "--out" in a else None
        sys.exit(do_classify("--apply" in a, out))
    sys.exit(census())

#!/usr/bin/env python3
# util_baton_check.py -- every baton's NEXT under a cap, its SUPERSEDED blocks archived (DESIGN-PLAN box-scheduler step 15, CTO-496; the records are
# the cio's). A baton (/home/resources/postoffice/tasks/<topic>.task.md) is read at every `next`, every claim notice and every Stop-hook gate, and
# it is a seat's resume point, so its `## NEXT` must be short enough to read first thing: the cap is S4E_NEXT_CAP bytes (8192). MEASURED 2026-11-04
# 18:3x CST: 3898 batons, 35 NEXT blocks over 8 KB (the largest 66 KB), 1220 batons carrying `## SUPERSEDED-NEXT` blocks inline, 15 with two
# `## NEXT` headings. Nothing is deleted: a block that leaves a baton goes, stamped, to tasks/archive/<topic>.superseded.md.
#   util_baton_check.py --all            every baton: prints `BATONS over_cap=N superseded_inline=M multiple_next=K batons=T cap=C`; rc 0 iff N=M=K=0
#   util_baton_check.py --apply          archive every SUPERSEDED-NEXT block and every NEXT past the first; cut a NEXT over the cap at a paragraph
#                                        boundary under the cap, the whole original archived, a pointer line left; then --all
#   util_baton_check.py --probe          prove it on a scratch tasks directory: RED before, GREEN after, text in the archive, header lines kept
#   S4E_TASKS_DIR overrides the tasks directory (the probe and the sweep's scratch runs); rc 2 when the directory cannot be read
import os, re, sys, glob, datetime

TASKS = os.environ.get("S4E_TASKS_DIR") or os.path.join(os.environ.get("S4E_POST", "/home/resources/postoffice"), "tasks")
CAP = int(os.environ.get("S4E_NEXT_CAP", "8192"))
ME = os.environ.get("S4E_SEAT", "seat")
SEC = re.compile(r"^## ", re.M)


def sections(text):
    """-> (header, [(heading_line, body)]) : header is everything before the first `## `; each section keeps its heading line."""
    m = SEC.search(text)
    if not m:
        return text, []
    head, rest = text[:m.start()], text[m.start():]
    starts = [x.start() for x in SEC.finditer(rest)] + [len(rest)]
    out = []
    for a, b in zip(starts, starts[1:]):
        chunk = rest[a:b]
        nl = chunk.find("\n")
        out.append((chunk if nl < 0 else chunk[:nl], "" if nl < 0 else chunk[nl + 1:]))
    return head, out


def measure(text):
    _, secs = sections(text)
    nexts = [b for h, b in secs if h.rstrip() == "## NEXT"]
    sup = sum(1 for h, _ in secs if h.startswith("## SUPERSEDED-NEXT"))
    over = len(nexts[0].encode()) > CAP if nexts else False
    return over, sup, len(nexts)


def cut_under_cap(body, topic, stamp):
    note = "\n(... this NEXT was %d bytes, over the %d-byte cap; the whole of it is in archive/%s.superseded.md -- box-scheduler step 15, %s)\n" % (len(body.encode()), CAP, topic, stamp)
    room = CAP - len(note.encode()) - 64
    b = body.encode()
    if room <= 0:
        return note.lstrip("\n")
    head = b[:room].decode("utf-8", "ignore")
    cut = head.rfind("\n\n")
    if cut < room // 2:
        cut = head.rfind("\n")
    if cut > 0:
        head = head[:cut]
    return head.rstrip("\n") + "\n" + note.lstrip("\n")


def apply_one(path, stamp):
    text = open(path, encoding="utf-8", errors="replace").read()
    topic = os.path.basename(path)[:-len(".task.md")]
    head, secs = sections(text)
    if not secs:
        return 0
    moved, kept, seen_next = [], [], False
    for h, b in secs:
        if h.startswith("## SUPERSEDED-NEXT"):
            moved.append((h, b)); continue
        if h.rstrip() == "## NEXT":
            if seen_next:
                moved.append(("## SUPERSEDED-NEXT (a second NEXT heading)", b)); continue
            seen_next = True
            if len(b.encode()) > CAP:
                moved.append(("## SUPERSEDED-NEXT (the NEXT over the cap, whole)", b))
                b = cut_under_cap(b, topic, stamp)
        kept.append((h, b))
    if not moved:
        return 0
    arch_dir = os.path.join(TASKS, "archive"); os.makedirs(arch_dir, exist_ok=True)
    with open(os.path.join(arch_dir, topic + ".superseded.md"), "a", encoding="utf-8") as a:
        for h, b in moved:
            a.write("%s -- archived %s by %s (box-scheduler step 15)\n%s" % (h.rstrip(), stamp, ME, b if b.endswith("\n") else b + "\n"))
    out = head + "".join(h + "\n" + b for h, b in kept)
    led = "- [%s %s] %d block(s) (SUPERSEDED-NEXT, a second NEXT or a NEXT over the %d-byte cap) archived to archive/%s.superseded.md (box-scheduler step 15)\n" % (ME, stamp, len(moved), CAP, topic)
    if "\n## LEDGER\n" in out:
        out = out.replace("\n## LEDGER\n", "\n## LEDGER\n" + led, 1)
    else:
        out = out.rstrip("\n") + "\n## LEDGER\n" + led
    tmp = path + ".cap.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(out)
    os.replace(tmp, path)
    return len(moved)


def check():
    paths = glob.glob(os.path.join(TASKS, "*.task.md"))
    if not os.path.isdir(TASKS) or not paths:
        print("REFUSE(2) [baton-check]: no batons under %s" % TASKS); return 2
    over = sup = multi = 0
    for p in paths:
        o, s, n = measure(open(p, encoding="utf-8", errors="replace").read())
        over += 1 if o else 0; sup += 1 if s else 0; multi += 1 if n > 1 else 0
    print("BATONS over_cap=%d superseded_inline=%d multiple_next=%d batons=%d cap=%d" % (over, sup, multi, len(paths), CAP))
    return 0 if over == sup == multi == 0 else 1


def apply():
    if not os.path.isdir(TASKS):
        print("REFUSE(2) [baton-check]: no tasks directory %s" % TASKS); return 2
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    n = sum(apply_one(p, stamp) for p in glob.glob(os.path.join(TASKS, "*.task.md")))
    print("BATONS applied blocks_archived=%d archive=%s" % (n, os.path.join(TASKS, "archive")))
    return check()


def probe():
    import tempfile, subprocess, shutil
    t = tempfile.mkdtemp(prefix="s4e_baton_probe.")
    try:
        big = "resume here\n\n" + "\n\n".join("paragraph %d %s" % (i, "x" * 400) for i in range(30))
        open(os.path.join(t, "plant-big.task.md"), "w").write("# TASK plant-big\nGOAL: plant\nDONE-WHEN: false\nTOUCHES: a/b\n## NEXT\n%s\n## QA\n## LEDGER\n- [plant] minted\n" % big)
        open(os.path.join(t, "plant-sup.task.md"), "w").write("# TASK plant-sup\nGOAL: plant\nDONE-WHEN: false\n## NEXT\nlive next\n## SUPERSEDED-NEXT\nold next one\n## SUPERSEDED-NEXT 2\nold next two\n## QA\n## LEDGER\n")
        open(os.path.join(t, "plant-two.task.md"), "w").write("# TASK plant-two\nGOAL: plant\nDONE-WHEN: false\n## NEXT\nfirst next\n## NEXT\nsecond next\n## LEDGER\n")
        open(os.path.join(t, "plant-ok.task.md"), "w").write("# TASK plant-ok\nGOAL: plant\nDONE-WHEN: false\n## NEXT\nfine\n## QA\n## LEDGER\n")
        env = dict(os.environ, S4E_TASKS_DIR=t, S4E_SEAT=ME)
        r = subprocess.run([sys.executable, __file__, "--all"], env=env, capture_output=True, text=True)
        why = []
        if r.returncode != 1 or "over_cap=1 superseded_inline=1 multiple_next=1 batons=4" not in r.stdout:
            why.append("the plant did not read RED [%s rc=%d]" % (r.stdout.strip(), r.returncode))
        r = subprocess.run([sys.executable, __file__, "--apply"], env=env, capture_output=True, text=True)
        if r.returncode != 0 or "over_cap=0 superseded_inline=0 multiple_next=0" not in r.stdout:
            why.append("--apply did not end GREEN [%s rc=%d]" % (r.stdout.strip().replace("\n", " | "), r.returncode))
        big2 = open(os.path.join(t, "plant-big.task.md")).read()
        if len(big2.split("## NEXT\n", 1)[1].split("## ")[0].encode()) > CAP: why.append("the big NEXT is still over the cap")
        if "resume here" not in big2 or "TOUCHES: a/b" not in big2 or "GOAL: plant" not in big2: why.append("the big baton lost its head or its NEXT's first line")
        if "archive/plant-big.superseded.md" not in big2: why.append("no pointer to the archive in the cut NEXT")
        a = os.path.join(t, "archive", "plant-big.superseded.md")
        if not os.path.exists(a) or "paragraph 29" not in open(a).read(): why.append("the whole NEXT is not in the archive")
        sup2 = open(os.path.join(t, "plant-sup.task.md")).read()
        if re.search(r"^## SUPERSEDED-NEXT", sup2, re.M) or "live next" not in sup2: why.append("the superseded blocks were not moved or the live NEXT was")
        a = open(os.path.join(t, "archive", "plant-sup.superseded.md")).read()
        if "old next one" not in a or "old next two" not in a: why.append("a superseded block is missing from the archive")
        two2 = open(os.path.join(t, "plant-two.task.md")).read()
        if two2.count("## NEXT\n") != 1 or "first next" not in two2 or "second next" in two2: why.append("the second NEXT was not demoted")
        if "second next" not in open(os.path.join(t, "archive", "plant-two.superseded.md")).read(): why.append("the second NEXT is not archived")
        if open(os.path.join(t, "plant-ok.task.md")).read() != "# TASK plant-ok\nGOAL: plant\nDONE-WHEN: false\n## NEXT\nfine\n## QA\n## LEDGER\n": why.append("a baton under the cap was rewritten")
        if "(box-scheduler step 15)" not in sup2.split("## LEDGER\n", 1)[1]: why.append("no ledger line on a rewritten baton")
        r = subprocess.run([sys.executable, __file__, "--apply"], env=env, capture_output=True, text=True)
        if "blocks_archived=0" not in r.stdout: why.append("a second apply moved something [%s]" % r.stdout.strip().replace("\n", " | "))
        if why:
            print("BATONS PROBE RED: " + "; ".join(why)); return 1
        print("BATONS over_cap=0 superseded_inline=0 multiple_next=0 (probe: three planted defects read RED, --apply archived every block with a ledger line and a pointer, kept the head, the live NEXT and an untouched baton, and moved nothing the second time)")
        return 0
    finally:
        shutil.rmtree(t, ignore_errors=True)


if __name__ == "__main__":
    a = sys.argv[1] if len(sys.argv) > 1 else ""
    if a == "--all": sys.exit(check())
    if a == "--apply": sys.exit(apply())
    if a == "--probe": sys.exit(probe())
    print("usage: util_baton_check.py --all | --apply | --probe (box-scheduler step 15: every baton NEXT under %d bytes, SUPERSEDED blocks archived)" % CAP, file=sys.stderr)
    sys.exit(2)

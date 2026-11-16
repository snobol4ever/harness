#!/usr/bin/env python3
"""util_graphics_progress.py -- WORKS AND BUILT, the percent complete of the Icon graphics and of the Prolog graphics, two lines the Stop banner shows under the
summary by language (s4e_banner_cached.sh, for a seat whose banner carries the grid). Lon 2026-11-16 11:4x CST, in the coo's window, asked "how should we measure
percentage complete for Icon graphics? Prolog graphics?", and on the coo's answer, 11:5x CST, verbatim: "add the Works and Built lines to the banner".
WORKS IS THE PERCENT COMPLETE: the graphics programs the cycle grades that pass against the oracle. A graphics program is an entry of one of the language's
containers (SUITE_RUNNERS.tsv, kind master or pkg) whose out_files cell names screen.dump (the screen road, skill suites-and-grading section 4) or that carries
NAME.display. It passes when its newest clean mode-3 reading in the progress store is PASS (ONE DB: results.tsv, a -dirty tree unread). A FIRST PICTURE ALONE IS
NOT WORKING: in a container of programs that wait for a mouse or a key (column scripted of GRAPHICS_PROGRESS.tsv) an entry counts only when it has its event
script, NAME.events, and passes with it; the line says how many entries have one. The denominator is every graphics entry cut, so it grows as packages are cut.
BUILT EXPLAINS A FLAT WORKS: the steps of the design's step table (step 0, the baseline, left out) whose row is closed, a row named by the step's number
(column rows, a regular expression with N for the number) standing in QUEUE.done.tsv or its baton reading STATE: DONE or RETIRED:done-green.
Unicon's graphics are a separate library by Lon's ruling of 2026-11-16 09:5x and are left out (column excluded) until they have a line of their own.
THE GOAL LINES COME FIRST (Lon 2026-11-16 12:3x CST, in the coo's window, verbatim: "The number to watch as the countdown is Icon demo 10 to 177. Here we go. That
is the goal." / "Gui pack from 3 to 7 is also the goal."): a line of the table whose first column is goal names a label, a suite key and where its denominator is
read. The numerator is the suite row's newest pass count in SUITES.tsv, what the cycle graded; the denominator is the count of files a glob names (the library's
177 graphics programs, so the count has its true end before every program is an entry) or, for -, the row's own total, which grows as entries are cut.
Read only, nothing run. The table is GRAPHICS_PROGRESS.tsv beside this file: one line a language and one a goal.
  python3 -I util_graphics_progress.py            the header and one line a language; rc 0
  python3 -I util_graphics_progress.py --list     every graphics entry: language, suite key, entry, its newest reading, scripted or not, counted or not
  python3 -I util_graphics_progress.py --probe    five arms on a scratch store, corpus and postoffice; PROBE ok | RED"""
import csv, glob, os, re, shutil, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))


def env():
    top = os.environ.get("S4E_ONE_DISK_TOP", "/home")
    return {"top": top, "P": os.environ.get("S4E_PROGRESS", "/home/resources/progress"), "PO": os.environ.get("S4E_POST", "/home/resources/postoffice"),
            "db": os.environ.get("S4E_PROGRESS_DB") or os.path.join(os.environ.get("S4E_PROGRESS", "/home/resources/progress"), "results.tsv"),
            "table": os.environ.get("S4E_GRAPHICS_PROGRESS", os.path.join(HERE, "GRAPHICS_PROGRESS.tsv")),
            "runners": os.environ.get("S4E_SUITE_RUNNERS", os.path.join(HERE, "SUITE_RUNNERS.tsv")),
            "designs": os.environ.get("S4E_DESIGNS", os.path.join(os.path.dirname(HERE), "designs"))}


def table(e):
    rows = []
    for ln in open(e["table"], encoding="utf-8"):
        if ln.startswith("#") or not ln.strip(): continue
        f = ln.rstrip("\n").split("\t")
        if f[0] in ("lang", "goal"): continue
        f += [""] * (6 - len(f))
        rows.append({"lang": f[0], "label": f[1], "steps": f[2], "rows": f[3], "scripted": set(f[4].split(",")) - {"", "-"}, "excluded": set(f[5].split(",")) - {"", "-"}})
    return rows


def containers(e, lang, excluded):
    out = []
    for ln in open(e["runners"], encoding="utf-8"):
        f = ln.rstrip("\n").split("\t")
        if len(f) < 5 or ln.startswith("#") or f[2] != lang or f[1] not in ("master", "pkg") or f[0] in excluded: continue
        d = os.path.join(e["top"], f[4])
        if os.path.isfile(os.path.join(d, "ALL.csv")): out.append((f[0], d))
    return out


def entries(key, d):
    out = []
    try:
        rd = list(csv.DictReader(open(os.path.join(d, "ALL.csv"), encoding="utf-8", errors="replace")))
    except OSError:
        return out
    for r in rd:
        name = (r.get("entry") or "").strip()
        if not name: continue
        stems = [os.path.join(d, name)]
        if r.get("path"): stems.insert(0, os.path.join(d, os.path.splitext(r["path"])[0]))
        if "screen.dump" not in (r.get("out_files") or "").split() and not any(os.path.isfile(s + ".display") for s in stems): continue
        out.append((key, name, any(os.path.isfile(s + ".events") for s in stems)))
    return out


def readings(e, keys):
    new = {}
    try:
        fh = open(e["db"], encoding="utf-8", errors="replace")
    except OSError:
        return new
    for ln in fh:
        f = ln.rstrip("\n").split("\t")
        if len(f) < 10 or f[5] not in keys or f[8] != "m3" or f[1].endswith("-dirty") or f[2].endswith("-dirty"): continue
        k = (f[5], f[7])
        if k not in new or f[0] >= new[k][0]: new[k] = (f[0], f[9])
    return new


def built(e, row):
    steps = []
    try:
        for ln in open(os.path.join(e["designs"], row["steps"]), encoding="utf-8"):
            f = ln.split("\t")
            if f[0].isdigit() and int(f[0]) > 0: steps.append(int(f[0]))
    except OSError:
        return None
    done = set()
    try:
        for ln in open(os.path.join(e["PO"], "QUEUE.done.tsv"), encoding="utf-8", errors="replace"):
            f = ln.split("\t")
            if len(f) > 1: done.add(f[1])
    except OSError:
        pass
    for bp in glob.glob(os.path.join(e["PO"], "tasks", "*.task.md")):
        try:
            m = re.search(r"^STATE: (\S+)", open(bp, encoding="utf-8", errors="replace").read(4000), re.M)
        except OSError:
            continue
        if m and re.match(r"(DONE|RETIRED:done-green)", m.group(1)): done.add(os.path.basename(bp)[:-len(".task.md")])
    closed = [n for n in steps if any(re.match(row["rows"].replace("N", str(n)), t) for t in done)]
    return len(closed), len(steps)


def measure(e):
    out = []
    for row in table(e):
        ents = []
        for key, d in containers(e, row["lang"], row["excluded"]): ents += entries(key, d)
        new = readings(e, {k for k, _n, _s in ents})
        detail = []
        for key, name, scr in ents:
            rd = new.get((key, name), ("", "UNREAD"))[1]
            need = key in row["scripted"]
            detail.append((row["lang"], key, name, rd, scr, rd == "PASS" and (scr or not need)))
        out.append((row, detail, built(e, row)))
    return out


def goals(e):
    rows = {}
    try:
        for ln in open(os.path.join(e["P"], "SUITES.tsv"), encoding="utf-8"):
            f = ln.rstrip("\n").split("\t")
            if len(f) > 9 and not ln.startswith("#"): rows[f[0]] = f
    except OSError: pass
    out = []
    for ln in open(e["table"], encoding="utf-8"):
        f = ln.rstrip("\n").split("\t")
        if f[0] != "goal" or len(f) < 4: continue
        r = rows.get(f[2])
        have = int(r[8]) if r and r[8].isdigit() else None
        of = len(glob.glob(f[3])) if f[3] != "-" else (int(r[9]) if r and r[9].isdigit() else None)
        out.append((f[1], have, of))
    return out


def render(e):
    lines = []
    for label, have, of in goals(e):
        if have is None or not of: lines.append("%-17s%14s%8s  %s" % ("GOAL " + label, "?", "-", "the suite row or the library is unread")); continue
        lines.append("%-17s%14s%8s  %s" % ("GOAL " + label, "%d/%d" % (have, of), "%5.1f%%" % (100.0 * have / of), "%d to go" % (of - have) if of > have else "REACHED"))
    lines.append("%-17s%14s%8s  %-22s%s" % ("Graphics", "Works", "Pct", "", "Built"))
    for row, detail, b in measure(e):
        n = len(detail); w = sum(1 for d in detail if d[5]); s = sum(1 for d in detail if d[4])
        need = sum(1 for d in detail if d[1] in row["scripted"])
        pct = "%5.1f%%" % (100.0 * w / n) if n else "    -"
        note = "none cut yet" if not n else ("%d of %d scripted" % (sum(1 for d in detail if d[4] and d[1] in row["scripted"]), need) if need else "%d scripted" % s)
        bt = "no step table" if b is None else "%d/%d steps" % b
        lines.append("%-17s%14s%8s  %-22s%s" % (row["label"], "%d/%d" % (w, n), pct, note, bt))
    return lines


def probe():
    t = tempfile.mkdtemp(prefix="gfxprobe."); why = ""
    try:
        d = os.path.join(t, "corpus/packages/icon/pk"); os.makedirs(d); os.makedirs(os.path.join(t, "po/tasks")); os.makedirs(os.path.join(t, "designs/x")); os.makedirs(os.path.join(t, "corpus/packages/icon/rs"))
        open(os.path.join(d, "ALL.csv"), "w").write("rank,entry,path,out_files\n1,a,a.icn,screen.dump\n2,b,b.icn,screen.dump\n3,c,c.icn,screen.dump\n")
        open(os.path.join(d, "a.events"), "w").write("key q\n")
        open(os.path.join(t, "corpus/packages/icon/rs/ALL.csv"), "w").write("rank,entry,out_files\n1,fern,screen.dump\n2,text,\n3,disp,\n")
        open(os.path.join(t, "corpus/packages/icon/rs/disp.display"), "w").write("")
        open(os.path.join(t, "runners.tsv"), "w").write("pk\tpkg\ticon\tr\tcorpus/packages/icon/pk\nrs\tpkg\ticon\tr\tcorpus/packages/icon/rs\n")
        open(os.path.join(t, "table.tsv"), "w").write("lang\tlabel\tsteps\trows\tscripted\texcluded\nicon\tIcon graphics\tx/STEPS.tsv\t^xw-(w|step-)N-\tpk\t-\n")
        open(os.path.join(t, "designs/x/STEPS.tsv"), "w").write("# c\nstep\tslug\n0\tbaseline\n1\tone\n2\ttwo\n3\tthree\n")
        open(os.path.join(t, "po/QUEUE.done.tsv"), "w").write("# h\n0\txw-w1-one\tx\tDONE\n")
        open(os.path.join(t, "po/tasks/xw-step-2-two.task.md"), "w").write("# t\nSTATE: DONE\n")
        open(os.path.join(t, "po/tasks/xw-w3-three.task.md"), "w").write("# t\nSTATE: CLAIMED:x\n")
        H = "ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\n"
        def db(rows): open(os.path.join(t, "results.tsv"), "w").write(H + "".join("\t".join(r) + "\n" for r in rows))
        e = {"top": t, "P": t, "PO": os.path.join(t, "po"), "db": os.path.join(t, "results.tsv"), "table": os.path.join(t, "table.tsv"), "runners": os.path.join(t, "runners.tsv"), "designs": os.path.join(t, "designs")}
        def works(): return [(sum(1 for d in det if d[5]), len(det), b) for _r, det, b in measure(e)][0]
        db([]); g = works()
        if g != (0, 5, (2, 3)): why += " arm1 an empty store reads %r, wanted 0 of 5 and 2 of 3 steps;" % (g,)
        db([("2026-01-01T00:00:00", "s", "c", "g", "package", "pk", "icon", "a", "m3", "PASS"), ("2026-01-01T00:00:00", "s", "c", "g", "package", "pk", "icon", "b", "m3", "PASS"),
            ("2026-01-01T00:00:00", "s", "c", "g", "package", "rs", "icon", "fern", "m3", "PASS"), ("2026-01-01T00:00:00", "s", "c", "g", "package", "rs", "icon", "text", "m3", "PASS")]); g = works()
        if g[0] != 2: why += " arm2 a scripted pass, a first-picture pass and a plain screen pass read %d works, wanted 2 (b has no script; text is no graphics entry);" % g[0]
        db([("2026-01-01T00:00:00", "s", "c", "g", "package", "pk", "icon", "a", "m3", "PASS"), ("2026-01-02T00:00:00", "s", "c", "g", "package", "pk", "icon", "a", "m3", "FAIL")]); g = works()
        if g[0] != 0: why += " arm3 a newer FAIL over a PASS reads %d works, wanted 0;" % g[0]
        db([("2026-01-01T00:00:00", "s-dirty", "c", "g", "package", "pk", "icon", "a", "m3", "PASS"), ("2026-01-01T00:00:00", "s", "c", "g", "package", "pk", "icon", "a", "m4", "PASS")]); g = works()
        if g[0] != 0: why += " arm4 a dirty reading and a mode-4 reading read %d works, wanted 0;" % g[0]
        db([("2026-01-01T00:00:00", "s", "c", "g", "package", "rs", "icon", "disp", "m3", "PASS")]); g = works()
        if g[0] != 1: why += " arm5 an entry with NAME.display passing reads %d works, wanted 1;" % g[0]
        os.makedirs(os.path.join(t, "lib"))
        for n in "abcde": open(os.path.join(t, "lib", n + ".icn"), "w").write("")
        open(os.path.join(t, "SUITES.tsv"), "w").write("# h\n" + "\t".join(["pk", "L", "x", "icon", "d", "0", "7", "d", "3", "7", "tree"]) + "\n")
        open(os.path.join(t, "table.tsv"), "a").write("goal\tIcon demos\tpk\t%s\ngoal\tGUI packs\tpk\t-\ngoal\tNo row\tnone\t-\n" % os.path.join(t, "lib", "*.icn"))
        g = goals(e)
        if g != [("Icon demos", 3, 5), ("GUI packs", 3, 7), ("No row", None, None)]: why += " arm6 the goal lines read %r, wanted 3 of 5 by the glob, 3 of 7 by the row, and a missing row unread;" % (g,)
        if len(measure(e)) != 1: why += " arm6 a goal line was read as a language line;"
    finally:
        shutil.rmtree(t, ignore_errors=True)
    print("GRAPHICS-PROGRESS PROBE " + ("RED:" + why if why else "ok arms=6 (empty store, the script rule, newest wins, dirty and mode 4 unread, a display entry, the goal lines; steps closed by the done file and by a baton, never by a claim)"))
    return 1 if why else 0


if __name__ == "__main__":
    if "--probe" in sys.argv: sys.exit(probe())
    e = env()
    if "--list" in sys.argv:
        for row, detail, _b in measure(e):
            for lang, key, name, rd, scr, cnt in detail: print("\t".join((lang, key, name, rd, "scripted" if scr else "-", "WORKS" if cnt else "-")))
        sys.exit(0)
    try:
        print("\n".join(render(e)))
    except Exception as ex:   # the banner is never lost to a line that could not be read
        print("Graphics: unreadable (%s)" % type(ex).__name__)

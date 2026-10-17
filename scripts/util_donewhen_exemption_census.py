#!/usr/bin/env python3
"""util_donewhen_exemption_census.py -- AN EXEMPTION IS INVISIBLE TO THE THING IT EXEMPTS (ceo CEO-967, on the coo's COO-116 report;
row instruments-the-donewhen-exemption-census-names-every-criterion-that-measures-its-one-runner-exemption).

The bus runs every computed DONE-WHEN with S4E_DONE_WHEN_RUN=1, a sanctioned ONE-RUNNER exemption (lib_one_runner.sh admits the run
whatever seat asks). So a criterion that shells out to a board, a suite runner or the guard itself and reads what comes back can be
measuring THE EXEMPTION rather than its subject: measured on COO-116, the one criterion on one tree read G=0 with the exemption set
and G=2 with it cleared. This census NAMES every such baton -- it fixes none (the ceo: "name them, do not sweep them") -- because for
some rows the exemption merely admits a run the criterion wants, and for others it is the whole verdict, and only the row's owner can
tell which. Each exposed baton is printed with its QUEUE.tsv owner and state, the mechanism it shells out to, and a class:

  GUARD   the criterion runs the one-runner guard itself (lib_one_runner.sh, one_runner_guard) and reads its answer -- under the
          exemption the guard admits everyone, so the verdict IS the exemption. The owner must rewrite it.
  BOARD   the criterion runs a guarded board or runner (a name in ../harness/scripts/one_runner_boards.txt, corpus_suite_harness.py run, or any
          test_*_suite.sh / board_*.sh / scorecard_*.sh) and reads its rc or output -- the exemption ADMITS the run; the owner says
          whether admitting it is what the criterion means.
  SMOKE   every guarded runner it names runs as an AREA SMOKE the guard admits for every seat (ceo CEO-1505, row instruments-the-
          donewhen-census-names-an-area-smoke-as-a-board): S4E_AREA_SMOKE_ENTRIES set non-empty on that command (or exported before
          it), the runner one of lib_one_runner.sh's ONE_RUNNER_SMOKE_MODE_RUNNERS -- READ FROM THAT LINE, never copied here -- and no
          population named (no --corpus, no CORPUS=), the three conditions one_runner_guard admits on. A smoke writes no progress row
          and no score row, so it is not a board run; counted, never named as exposed. A plain run of the same runner, a smoke of a
          runner without a smoke mode, or a smoke beside any other board stays BOARD.
  ONEFILE every guarded runner it names runs in its ONE-FILE mode the guard admits for every seat and for the bus done (ceo CEO-1664):
          the runner one of lib_one_runner.sh's ONE_RUNNER_SINGLE_FILE_RUNNERS -- READ FROM THAT LINE -- with --file <one file> on every
          command naming it and no population named. That mode grades exactly one file and writes no progress row and no score row, so
          it is not a board run; counted, never named as exposed. The same runner without --file stays BOARD.
  CLEAR   it runs one of those but clears the exemption first (env -u S4E_DONE_WHEN_RUN, S4E_DONE_WHEN_RUN= , unset) -- measured
          on its own terms; counted, never named as exposed.

EXIT 0: measured, no LIVE baton exposed. 1: at least one live baton exposed (named). 2: the tasks tree, QUEUE or the guard's smoke-mode
list could not be read -- a
census that reports zero exposed rows because it could not look is the very defect it exists to name. S4E_TASKS / S4E_QUEUE redirect
it (the gate's fixture); --json prints one JSON document instead of lines; --all names DONE rows too.
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
PO = os.environ.get("S4E_POSTOFFICE", "/home/resources/postoffice")
TASKS = os.environ.get("S4E_TASKS") or os.path.join(PO, "tasks")
QUEUE = os.environ.get("S4E_QUEUE") or os.path.join(PO, "QUEUE.tsv")
CLEAR_RX = re.compile(r"env\s+-u\s+S4E_DONE_WHEN_RUN\b|\bunset\s+S4E_DONE_WHEN_RUN\b|\bS4E_DONE_WHEN_RUN=(?:\s|$|''|\"\")")
GUARD_RX = re.compile(r"\blib_one_runner\.sh\b|\bone_runner_guard\b")
GENERIC_RX = re.compile(r"\b(test_[a-z0-9_]+_suite\.sh|board_[a-z0-9_]+\.sh|scorecard_[a-z0-9_]+\.sh)\b")
HARNESS_RX = re.compile(r"\bcorpus_suite_harness\.py\s+run\b")
SMOKE_LIST_RX = re.compile(r'^ONE_RUNNER_SMOKE_MODE_RUNNERS="([^"]*)"', re.M)
ONEFILE_LIST_RX = re.compile(r'^ONE_RUNNER_SINGLE_FILE_RUNNERS="([^"]*)"', re.M)
ONEFILE_ARG_RX = re.compile(r"(?:^|\s)--file\s+[^\s;&|)]+")
SMOKE_SET_RX = re.compile(r"""\bS4E_AREA_SMOKE_ENTRIES=(?:"[^"]+"|'[^']+'|[^\s"';&|]+)""")
SMOKE_EXPORT_RX = re.compile(r"""\bexport\s+S4E_AREA_SMOKE_ENTRIES=(?:"[^"]+"|'[^']+'|[^\s"';&|]+)""")
POPULATION_RX = re.compile(r"(?:^|\s)--corpus\b|\bCORPUS=")
SEGMENT_RX = re.compile(r"&&|\|\||;|\||\n")


def boards():
    p = os.path.join(HERE, "one_runner_boards.txt")
    try:
        return {l.strip() for l in open(p, encoding="utf-8") if l.strip() and not l.startswith("#")}
    except OSError:
        return set()


def smoke_runners():
    """the runners one_runner_guard admits as an area smoke: lib_one_runner.sh's own list, or None when it cannot be read."""
    try:
        m = SMOKE_LIST_RX.search(open(os.path.join(HERE, "lib_one_runner.sh"), encoding="utf-8").read())
    except OSError:
        return None
    return set(m.group(1).split()) if m else None


def onefile_runners():
    """the runners one_runner_guard admits in their one-file mode: lib_one_runner.sh's own list, empty when it names none."""
    try:
        m = ONEFILE_LIST_RX.search(open(os.path.join(HERE, "lib_one_runner.sh"), encoding="utf-8").read())
    except OSError:
        return set()
    return set(m.group(1).split()) if m else set()


def onefile_admitted(dw, runner):
    """True when every command of dw that names runner passes it --file <one file> and names no population."""
    seen = False
    for seg in SEGMENT_RX.split(dw):
        if re.search(r"\b" + re.escape(runner) + r"\b", seg):
            seen = True
            if not ONEFILE_ARG_RX.search(seg) or POPULATION_RX.search(seg):
                return False
    return seen


def smoke_admitted(dw, runner):
    """True when every command of dw that names runner is an area smoke the guard admits: the entries set non-empty on that command
    or exported before it, and no population named on it."""
    exported, seen = False, False
    for seg in SEGMENT_RX.split(dw):
        if re.search(r"\b" + re.escape(runner) + r"\b", seg):
            seen = True
            if not (exported or SMOKE_SET_RX.search(seg)) or POPULATION_RX.search(seg):
                return False
        if SMOKE_EXPORT_RX.search(seg):
            exported = True
    return seen


def donewhen(path):
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("DONE-WHEN:"):
            return line[len("DONE-WHEN:"):].strip()
    return None


def classify(dw, board_names, smoke_names=frozenset(), onefile_names=frozenset()):
    mech = []
    for m in GUARD_RX.findall(dw):
        mech.append(m)
    guard = bool(mech)
    for b in sorted(board_names):
        if re.search(r"\b" + re.escape(b) + r"\b", dw):
            mech.append(b)
    mech += [m for m in GENERIC_RX.findall(dw) if m not in mech]
    if HARNESS_RX.search(dw):
        mech.append("corpus_suite_harness.py run")
    if not mech:
        return None, []
    if CLEAR_RX.search(dw):
        return "CLEAR", mech
    if not guard and all(m in onefile_names and onefile_admitted(dw, m) for m in mech):
        return "ONEFILE", mech
    if not guard and all(m in smoke_names and smoke_admitted(dw, m) for m in mech):
        return "SMOKE", mech
    return ("GUARD" if guard else "BOARD"), mech


def main(argv):
    as_json, show_all = "--json" in argv, "--all" in argv
    if not os.path.isdir(TASKS):
        print(f"REFUSED(2): the tasks tree {TASKS} is not readable -- a census that cannot look reports nothing, never zero", file=sys.stderr)
        return 2
    try:
        q = [l.rstrip("\n").split("\t") for l in open(QUEUE, encoding="utf-8", errors="replace") if l.strip() and not l.startswith("#")]
    except OSError as e:
        print(f"REFUSED(2): QUEUE {QUEUE} is not readable ({e}) -- owners and states cannot be named", file=sys.stderr)
        return 2
    rows = {c[1]: (c[2] if len(c) > 2 else "", c[3] if len(c) > 3 else "") for c in q if len(c) > 1}
    names = sorted(f for f in os.listdir(TASKS) if f.endswith(".task.md"))
    bn, sm, of = boards(), smoke_runners(), onefile_runners()
    if sm is None:
        print("REFUSED(2): ONE_RUNNER_SMOKE_MODE_RUNNERS is not readable in lib_one_runner.sh -- the census cannot tell an admitted area "
              "smoke from a board run", file=sys.stderr)
        return 2
    with_dw, out = 0, []
    counts = {"ONEFILE": 0, "GUARD": 0, "BOARD": 0, "SMOKE": 0, "CLEAR": 0}
    for f in names:
        dw = donewhen(os.path.join(TASKS, f))
        if dw is None:
            continue
        with_dw += 1
        cls, mech = classify(dw, bn, sm, of)
        if not cls:
            continue
        topic = f[:-len(".task.md")]
        owner, state = rows.get(topic, ("", "not in QUEUE.tsv"))
        live = topic in rows and not re.match(r"(DONE|SUPERSEDED)", state or "")
        counts[cls] += 1
        out.append({"topic": topic, "owner": owner, "state": state, "live": live, "class": cls, "mechanism": mech})
    exposed_live = [r for r in out if r["class"] in ("GUARD", "BOARD") and r["live"]]
    if as_json:
        print(json.dumps({"tasks": TASKS, "batons_with_donewhen": with_dw, "counts": counts, "exposed_live": len(exposed_live),
                          "rows": out if show_all else [r for r in out if r["live"]]}, indent=1))
    else:
        for r in out:
            if r["class"] in ("SMOKE", "CLEAR", "ONEFILE") or not (r["live"] or show_all):
                continue
            print(f"  {r['class']:5}  {r['owner'] or '-':12} {r['state'][:22]:22} {r['topic'][:110]}  <- {', '.join(r['mechanism'][:3])}")
        print(f"population: {with_dw} baton(s) with a DONE-WHEN under {TASKS}; {len(out)} shell out to the guard or a guarded runner: "
              f"ONEFILE {counts['ONEFILE']}, GUARD {counts['GUARD']}, BOARD {counts['BOARD']}, SMOKE {counts['SMOKE']}, CLEAR {counts['CLEAR']}; exposed and LIVE: {len(exposed_live)}")
    return 1 if exposed_live else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

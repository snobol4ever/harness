#!/usr/bin/env python3
# util_suite_runners.py -- THE RUNNER TABLE (DESIGN-PLAN test-cycle step 9; skill suites-and-grading reference.md section 7, the cio 2026-11-07).
#
#   --write-from-loop LOOP8.sh   write harness/scripts/SUITE_RUNNERS.tsv from the coo loop's ROT array and SUITES.tsv (run once; the table is then the record)
#   --check [--table PATH] [--suites PATH]
#                                rc 0 and the line SUITE_RUNNERS keys=N packages=P missing_runner=0 unlisted_suites=0 when every SUITES.tsv key has a row,
#                                every runner file exists under harness/scripts, and every master, pkg and port table has a PARTITION.tsv; rc 1 naming each
#                                gap; rc 2 when a file is missing.
# THE COLUMNS (key kind lang runner table; one row per SUITES.tsv key, in SUITES order):
#   master  a language container: runner corpus_suite_harness.py, table corpus/tests/<lang> (its PARTITION.tsv is the cells)
#   pkg     a package suite: runner its test_<lang>_<pkg>_suite.sh (Roast: raku_roast_scoreboard.sh --run; the args follow the file), table corpus/packages/<dir>
#   small   a demos or benchmark suite that runs whole as one chunk (CEO-1802): runner as the loop names it, table - (its tree is the runner's own)
#   port    a key named <bare>@<engine> (sno-rungs@dotnet): the bare key's runner and table; the engine is in the key (the ports skill)
#   none    a key with no runner anywhere: runner -, counted as missing_runner
# The ROT lines it reads: master|<lang> ; pkg|<member>|<lang>|<runner>|<key>|<pkgdir> ; small|<member>|<key>|<runner and args>. The port members are not keys.
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import harness_paths   # THE ABSOLUTE MODEL: corpus() is S4E_CORPUS, else /home/corpus once it is a checkout, else the root's sibling
TABLE = os.path.join(HERE, "SUITE_RUNNERS.tsv")
SUITES = os.environ.get("S4E_SUITES_TSV", "/home/resources/progress/SUITES.tsv")
RUNGS = {"snobol4": "sno-rungs", "icon": "icn-rungs", "prolog": "pl-rungs", "pascal": "pas-rungs", "raku": "raku-rungs", "snocone": "snc-rungs", "rebus": "reb-rungs"}
KINDS = ("master", "pkg", "small", "port", "none")

def refuse(msg):
    print("REFUSE(2) [util_suite_runners]: " + msg, file=sys.stderr)
    sys.exit(2)

def read_suites(path):
    if not os.path.isfile(path):
        refuse("no SUITES.tsv at %s" % path)
    out = []
    for ln in open(path, encoding="utf-8", errors="replace"):
        if ln.startswith("#"):
            continue
        f = ln.rstrip("\n").split("\t")
        if len(f) < 4 or f[0] == "key" or not f[0]:
            continue
        out.append((f[0], f[3]))
    return out

def rot_entries(text):
    out, inside = [], False
    for ln in text.splitlines():
        s = ln.strip()
        if not inside:
            if not s.startswith("ROT=("):
                continue
            inside, s = True, s[len("ROT=("):].strip()
        if s.startswith("#"):
            continue
        out.extend(m.group(1) for m in re.finditer(r'"([^"]*)"', s))
        if s == ")" or s.startswith(")"):
            break
    return out

def rot_rows(entries):
    rows = {}
    for e in entries:
        p = e.split("|")
        if p[0] == "master" and len(p) == 2 and p[1] in RUNGS:
            rows[RUNGS[p[1]]] = ("master", p[1], "corpus_suite_harness.py", "corpus/tests/" + p[1])  # one-disk: not a path
        elif p[0] == "pkg" and len(p) == 6:
            rows[p[4]] = ("pkg", p[2], p[3], "corpus/packages/" + p[5])  # one-disk: not a path
        elif p[0] == "small" and len(p) == 4:
            rows[p[2]] = ("small", None, p[3], "-")
    return rows

def build(suites, rot):
    row = {}
    for key, lang in suites:
        if "@" in key:
            continue
        if key in rot:
            kind, rlang, runner, table = rot[key]
            row[key] = (kind, rlang or lang, runner, table)
        elif os.path.isfile(os.path.join(str(harness_paths.corpus(ROOT)), "tests", lang or "-", "PARTITION.tsv")):
            row[key] = ("master", lang, "corpus_suite_harness.py", "corpus/tests/" + lang)  # one-disk: not a path
        else:
            row[key] = ("none", lang, "-", "-")
    out = []
    for key, lang in suites:
        if key in row:
            kind, rlang, runner, table = row[key]
        else:
            base = row.get(key.split("@")[0], ("none", lang, "-", "-"))
            kind, rlang, runner, table = "port", lang, base[2], base[3]
        out.append((key, kind, rlang or lang or "-", runner, table))
    return out

def write_from_loop(loop_path):
    if not os.path.isfile(loop_path):
        refuse("no loop file at %s" % loop_path)
    rows = build(read_suites(SUITES), rot_rows(rot_entries(open(loop_path, encoding="utf-8", errors="replace").read())))
    head = [
        "# SUITE_RUNNERS.tsv -- THE RUNNER TABLE (DESIGN-PLAN test-cycle step 9; skill suites-and-grading reference.md section 7). Written once by",
        "# util_suite_runners.py --write-from-loop from the coo loop's ROT array and SUITES.tsv; kept by util_suite_runners.py --check (the gate).",
        "# Columns: key kind lang runner table. kind master|pkg|small|port|none (see util_suite_runners.py). The grade worker reads it: a master or pkg row",
        "# launches; a package cell runs S4E_CHUNK=<cell> bash harness/scripts/<runner> under util_run_slot.sh. SUITES.tsv itself gains no column.",  # one-disk: not a path
    ]
    with open(TABLE, "w", encoding="utf-8") as f:
        f.write("\n".join(head) + "\n")
        for r in rows:
            f.write("\t".join(r) + "\n")
    print("WROTE %s rows=%d" % (TABLE, len(rows)))
    return 0

def read_table(path):
    if not os.path.isfile(path):
        refuse("no runner table at %s" % path)
    rows = []
    for ln in open(path, encoding="utf-8", errors="replace"):
        if ln.startswith("#") or not ln.strip():
            continue
        f = ln.rstrip("\n").split("\t")
        if len(f) != 5:
            refuse("%s: a row with %d columns (want 5): %r" % (path, len(f), ln.rstrip()[:120]))
        rows.append(dict(zip(("key", "kind", "lang", "runner", "table"), f)))
    return rows

def check(table_path, suites_path):
    suites = read_suites(suites_path)
    rows = read_table(table_path)
    have = {r["key"] for r in rows}
    gaps = []
    unlisted = [k for k, _ in suites if k not in have]
    gaps += ["unlisted %s" % k for k in unlisted]
    missing_runner = 0
    for r in rows:
        if r["kind"] not in KINDS:
            gaps.append("kind %s %s" % (r["key"], r["kind"]))
        runner = r["runner"]
        if runner == "-" or not os.path.isfile(os.path.join(HERE, runner.split()[0])):
            missing_runner += 1
            gaps.append("missing_runner %s runner=%s" % (r["key"], runner))
        partitioned = r["kind"] in ("master", "pkg") or (r["kind"] == "port" and r["table"] != "-")
        if partitioned and not os.path.isfile(os.path.join(ROOT, r["table"], "PARTITION.tsv")):
            gaps.append("partition %s table=%s" % (r["key"], r["table"]))
        if r["kind"] == "small" and r["table"] != "-" and not os.path.isdir(os.path.join(ROOT, r["table"])):
            gaps.append("table %s table=%s" % (r["key"], r["table"]))
    packages = sum(1 for r in rows if r["kind"] == "pkg")
    line = "SUITE_RUNNERS keys=%d packages=%d missing_runner=%d unlisted_suites=%d" % (len(rows), packages, missing_runner, len(unlisted))
    print(line)
    for g in gaps:
        print("GAP " + g)
    return 0 if not gaps else 1

def main(argv):
    if not argv:
        refuse("usage: util_suite_runners.py --write-from-loop LOOP8.sh | --check [--table PATH] [--suites PATH]")
    if argv[0] == "--write-from-loop" and len(argv) == 2:
        return write_from_loop(argv[1])
    if argv[0] == "--check":
        table, suites = TABLE, SUITES
        rest = argv[1:]
        while rest:
            if rest[0] == "--table" and len(rest) >= 2:
                table, rest = rest[1], rest[2:]
            elif rest[0] == "--suites" and len(rest) >= 2:
                suites, rest = rest[1], rest[2:]
            else:
                refuse("unknown argument %r" % rest[0])
        return check(table, suites)
    refuse("usage: util_suite_runners.py --write-from-loop LOOP8.sh | --check [--table PATH] [--suites PATH]")

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

#!/usr/bin/env python3
"""util_scratch_snobol4_rungs.py ROOT PATTERN -- a scratch SNOBOL4 world for a gate that runs test_corpus_snobol4.sh.

   python3 ../harness/scripts/util_scratch_snobol4_rungs.py "$TMP/snoroot" '\\b[NF]RETURN\\b'
   S4E_HOME="$TMP/snoroot" S4E_PROGRESS_DB="$TMP/p.tsv" RUNGS_ENTRY_FLOOR=<entries> bash ../harness/scripts/test_corpus_snobol4.sh

ROOT/corpus/tests/snobol4/ALL.sno and ALL.ref hold the rungs entries whose source matches PATTERN (a Python regex), leaving out
every XFAIL entry (a standing red, RULES.md) and every entry ALL.outside.tsv names (outside the baseline), in the rungs' own
format and order: written by the harness's own extract-family over a copy of ALL.csv whose selected rows carry one family, so the
stdin and xfail sidecars travel as they do for any family, and so do ALL.cmdline, ALL.heap and ALL.stack -- each entry compiles
under its own declared switches, heap and stack. No ALL.csv is written beside them: the harness refuses a unit that declares its
command line in both (two answers to one question). The runner's fixed demo rows need their programs, so
ROOT/corpus/demos/snobol4 is a copy; ROOT/corpus/include links back to the shared library, read only; ROOT/corpus/crosscheck is
empty, the loose tree the runner still looks for; ROOT/corpus is `git init`ed with no remote, the world the harness admits as a
fixture. Prints "SCRATCH_RUNGS entries=N root=ROOT pattern=PATTERN"; rc 2 when the
rungs cannot be read or nothing matches.

⛔ WHY (ceo CEO-1302 (c), 2026-09-27): the one-runner fixture exemption holds only for a population outside the shared corpus.
test_gate_nreturn_by_name_value_broken.sh and test_gate_snocone_returns_codegen.sh ran test_corpus_snobol4.sh over the real
1991-entry rungs as their SNOBOL4 non-regression arm, so the coo's control arm of 2026-09-26 made two whole SnoRungs passes and
appended 7964 rows. They now grade the rungs entries their rows are about, in a root that is no checkout of the shared corpus.
"""
import csv, os, re, shutil, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import corpus_suite_harness as h  # noqa: E402

SLICE = "__scratch_rungs_slice__"


def refuse(msg):
    print("⛔ REFUSE(2) util_scratch_snobol4_rungs: %s" % msg, file=sys.stderr)
    sys.exit(2)


def main(argv):
    if len(argv) != 3:
        print(__doc__.split("\n\n")[0]); return 2
    root, pattern = Path(argv[1]), re.compile(argv[2])
    corpus = Path(os.environ.get("S4E_SCRATCH_SOURCE_CORPUS") or HERE.parent.parent / "corpus")
    m = corpus / "tests" / "snobol4"
    sno, ref, csvp, outside = m / "ALL.sno", m / "ALL.ref", m / "ALL.csv", m / "ALL.outside.tsv"
    for p in (sno, ref, csvp):
        if not p.is_file():
            refuse("no %s" % p)
    _in, _x = h.sidecar_in_path(str(sno)), h.sidecar_xfail_path(str(sno))
    try:   # the reads extract-family itself makes, in its order: a banner-block suite, else the mixed one-line and block reader
        entries = h.read_block_suite(str(sno), str(ref), h.banner_re_for("*", ""), in_path=_in, x_path=_x)
    except Exception:
        try:
            entries = h.read_suite(str(sno), str(ref), in_path=_in, x_path=_x)
        except Exception as e:
            refuse("the rungs does not read: %s" % e)
    out_names = set()
    if outside.is_file():
        for line in outside.read_text().splitlines():
            if line.strip() and not line.startswith("#"):
                out_names.add(line.split("\t")[0].strip())
    sel = [e.name for e in entries if pattern.search("\n".join(e.sno_lines)) and not e.xfail and e.name not in out_names]
    if not sel:
        refuse("no rungs entry matches %r outside the XFAIL and outside-baseline sets" % argv[2])
    want = set(sel)
    with open(csvp, newline="") as f:
        rdr = csv.DictReader(f)
        head, rows = rdr.fieldnames, list(rdr)
    mt = root / "corpus" / "tests" / "snobol4"
    mt.mkdir(parents=True, exist_ok=True)
    marked = root / "slice.csv"
    with open(marked, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=head, lineterminator="\n")
        w.writeheader()
        for r in rows:
            w.writerow(dict(r, family=SLICE) if r["entry"] in want else r)
    r = subprocess.run([sys.executable, str(HERE / "corpus_suite_harness.py"), "extract-family", str(sno), str(ref), str(marked), SLICE,
                        str(mt / "ALL.sno"), str(mt / "ALL.ref")], capture_output=True, text=True)
    if r.returncode != 0:
        refuse("extract-family refused rc=%d: %s" % (r.returncode, (r.stderr or r.stdout).strip()[:400]))
    marked.unlink()
    (root / "corpus" / "crosscheck").mkdir(exist_ok=True)
    # a git world with no remote: the harness judges a suite under its configured corpus root by that root's remote, and an
    # unreadable answer is a board (lib_one_runner.sh one_runner_corpus_is_the_shared_population) -- `git init` is the fixture shape
    if not (root / "corpus" / ".git").exists():
        subprocess.run(["git", "init", "-q", str(root / "corpus")], check=True)
    inc = root / "corpus" / "include"
    if not inc.exists():
        shutil.copytree(corpus / "include", inc)
    demos = root / "corpus" / "demos" / "snobol4"
    if not demos.exists():
        demos.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(corpus / "demos" / "snobol4", demos, symlinks=True)
    print("SCRATCH_RUNGS entries=%d root=%s pattern=%s" % (len(sel), root, argv[2]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

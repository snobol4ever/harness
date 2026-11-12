#!/usr/bin/env python3
"""util_package_layout_census.py -- EVERY FILE OF A PACKAGE, NAMED BY ITS ROLE (the cio 2026-11-10, CIO-59, CIO-60, CIO-113; Lon in the cio's window,
verbatim: "We also need major clean up in the $/corpus/packages language folders just like the \"tests\" folder but they will not have ONE LINERS
and MULTI LINERS. Instead the programs will have the same layout as in the distribution from which it came, and side-by-side files with NAME.in,
NAME.out, and NAME.err files. And slightly varying ALL files."). The sister of util_tests_layout_census.py, which reads a test folder.

usage: util_package_layout_census.py --package DIR [--check] [--list] | --probe
For every file git tracks under DIR (every file on disk when DIR is in no repository) one role:
  INDEX      ALL.csv, ALL.args, ALL.omit, ALL.mask, ALL.rc, ALL.source (the collection a row's program is read from in place, CIO-92), ALL.stdin (an entry's standard input, a file of that collection by its path, COO-514) and ALL.launch at the
             package root; and ALL.dialect there while ALL.csv has no dialect column: the builder's own
             record of the oracle's mode that cut each answer, which the grader does not read (with the column it is a second home of one fact and reads
             LOOSE, to leave in the landing that writes the column; the cio's ruling of 2026-11-11 on rosetta-pascal)
  PROGRAM    a file the path column of ALL.csv names for a row ALL.omit does not name
  STREAM     STEM.in, STEM.out or STEM.err beside a PROGRAM of that stem
  OMITTED    a program a line of ALL.omit or a row of an EXCLUDED*.tsv names (declared out, with its measurement; not loose), and its streams
  TABLE      CONTRACT.tsv, CONTAINERS.tsv, EXCLUDED*.tsv, PARTITION.tsv, SOURCES.tsv, DRIVERS.tsv, or a .tsv at the root a script of harness/scripts names
  PART       a file ALL.launch names (the package's own driver around or under which each row runs; the grader 2026-11-11 on chat80's drive.pl);
             NAME.ecp beside a program or an omitted program of a package whose CONTRACT.tsv says units iso-rejection (the distribution's expected compiler
             listing, which the builder reads for the lines a rejection must name; the coo 2026-11-11 on pat); STEM.E.ref beside a program a row of PREPROCESS.tsv names (the preprocess-only contract's answer; the coo's ask of 2026-11-10 on jcon and
             arizona); NAME.ref.corrected for a name a row of ALL.corrected.tsv carries (the corrected answer the grader reads where the oracle errs;
             the coo 2026-11-10 on fpc_tests); a file CONTAINERS.tsv or CONTRACT.tsv names by its path or bare name, one ALL.args names as an argument, a member of a folder whose
             other files are all PARTs (a library shipped whole), or one whose bare file name a PROGRAM, an OMITTED program or another PART holds in its text, or an
             Icon file NAME.icn that one of those names in a link declaration (link NAME: a pack of the Icon library is one program of many files)
  DOCUMENT   README*, LICENSE*, COPYING*, NOTICE*, PROVENANCE*, *.md or *.txt at the package root; a root file one of those names by its bare name (the
             distribution's own script or note, accounted for by the package's own record); and every file under the root folder upstream/ when it holds a
             PROVENANCE.md: the distribution's own drop, kept whole as the record of what the vendoring changed (the cio 2026-11-10, on aisnobol)
  CONTAINER  ALL.<ext>, ALL.ref, ALL.in, ALL.argv, ALL.prelude: the form a converted package no longer has
  LOOSE      everything else
then PACKAGE_LAYOUT dir=DIR files=N index=N program=N stream=N part=N table=N document=N container=N omitted=N loose=N.
--list prints one line a file (role, a tab, the path); --check: rc 0 when container=0 and loose=0, else rc 1 with the first twenty CONTAINER and
LOOSE paths; --probe: a planted package holding one file of each role prints PACKAGE_LAYOUT_PROBE roles=9, rc 0 (rc 1 naming the file read
otherwise). rc 2 refused (no such directory, no ALL.csv). It reads; it writes nothing in the package and runs no program."""
import csv, fnmatch, os, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROLES = ("INDEX", "PROGRAM", "STREAM", "PART", "TABLE", "DOCUMENT", "CONTAINER", "OMITTED", "LOOSE")
INDEX = ("ALL.csv", "ALL.args", "ALL.omit", "ALL.mask", "ALL.rc", "ALL.source", "ALL.launch", "ALL.stdin")
TABLES = ("CONTRACT.tsv", "CONTAINERS.tsv", "PARTITION.tsv", "SOURCES.tsv", "DRIVERS.tsv")
CONTAINER_EXT = (".sno", ".icn", ".pl", ".raku", ".pas", ".sc", ".reb")
CONTAINER = ("ALL.ref", "ALL.in", "ALL.argv", "ALL.prelude") + tuple("ALL" + x for x in CONTAINER_EXT)
STREAMS = (".in", ".out", ".err")
DOCS = ("README*", "LICENSE*", "COPYING*", "NOTICE*", "PROVENANCE*", "_PROVENANCE*", "*.md", "*.txt")


def refuse(msg):
    print("REFUSE(2) [util_package_layout_census]: " + msg, file=sys.stderr)
    sys.exit(2)


def tracked(d):
    """Every file git tracks under D, as paths from D; every file on disk when D is in no repository."""
    p = subprocess.run(["git", "-C", d, "ls-files", "-z"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if p.returncode == 0:
        return sorted(x for x in p.stdout.decode("utf-8", "surrogateescape").split("\0") if x)
    out = []
    for root, dirs, names in os.walk(d):
        dirs[:] = [x for x in dirs if not x.startswith(".")]
        out += [os.path.relpath(os.path.join(root, n), d) for n in names]
    return sorted(out)


def omitted_names(d, files):
    names = set()
    p = os.path.join(d, "ALL.omit")
    if os.path.isfile(p):
        for ln in open(p, encoding="utf-8", errors="replace").read().split("\n"):
            if ln.strip() and not ln.startswith("#") and ": " in ln:
                names.add(ln.split(": ", 1)[0])
    for f in files:
        if "/" not in f and fnmatch.fnmatch(f, "EXCLUDED*.tsv"):
            for ln in open(os.path.join(d, f), encoding="utf-8", errors="replace").read().split("\n"):
                if ln.strip() and not ln.startswith("#"):
                    names.add(ln.split("\t", 1)[0].strip())
    return names


def script_names(name):
    p = subprocess.run(["grep", "-r", "-l", "-F", "-m", "1", "--", name, HERE], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return bool(p.stdout.strip())


def icon_linked(texts):
    """The names an Icon link declaration of TEXTS names (link a, b, c: each a file NAME.icn, written without its extension): a pack of the Icon
    program library is one program of many files, its main file linking the others (the grader 2026-11-11 on pack_tcll1, whose ten linked files
    read LOOSE because the rule above looks for a file's whole name)."""
    import re
    out = set()
    for m in re.finditer(r"(?m)^[ \t]*link[ \t]+([^\n#;]+)", texts):
        out.update(x.strip().strip('"') for x in m.group(1).split(",") if x.strip())
    return out


def text_of(d, f):
    try:
        return open(os.path.join(d, f), "rb").read().decode("utf-8", "replace")
    except OSError:
        return ""


def census(d):
    d = os.path.abspath(d)
    if not os.path.isdir(d):
        refuse("no directory %s" % d)
    if not os.path.isfile(os.path.join(d, "ALL.csv")):
        refuse("%s has no ALL.csv: it is no package" % d)
    files = tracked(d)
    role = {}
    with open(os.path.join(d, "ALL.csv"), newline="", encoding="utf-8") as fh:
        rdr = csv.DictReader(fh)
        rows = list(rdr)
        has_dialect = "dialect" in (rdr.fieldnames or [])
    omit = omitted_names(d, files)
    progs = {r.get("path") for r in rows if r.get("path") and r.get("entry") not in omit}
    out_progs = {r.get("path") for r in rows if r.get("path") and r.get("entry") in omit}
    stem = lambda f: os.path.splitext(f)[0]
    prog_stems, out_stems = {stem(f) for f in progs}, {stem(f) for f in out_progs}
    contained = set()
    if os.path.isfile(os.path.join(d, "CONTAINERS.tsv")):
        for ln in text_of(d, "CONTAINERS.tsv").split("\n"):
            if ln.strip() and not ln.startswith("#"):
                contained.update(c.strip() for c in ln.split("\t") if c.strip())
    contract = text_of(d, "CONTRACT.tsv") if os.path.isfile(os.path.join(d, "CONTRACT.tsv")) else ""
    pre = set()
    if os.path.isfile(os.path.join(d, "ALL.corrected.tsv")):
        for ln in text_of(d, "ALL.corrected.tsv").split("\n"):
            if ln.strip() and not ln.startswith("#"):
                pre.add(ln.split("\t", 1)[0].strip() + ".ref.corrected")
    if os.path.isfile(os.path.join(d, "PREPROCESS.tsv")):
        for ln in text_of(d, "PREPROCESS.tsv").split("\n"):
            if ln.strip() and not ln.startswith("#"):
                pre.add(os.path.splitext(ln.split("\t", 1)[0].strip())[0] + ".E.ref")
    upstream = "upstream/PROVENANCE.md" in files
    iso_rej = any(ln.split("\t")[:2] == ["units", "iso-rejection"] for ln in contract.split("\n"))
    argd = set()
    if os.path.isfile(os.path.join(d, "ALL.args")):
        for ln in text_of(d, "ALL.args").split("\n"):
            if ln.strip() and not ln.startswith("#"):
                argd.update(ln.split("\t")[1:])
    launched = set()
    if os.path.isfile(os.path.join(d, "ALL.launch")):
        for ln in text_of(d, "ALL.launch").split("\n"):
            if ln.strip() and not ln.startswith("#"):
                launched.update(ln.split())
    for f in files:
        base, top = os.path.basename(f), "/" not in f
        ext = os.path.splitext(f)[1]
        if top and base in INDEX:
            role[f] = "INDEX"
        elif f in launched and f not in progs:
            role[f] = "PART"
        elif top and base == "ALL.dialect":
            role[f] = "LOOSE" if has_dialect else "INDEX"
        elif top and base in CONTAINER:
            role[f] = "CONTAINER"
        elif f in progs:
            role[f] = "PROGRAM"
        elif ext in STREAMS and stem(f) in prog_stems:
            role[f] = "STREAM"
        elif f in out_progs or (ext in STREAMS and stem(f) in out_stems):
            role[f] = "OMITTED"
        elif top and (base in TABLES or fnmatch.fnmatch(base, "EXCLUDED*.tsv")):
            role[f] = "TABLE"
        elif f in omit or stem(f) in omit or base in omit or (ext not in STREAMS and ext != ".ref" and stem(base) in omit):
            role[f] = "OMITTED"
        elif f in pre:
            role[f] = "PART"
        elif iso_rej and ext == ".ecp" and (stem(f) in prog_stems or stem(f) in out_stems):
            role[f] = "PART"
        elif upstream and f.startswith("upstream/"):
            role[f] = "DOCUMENT"
        elif f in contained or base in contained or f in argd or (contract and ext not in STREAMS + (".ref",) and base in contract) or (contract and ext in STREAMS and stem(f) not in prog_stems and base in contract):
            role[f] = "PART"
        elif top and ext == ".tsv" and script_names(base):
            role[f] = "TABLE"
        elif top and any(fnmatch.fnmatch(base, g) for g in DOCS):
            role[f] = "DOCUMENT"
    rest = [f for f in files if f not in role]
    readers = [f for f in files if role.get(f) in ("PROGRAM", "OMITTED", "PART")]
    texts = "\n".join(text_of(d, f) for f in readers)
    while rest:
        linked = icon_linked(texts)
        found = [f for f in rest if os.path.splitext(f)[1] not in STREAMS + (".ref",) and (os.path.basename(f) in texts or (os.path.splitext(f)[1] == ".icn" and os.path.splitext(os.path.basename(f))[0] in linked))]
        if not found:
            break
        for f in found:
            role[f] = "PART"
        texts += "\n" + "\n".join(text_of(d, f) for f in found)
        rest = [f for f in rest if f not in role]
    docs = "\n".join(text_of(d, f) for f in files if role.get(f) == "DOCUMENT" and "/" not in f)
    for f in list(rest):
        if "/" not in f and len(f) > 3 and f in docs:
            role[f] = "DOCUMENT"
    rest = [f for f in rest if f not in role]
    low = texts.lower()
    for f in list(rest):
        folder = os.path.dirname(f)
        mates = [g for g in files if os.path.dirname(g) == folder and g != f and g not in rest]
        if os.path.splitext(f)[1] not in STREAMS + (".ref",) and (os.path.basename(f).lower() in low or (folder and mates and all(role.get(g) == "PART" for g in mates))):
            role[f] = "PART"
    rest = [f for f in rest if f not in role]
    for f in rest:
        role[f] = "LOOSE"
    return d, files, role


def report(d, files, role, list_all, check):
    if list_all:
        for f in files:
            print("%s\t%s" % (role[f], f))
    n = {r: sum(1 for f in files if role[f] == r) for r in ROLES}
    print("PACKAGE_LAYOUT dir=%s files=%d index=%d program=%d stream=%d part=%d table=%d document=%d container=%d omitted=%d loose=%d" % (
        d, len(files), n["INDEX"], n["PROGRAM"], n["STREAM"], n["PART"], n["TABLE"], n["DOCUMENT"], n["CONTAINER"], n["OMITTED"], n["LOOSE"]))
    if not check:
        return 0
    bad = [f for f in files if role[f] in ("CONTAINER", "LOOSE")]
    for f in bad[:20]:
        print("  %s\t%s" % (role[f], f))
    return 1 if bad else 0


def probe():
    t = tempfile.mkdtemp(prefix="pkg_layout_probe_", dir=os.environ.get("TMPDIR") or None)
    try:
        d = os.path.join(t, "probe_pkg")
        os.makedirs(os.path.join(d, "sub"))
        plant = {
            "ALL.csv": ("INDEX", "rank,entry,path,origin\n1,sub/run,sub/run.sno,probe\n2,gone,gone.sno,probe\n"),
            "ALL.omit": ("INDEX", "gone: the oracle refuses it\n"),
            "ALL.dialect": ("INDEX", "sub/run\tiso\n"),
            "ALL.source": ("INDEX", "root\t/nowhere\norigin\tprobe\nversion\tprobe\nlicence\tpublic domain\n"),
            "ALL.launch": ("INDEX", "scrip around - drive.sno\n"),
            "drive.sno": ("PART", "* the package's own driver, named by ALL.launch\nEND\n"),
            "sub/run.sno": ("PROGRAM", "-INCLUDE 'lib.inc'\n OUTPUT = 'x'\nEND\n"),
            "sub/run.out": ("STREAM", "x\n"),
            "gone.sno": ("OMITTED", "END\n"),
            "PARTITION.tsv": ("TABLE", "# cells\n"),
            "lib.inc": ("PART", "* a library\n"),
            "ALL.corrected.tsv": ("TABLE", "sub/run\tthe oracle errs\n"),
            "sub/run.ref.corrected": ("PART", "y\n"),
            "README.md": ("DOCUMENT", "a planted package\n"),
            "ALL.ref": ("CONTAINER", ""),
            "stray.bak": ("LOOSE", "left behind\n"),
        }
        for f, (r, body) in plant.items():
            open(os.path.join(d, f), "w").write(body)
        d2, files, role = census(d)
        wrong = ["%s read %s, planted %s" % (f, role.get(f), r) for f, (r, body) in plant.items() if role.get(f) != r]
        seen = len({role[f] for f in files})
        d3 = os.path.join(t, "probe_pkg_dialect_column")
        os.makedirs(d3)
        open(os.path.join(d3, "ALL.csv"), "w").write("rank,entry,path,dialect\n1,run,run.sno,\n")
        open(os.path.join(d3, "run.sno"), "w").write(" OUTPUT = 'x'\nEND\n")
        open(os.path.join(d3, "ALL.dialect"), "w").write("run\tiso\n")
        r3 = census(d3)[2].get("ALL.dialect")
        if r3 != "LOOSE":
            wrong.append("ALL.dialect beside an index with a dialect column read %s, wanted LOOSE" % r3)
        d4 = os.path.join(t, "probe_pkg_iso_rejection")
        os.makedirs(d4)
        open(os.path.join(d4, "ALL.csv"), "w").write("rank,entry,path\n1,rej,rej.pas\n")
        open(os.path.join(d4, "rej.pas"), "w").write("program rej; begin end.\n")
        open(os.path.join(d4, "rej.ecp"), "w").write("the distribution's listing\n")
        open(os.path.join(d4, "CONTRACT.tsv"), "w").write("units\tiso-rejection\tplanted\n")
        r4 = census(d4)[2].get("rej.ecp")
        if r4 != "PART":
            wrong.append("rej.ecp beside a program of an iso-rejection package read %s, wanted PART" % r4)
        print("PACKAGE_LAYOUT_PROBE roles=%d" % seen)
        for w in wrong:
            print("  " + w)
        return 0 if not wrong and seen == len(ROLES) else 1
    finally:
        shutil.rmtree(t, ignore_errors=True)


def main(a):
    if "--probe" in a:
        return probe()
    if "--package" not in a or a.index("--package") + 1 >= len(a):
        refuse("usage: util_package_layout_census.py --package DIR [--check] [--list] | --probe")
    d, files, role = census(a[a.index("--package") + 1])
    return report(d, files, role, "--list" in a, "--check" in a)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

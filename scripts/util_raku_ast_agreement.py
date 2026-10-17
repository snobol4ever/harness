#!/usr/bin/env python3
"""util_raku_ast_agreement.py -- does the new Raku parser build the tree the flex/bison parser builds?

THE INSTRUMENT of row raku-the-new-parser-builds-the-tree-its-dump-ast-byte-identical-to-the-flex-bison-parsers-
dump-on-every-master-entry-and-kernel-then-the-old-parser-is-deleted (Lon 2026-09-26 16:0x CDT, ceo CEO-1289:
"Then add the tree building code from the current parsers --dump-ast output."). Entry point:
../harness/scripts/util_raku_ast_agreement.sh, which the row's DONE-WHEN runs.

THE POPULATION, every unit named by a durable key:
    rungs:<entry>     every entry of corpus/tests/raku/ALL.raku, extracted alone through corpus_suite_harness.py's
                       own suite readers (the same extraction util_raku_syntax_agreement.py uses)
    bench:<file>       every *.raku kernel under corpus/benchmarks/raku

THE REFERENCE is the flex/bison parser's own `scrip --dump-ast` output, cut ONCE by `--cut` before the parser swap:
    corpus/tests/raku/ALL.ast            one banner per rungs entry, `#-- <key>` then `#rc <n>` then the dump
    corpus/benchmarks/raku/<stem>.ast    one file per kernel, `#rc <n>` then the dump
each file headed by the SCRIP commit that cut it. `--cut` REFUSES rc=2 once src/parsers/raku/raku.y is gone:
the reference is the old parser's tree, and nothing else may write it.

THE SUBJECT is `scrip <flag> FILE` (default flag --dump-ast, which is the new parser once it is swapped in;
`--flag` names another while both parsers are in the tree). Its stdout and rc must match the reference byte
for byte. A unit whose difference is the OLD parser's defect is listed in corpus/tests/raku/ALL.ast.exceptions.tsv
(key, the md5 of the subject's dump that is accepted instead, the measured reason): it counts as EXCEPTED only
while the subject's dump still has that md5 -- an exception is a pinned answer, never a blanket pass.

OUTPUT: one line
    RAKU_AST_AGREEMENT population=N identical=I excepted=E differ=D     (I + E + D = N, else REFUSED rc=2)
then every differing unit by key (--show adds a unified diff of each, first 12 lines). rc 0 when D == 0, 1 when
D > 0, 2 when it could not measure.
"""
import argparse, concurrent.futures, difflib, hashlib, os, subprocess, sys, tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIP_DIR = (HERE.parent.parent / "SCRIP")
HOME = Path(os.environ.get("S4E_HOME", SCRIP_DIR.parent))
CORPUS = HOME / "corpus"
RUNGS = CORPUS / "tests" / "raku" / "ALL.raku"
RUNGS_REF = CORPUS / "tests" / "raku" / "ALL.ref"
RUNGS_AST = CORPUS / "tests" / "raku" / "ALL.ast"
EXCEPTIONS = CORPUS / "tests" / "raku" / "ALL.ast.exceptions.tsv"
BENCH = CORPUS / "benchmarks" / "raku"
SCRIP = SCRIP_DIR / "scrip"
OLD_PARSER = SCRIP_DIR / "src" / "parsers" / "raku" / "raku.y"


def refuse(msg):
    print(f"⛔ REFUSE(rc=2) [util_raku_ast_agreement]: {msg}", file=sys.stderr)
    raise SystemExit(2)


def rungs_units(workdir):
    sys.path.insert(0, str(HERE))
    import corpus_suite_harness as h
    try:
        entries = h.read_block_suite(str(RUNGS), str(RUNGS_REF), h.banner_re_for("#", ""))
    except Exception:
        entries = h.read_suite(str(RUNGS), str(RUNGS_REF))
    out = []
    for e in entries:
        text = (e.sno_lines[0] if e.kind == "line" else "\n".join(e.sno_lines)) + "\n"
        p = workdir / f"{e.name}.raku"
        p.write_text(text)
        out.append((f"rungs:{e.name}", p))
    return out


def population(workdir):
    return rungs_units(workdir) + [(f"bench:{p.name}", p) for p in sorted(BENCH.glob("*.raku"))]


def dump(flag, path, timeout):
    try:
        r = subprocess.run([str(SCRIP), flag, str(path)], stdin=subprocess.DEVNULL, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return "timeout", b""
    return str(r.returncode), r.stdout


def scrip_commit():
    r = subprocess.run(["git", "-C", str(SCRIP_DIR), "log", "-1", "--format=%h"], capture_output=True, text=True)
    dirty = subprocess.run(["git", "-C", str(SCRIP_DIR), "status", "--porcelain", "--untracked-files=no"], capture_output=True, text=True)
    return r.stdout.strip() + ("-dirty" if dirty.stdout.strip() else "")


def run_all(units, flag, jobs, timeout):
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as ex:
        futs = {ex.submit(dump, flag, p, timeout): k for k, p in units}
        return {futs[f]: f.result() for f in concurrent.futures.as_completed(futs)}


def cut(units, jobs, timeout):
    if not OLD_PARSER.is_file():
        refuse(f"{OLD_PARSER} is gone -- the reference is the flex/bison parser's tree and only it may cut one")
    commit = scrip_commit()
    if commit.endswith("-dirty"):
        refuse("SCRIP has uncommitted changes -- a reference must name a tree someone else can check out")
    got = run_all(units, "--dump-ast", jobs, timeout)
    head = f"# cut by ../harness/scripts/util_raku_ast_agreement.py --cut from SCRIP {commit}: the flex/bison parser's `scrip --dump-ast`\n"
    with open(RUNGS_AST, "wb") as f:
        f.write(("# ALL.ast -- the reference Raku AST of every entry of ALL.raku (row raku-the-new-parser-builds-the-tree, CEO-1289)\n" + head).encode())
        for k, _ in units:
            if not k.startswith("rungs:"):
                continue
            rc, out = got[k]
            f.write(f"#-- {k}\n#rc {rc}\n".encode() + out + (b"" if out.endswith(b"\n") or not out else b"\n"))
    nb = 0
    for k, p in units:
        if not k.startswith("bench:"):
            continue
        rc, out = got[k]
        (BENCH / (p.stem + ".ast")).write_bytes(head.encode() + f"#rc {rc}\n".encode() + out)
        nb += 1
    nm = sum(1 for k, _ in units if k.startswith("rungs:"))
    print(f"RAKU_AST_REFERENCE cut from SCRIP {commit}: rungs={nm} -> {RUNGS_AST}  bench={nb} -> {BENCH}/*.ast")


def read_reference(units):
    if not RUNGS_AST.is_file():
        refuse(f"no reference at {RUNGS_AST} -- cut it first with --cut, on a tree that still has the old parser")
    ref, cur, buf = {}, None, []
    for line in RUNGS_AST.read_bytes().split(b"\n"):
        if line.startswith(b"#-- "):
            if cur:
                ref[cur] = buf
            cur, buf = line[4:].decode(), []
        elif cur is not None:
            buf.append(line)
    if cur:
        ref[cur] = buf
    out = {}
    for k, lines in ref.items():
        rc = lines[0][4:].decode() if lines and lines[0].startswith(b"#rc ") else "?"
        body = b"\n".join(lines[1:]).rstrip(b"\n")
        out[k] = (rc, body + b"\n" if body else b"")
    for k, p in units:
        if k.startswith("bench:"):
            a = BENCH / (p.stem + ".ast")
            if not a.is_file():
                continue
            ls = a.read_bytes().split(b"\n")
            while ls and ls[0].startswith(b"# "):
                ls.pop(0)
            rc = ls[0][4:].decode() if ls and ls[0].startswith(b"#rc ") else "?"
            out[k] = (rc, b"\n".join(ls[1:]))
    return out


def read_exceptions():
    ex = {}
    if EXCEPTIONS.is_file():
        for line in EXCEPTIONS.read_text().splitlines():
            if line.startswith("#") or not line.strip():
                continue
            f = line.split("\t")
            if len(f) >= 3:
                ex[f[0]] = f[1]
    return ex


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--cut", action="store_true", help="cut the reference from the flex/bison parser (refuses once it is gone)")
    ap.add_argument("--flag", default="--dump-ast", help="the subject's dump flag (default --dump-ast)")
    ap.add_argument("--show", action="store_true", help="print a short diff of every differing unit")
    ap.add_argument("--jobs", type=int, default=8)
    ap.add_argument("--timeout", type=int, default=30)
    a = ap.parse_args()
    if not SCRIP.is_file():
        refuse(f"no scrip at {SCRIP}")
    with tempfile.TemporaryDirectory(prefix="rk_ast_") as td:
        units = population(Path(td))
        if not units:
            refuse("the population is empty")
        if a.cut:
            cut(units, a.jobs, a.timeout)
            return 0
        ref = read_reference(units)
        missing = [k for k, _ in units if k not in ref]
        if missing:
            refuse(f"{len(missing)} unit(s) have no reference (first: {missing[0]}) -- the population moved since the cut; re-cut on a tree with the old parser")
        got = run_all(units, a.flag, a.jobs, a.timeout)
    exc = read_exceptions()
    ident, excepted, differ = 0, 0, []
    for k, _ in units:
        rrc, rbody = ref[k]
        grc, gbody = got[k]
        if grc == rrc and gbody.rstrip(b"\n") == rbody.rstrip(b"\n"):
            ident += 1
        elif k in exc and hashlib.md5(gbody).hexdigest() == exc[k]:
            excepted += 1
        else:
            differ.append((k, rrc, rbody, grc, gbody))
    n = len(units)
    if ident + excepted + len(differ) != n:
        refuse(f"identity does not close: {ident}+{excepted}+{len(differ)} != {n}")
    print(f"RAKU_AST_AGREEMENT population={n} identical={ident} excepted={excepted} differ={len(differ)}")
    for k, rrc, rbody, grc, gbody in differ:
        print(f"  DIFFER {k}  (reference rc {rrc}, subject rc {grc})")
        if a.show:
            d = difflib.unified_diff(rbody.decode(errors="replace").splitlines(), gbody.decode(errors="replace").splitlines(), "reference", "subject", lineterm="", n=1)
            for line in list(d)[:12]:
                print("      " + line)
    return 0 if not differ else 1


if __name__ == "__main__":
    sys.exit(main())

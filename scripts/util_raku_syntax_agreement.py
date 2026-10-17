#!/usr/bin/env python3
"""util_raku_syntax_agreement.py -- does `scrip --syntax` accept exactly what Rakudo's `raku -c` accepts?

THE INSTRUMENT of row raku-a-new-hand-written-lexer-and-parser-syntax-checking-first-no-trees-agreeing-with-
raku-dash-c-on-every-master-entry-benchmark-kernel-and-roast-file-lon-2026-09-26 (Lon 2026-09-26 16:0x CDT, ceo
CEO-1289: "Get a new lexer/parser for Raku before doing the benchmarks. Just get the syntax checking first and
produce no trees.").

THE POPULATION, three parts, every unit named by a durable key:
    rungs:<entry>     every entry of corpus/tests/raku/ALL.raku, extracted alone (a rung suite is a CONTAINER of
                       programs, never one program) through corpus_suite_harness.py's own suite readers
    bench:<file>       every *.raku kernel under corpus/benchmarks/raku
    roast:<relpath>    every *.t file under the roast checkout (/home/resources/roast-master)

THE ORACLE is Rakudo's syntax check, `raku -c FILE` (v2022.12 on the box), run with the file at its own path so
a roast file's `use lib $*PROGRAM.parent(2).add(...)` resolves. Its verdict per unit is CACHED in
corpus/tests/raku/config/RAKUDO-SYNTAX-VERDICTS.tsv, keyed by the unit's key and the md5 of its text: a unit
whose text changed is re-cut automatically, `--recut` re-cuts all. Verdicts: accept (rc 0), reject (rc != 0,
with Rakudo's first error line kept as the class), timeout (the oracle did not answer: UNGRADABLE, named).

THE SUBJECT is `scrip --syntax FILE`: rc 0 accept, rc 1 reject; any other rc, or a timeout, is its own class.
A scrip that cannot syntax-check (the probe `say 1;` is not accepted with rc 0) REFUSES rc=2 -- a checker that
cannot measure never prints the success shape. `--oracle-only` cuts the cache and prints Rakudo's census alone.

OUTPUT: one line
    RAKU_SYNTAX_AGREEMENT population=N agree=A disagree=D ungradable=U   (A + D + U = N, else REFUSED rc=2)
then every disagreement by key and class. rc 0 when D == 0, 1 when D > 0, 2 when it could not measure.
"""
import argparse, concurrent.futures, csv, hashlib, os, subprocess, sys, tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIP_DIR = (HERE.parent.parent / "SCRIP")
HOME = Path(os.environ.get("S4E_HOME", SCRIP_DIR.parent))
CORPUS = HOME / "corpus"
RUNGS = CORPUS / "tests" / "raku" / "ALL.raku"
RUNGS_REF = CORPUS / "tests" / "raku" / "ALL.ref"
BENCH = CORPUS / "benchmarks" / "raku"
ROAST = Path(os.environ.get("RAKU_ROAST_DIR", "/home/resources/roast-master"))
CACHE = CORPUS / "tests" / "raku" / "config" / "RAKUDO-SYNTAX-VERDICTS.tsv"
RAKU = os.environ.get("RAKU_BIN", "/usr/bin/raku")
SCRIP = SCRIP_DIR / "scrip"
FIELDS = ["key", "md5", "verdict", "rc", "first_error"]


def refuse(msg):
    print(f"⛔ REFUSE(rc=2) [util_raku_syntax_agreement]: {msg}", file=sys.stderr)
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
    units = rungs_units(workdir)
    units += [(f"bench:{p.name}", p) for p in sorted(BENCH.glob("*.raku"))]
    units += [(f"roast:{p.relative_to(ROAST)}", p) for p in sorted(ROAST.rglob("*.t"))]
    return units


def md5_of(path):
    return hashlib.md5(path.read_bytes()).hexdigest()


def first_error(text):
    for line in text.splitlines():
        s = line.replace("\x1b[31m", "").replace("\x1b[0m", "").replace("\x1b[32m", "").replace("\x1b[33m", "").strip()
        if s and "SORRY" not in s and not s.startswith("------>") and not s.startswith("at "):
            return s.replace("\t", " ")[:200]
    return ""


def oracle_verdict(path, timeout):
    try:
        r = subprocess.run([RAKU, "-c", path.name], cwd=path.parent, stdin=subprocess.DEVNULL,
                           capture_output=True, text=True, errors="replace", timeout=timeout)
    except subprocess.TimeoutExpired:
        return "timeout", "", "raku -c did not answer"
    if r.returncode == 0:
        return "accept", "0", ""
    return "reject", str(r.returncode), first_error(r.stderr + r.stdout)


def scrip_verdict(path, timeout):
    try:
        r = subprocess.run([str(SCRIP), "--syntax", str(path)], stdin=subprocess.DEVNULL,
                           capture_output=True, text=True, errors="replace", timeout=timeout)
    except subprocess.TimeoutExpired:
        return "timeout", ""
    if r.returncode == 0:
        return "accept", ""
    if r.returncode == 1:
        return "reject", first_error(r.stderr + r.stdout)
    return f"rc{r.returncode}", first_error(r.stderr + r.stdout)


def load_cache():
    if not CACHE.is_file():
        return {}
    with open(CACHE, encoding="utf-8") as f:
        return {row["key"]: row for row in csv.DictReader((l for l in f if not l.startswith("#")), delimiter="\t")}


def save_cache(rows):
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    tmp = CACHE.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8", newline="") as f:
        f.write(f"# Rakudo's own syntax verdict (`raku -c`, {RAKU}) per unit of the Raku syntax-agreement population;\n")
        f.write("# written by harness/scripts/util_raku_syntax_agreement.py -- a unit is re-cut when its md5 changes, all on --recut\n")
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        for k in sorted(rows):
            w.writerow({x: rows[k].get(x, "") for x in FIELDS})
    tmp.replace(CACHE)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--recut", action="store_true", help="re-run raku -c over every unit, ignoring the cache")
    ap.add_argument("--oracle-only", action="store_true", help="cut or refresh the cache and print Rakudo's census; grade nothing")
    ap.add_argument("--jobs", type=int, default=max(1, min(8, (os.cpu_count() or 2) // 2)))
    ap.add_argument("--oracle-timeout", type=int, default=120)
    ap.add_argument("--scrip-timeout", type=int, default=20)
    ap.add_argument("--show", action="store_true", help="under each disagreement, print the source line scrip's error names, with a caret at its column")
    ap.add_argument("--only", default="", help="grade only units whose key starts with this prefix (rungs: bench: roast:); a partial run prints PARTIAL")
    a = ap.parse_args()
    if not Path(RAKU).is_file():
        refuse(f"the oracle {RAKU} is not on the box")
    for need in (RUNGS, RUNGS_REF, BENCH, ROAST):
        if not need.exists():
            refuse(f"population part missing: {need}")
    with tempfile.TemporaryDirectory(prefix="rk_syntax_") as td:
        units = population(Path(td))
        if a.only:
            units = [u for u in units if u[0].startswith(a.only)]
        if not units:
            refuse("the population is empty")
        cache = load_cache()
        sums = {k: md5_of(p) for k, p in units}
        stale = [(k, p) for k, p in units if a.recut or k not in cache or cache[k].get("md5") != sums[k]]
        if stale:
            print(f"ORACLE: cutting {len(stale)} of {len(units)} verdict(s) with {RAKU} -c ({a.jobs} jobs)", file=sys.stderr)
            with concurrent.futures.ThreadPoolExecutor(a.jobs) as ex:
                futs = {ex.submit(oracle_verdict, p, a.oracle_timeout): k for k, p in stale}
                for n, fu in enumerate(concurrent.futures.as_completed(futs), 1):
                    k = futs[fu]
                    v, rc, err = fu.result()
                    cache[k] = {"key": k, "md5": sums[k], "verdict": v, "rc": rc, "first_error": err}
                    if n % 200 == 0:
                        print(f"  ... {n}/{len(stale)}", file=sys.stderr)
            if not a.only:
                live = {k for k, _ in units}
                cache = {k: v for k, v in cache.items() if k in live}
            save_cache(cache)
        if a.oracle_only:
            tally = {}
            for k, _ in units:
                part = k.split(":", 1)[0]
                tally.setdefault(part, {}).setdefault(cache[k]["verdict"], 0)
                tally[part][cache[k]["verdict"]] += 1
            for part in sorted(tally):
                print(f"RAKUDO_SYNTAX_CENSUS part={part} " + " ".join(f"{v}={n}" for v, n in sorted(tally[part].items())))
            return 0
        probe = Path(td) / "probe.raku"
        probe.write_text("say 1;\n")
        pv, _ = scrip_verdict(probe, a.scrip_timeout)
        if pv != "accept":
            refuse(f"{SCRIP} --syntax does not accept the probe `say 1;` (verdict {pv}) -- there is no syntax checker to grade")
        agree = 0; ungradable = []; disagree = []
        with concurrent.futures.ThreadPoolExecutor(a.jobs) as ex:
            futs = {ex.submit(scrip_verdict, p, a.scrip_timeout): k for k, p in units if cache[k]["verdict"] != "timeout"}
            for k, _ in units:
                if cache[k]["verdict"] == "timeout":
                    ungradable.append(k)
            for fu in concurrent.futures.as_completed(futs):
                k = futs[fu]
                sv, serr = fu.result()
                ov = cache[k]["verdict"]
                if sv == ov:
                    agree += 1
                elif sv in ("accept", "reject"):
                    disagree.append((k, f"RAKUDO_{ov.upper()}S_SCRIP_{sv.upper()}S", serr or cache[k]["first_error"]))
                else:
                    disagree.append((k, f"SCRIP_{sv.upper()}", serr))
        n = len(units); d = len(disagree); u = len(ungradable)
        if agree + d + u != n:
            refuse(f"the identity does not close: agree={agree} + disagree={d} + ungradable={u} != population={n}")
        print(f"RAKU_SYNTAX_AGREEMENT population={n} agree={agree} disagree={d} ungradable={u}" + (f" PARTIAL(--only {a.only})" if a.only else ""))
        for k in sorted(ungradable):
            print(f"  UNGRADABLE {k}  (raku -c gave no verdict in {a.oracle_timeout}s)")
        paths = dict(units)
        for k, cls, err in sorted(disagree, key=lambda t: (t[1], t[0])):
            print(f"  {cls:34s} {k}  {err}")
            if a.show:
                import re
                m = re.search(r":(\d+):(\d+): raku syntax error", err or "")
                if m:
                    ln, col = int(m.group(1)), int(m.group(2))
                    try:
                        lines = paths[k].read_text(errors="replace").splitlines()
                        src = lines[ln - 1] if 0 < ln <= len(lines) else ""
                        print(f"      | {src[:160]}")
                        print(f"      | {' ' * max(0, col - 1)}^")
                    except OSError:
                        pass
        return 1 if d else 0


if __name__ == "__main__":
    sys.exit(main())

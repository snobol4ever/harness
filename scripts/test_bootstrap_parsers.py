#!/usr/bin/env python3
"""test_bootstrap_parsers.py -- grade the self-hosted parsers SCRIP/bootstrap/parser_<lang>.sc over EVERY corpus
source of their language, in any of five arms, and print the denominator with every non-parse NAMED.

Lon 2026-09-23 15:2x CDT, in-chat to hq_snocone, verbatim: "Get each parser_*.sc working starting with the easiest.
First get parser_*.sno working. Then use those working SNO to get the SC ones working. Test the parsers using all the
corpus sources." -- and, relayed by the ceo (CEO-1212): "All of the parser_*.sno programs worked at 100% in the past."
The parser_<lang>.sno is the `scrip --transpile` of the 14-file bootstrap runtime chain plus parser_<lang>.sc
(GOAL-PARSER-SC-TRANSPILE.md), so SPITBOL -- a SNOBOL4 we did not write -- can run a parser we did.

THE FIVE ARMS (one per run; --arm):
  sbl  parser_<lang>.sno on SPITBOL (sbl -bf)                    -- a parser bug, never a SCRIP bug
  m3   parser_<lang>.sno on SCRIP --run      (SNOBOL4 frontend)  -- SCRIP's SNOBOL4 against the sbl arm
  m4   parser_<lang>.sno on SCRIP --compile  (SNOBOL4 frontend)
  sc3  the .sc chain concatenated, on SCRIP --run   (Snocone frontend) -- the thing Lon asked for
  sc4  the .sc chain concatenated, on SCRIP --compile
  ⛔ The .sc chain is loaded by CONCATENATION because a .sc program cannot load a library chain (no -INCLUDE for
  Snocone; scrip takes the first positional as the program and the rest as ITS arguments).

THE POPULATION (--list prints it): every corpus file carrying one of the language's source extensions, rung_suites
excluded, PLUS every entry of the language's rungs tests/<lang>/ALL.<ext>, materialized through the suite
harness's own readers (never a second parser of the suite grammar).

CLASSES, strict: PARSED = no "Parse Error", no runtime error, rc 0 and at least one output line; REFUSED = the
parser printed "Parse Error"; CRASH = any runtime error or non-zero rc (SPITBOL exits 0 on an ERROR, so its
text is read, never its rc); TIMEOUT; EMPTY = clean exit that printed nothing (kept apart, never counted PARSED).
Exit: 0 when every member PARSED, 1 when any did not, 2 when it could not measure (no binary, no oracle, a
transpile that failed, an empty population) -- a runner that cannot measure never prints the success shape.
"""
import argparse, concurrent.futures, os, re, shutil, subprocess, sys, time
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIP_DIR = (HERE.parent.parent / "SCRIP")
ROOT = Path(os.environ.get("S4E_HOME") or SCRIP_DIR.parent)
CORPUS = ROOT / "corpus"
BOOT = SCRIP_DIR / "bootstrap"
SCRIP = Path(os.environ.get("SCRIP") or SCRIP_DIR / "scrip")
RTLIB = SCRIP_DIR / "out"
SBL = Path(os.environ.get("SBL") or "/home/resources/x64/bin/sbl")
RUNTIME = ["global", "case", "assign", "match", "counter", "stack", "tree", "ShiftReduce",
           "tdump", "gen", "qize", "semantic", "omega", "trace"]
LANGS = {
    "snobol4": {"exts": [".sno", ".SNO", ".inc", ".INC", ".sbl", ".spt", ".SPT"], "rungs": "ALL.sno", "harness_lang": ""},
    "snocone": {"exts": [".sc"], "rungs": "ALL.sc", "harness_lang": "snocone"},
    "rebus":   {"exts": [".reb"], "rungs": "ALL.reb", "harness_lang": "rebus"},
    "icon":    {"exts": [".icn"], "rungs": "ALL.icn", "harness_lang": "icon"},
    "prolog":  {"exts": [".pl", ".P", ".pro"], "rungs": "ALL.pl", "harness_lang": "prolog"},
    "raku":    {"exts": [".raku", ".rakumod"], "rungs": "ALL.raku", "harness_lang": "raku"},
    "pascal":  {"exts": [".pas", ".pp"], "rungs": "ALL.pas", "harness_lang": "pascal"},
}
SPITBOL_ERR = re.compile(r"\bERROR \d+ --")
# SPITBOL's default stack (-s4m) is too small for a recursive grammar on a 1000-line source (ERROR 246 on beauty.sc and
# beauty_modules.sc, both clean at -s16m). HUGE HEAP AND HUGE STACK, ALWAYS (Lon 2026-09-26, in-chat to hq_snocone, verbatim: "You
# should run with huge heap and huge stack always to avoid limits."). Both engines' sizes are the CHAIN's declaration, never typed
# here (ceo CEO-1353, RULES.md clause 8 (g)(3)-(4)): bootstrap/parser_<lang>.heap and .stack for scrip, bootstrap/parser_<lang>.oracle_args
# for sbl, read through corpus_suite_harness -- the one reader -- and printed on the board line.
sys.path.insert(0, str(HERE))
import corpus_suite_harness as _harness


def scrip_arena(lang):
    """scrip's -d/-s switches for the chain of `lang`, from bootstrap/parser_<lang>.heap and .stack; refuses an undeclared chain."""
    drv = BOOT / f"parser_{lang}.sc"
    heap, _ = _harness.heap_declarations(str(drv))
    stack, _ = _harness.stack_declarations(str(drv))
    sw = _harness._size_switches(heap.get(drv.stem), stack.get(drv.stem))
    if not sw:
        refuse(f"{drv} declares no heap or stack (bootstrap/parser_{lang}.heap, .stack) -- the chain's sizes are its declaration")
    return sw


def sbl_args(lang):
    """sbl's size switches for the chain of `lang`, from bootstrap/parser_<lang>.oracle_args; [] runs the oracle at its defaults."""
    return _harness.oracle_args_declarations(str(BOOT / f"parser_{lang}.sc"))
SCRIP_ERR = re.compile(r"^(?:\S+:\d+: )?(?:Error \d+|error:|FATAL|scrip: )", re.M)


def refuse(msg):
    print(f"⛔ REFUSE(2): {msg}", file=sys.stderr)
    raise SystemExit(2)


def git_head(repo):
    try:
        return subprocess.run(["git", "-C", str(repo), "rev-parse", "--short=9", "HEAD"], capture_output=True, text=True).stdout.strip() or "?"
    except OSError:
        return "?"


def rungs_entries(lang, work):
    """Materialize every entry of the language's rungs into work/pop/<lang>/ through the suite harness's own
    readers. Returns [(name, path)]."""
    cfg = LANGS[lang]
    src = CORPUS / "tests" / lang / cfg["rungs"]
    ref = src.with_suffix(".ref")
    if not src.is_file() or not ref.is_file():
        return []
    sys.path.insert(0, str(HERE))
    import corpus_suite_harness as h
    if cfg["harness_lang"]:
        lc = h.LANG_CONFIGS[cfg["harness_lang"]]
        entries = h.read_block_suite(str(src), str(ref), h.banner_re_for(lc["comment_open"], lc["comment_close"]))
    else:
        entries = h.read_suite(str(src), str(ref))
    out_dir = work / "pop" / lang
    out_dir.mkdir(parents=True, exist_ok=True)
    ext = src.suffix
    res = []
    for e in entries:
        text = e.sno_lines[0] if e.kind == "line" else "\n".join(e.sno_lines)
        p = out_dir / f"{e.name}{ext}"
        p.write_text(text + "\n")
        res.append((f"rungs:{e.name}", p))
    return res


def corpus_files(lang):
    exts = set(LANGS[lang]["exts"])
    res = []
    for p in sorted(CORPUS.rglob("*")):
        if ".git" in p.parts or not p.is_file() or p.suffix not in exts:
            continue
        if p.name.startswith("ALL.") and p.parent == CORPUS / "tests" / lang:
            continue
        res.append((str(p.relative_to(CORPUS)), p))
    return res


def build_arm(lang, arm, work):
    """Prepare the program the arm runs. Returns (argv_prefix, cwd)."""
    d = work / lang
    d.mkdir(parents=True, exist_ok=True)
    chain = [BOOT / f"{m}.sc" for m in RUNTIME]
    helpers = BOOT / f"{lang}_helpers.sc"
    if helpers.is_file():
        chain.append(helpers)
    chain.append(BOOT / f"parser_{lang}.sc")
    missing = [str(p) for p in chain if not p.is_file()]
    if missing:
        refuse(f"chain file(s) missing: {', '.join(missing)}")
    if not SCRIP.is_file():
        refuse(f"no scrip binary at {SCRIP} -- run make")
    if arm in ("sbl", "m3", "m4"):
        sno = d / f"parser_{lang}.sno"
        r = subprocess.run([str(SCRIP), "--transpile"] + [str(p) for p in chain], capture_output=True, text=True,
                           stdin=subprocess.DEVNULL, timeout=120)
        if r.returncode != 0 or not r.stdout.strip():
            refuse(f"--transpile of the {lang} chain failed rc={r.returncode}: {(r.stderr or r.stdout)[:300]}")
        sno.write_text(r.stdout)
        placeholders = len(re.findall(r"\?TT_\d+\?|\?VAR\?|\?FN\?|\?KW\?", r.stdout))
        if placeholders:
            print(f"⚠ transpile placeholders in {sno.name}: {placeholders}")
        prog = sno
    else:
        prog = d / f"chain_{lang}.sc"
        prog.write_text("".join(p.read_text() for p in chain))
    if arm == "sbl":
        if not SBL.is_file():
            refuse(f"no SPITBOL oracle at {SBL}")
        return [str(SBL), "-bf"] + sbl_args(lang) + [str(prog)], d
    if arm in ("m3", "sc3"):
        return [str(SCRIP)] + scrip_arena(lang) + [str(prog)], d
    exe = d / f"{prog.stem}.{arm}.bin"
    asm = d / f"{prog.stem}.{arm}.s"
    obj = d / f"{prog.stem}.{arm}.o"
    for cmd in ([str(SCRIP), "--compile", f"--out={str(asm)}", str(prog)],
                ["as", "--64", "-o", str(obj), str(asm)],
                ["gcc", "-no-pie", "-o", str(exe), str(obj), "-L", str(RTLIB), "-lscrip_rt", f"-Wl,-rpath,{RTLIB}", "-lm"]):
        r = subprocess.run(cmd, capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=600)
        if r.returncode != 0:
            refuse(f"{arm} build step failed rc={r.returncode}: {' '.join(cmd[:3])} ... {(r.stderr or r.stdout)[:300]}")
    return [str(exe)] + scrip_arena(lang), d


def classify(arm, rc, text, timed_out):
    if timed_out:
        return "TIMEOUT", "timeout"
    lines = [l for l in text.splitlines() if l.strip()]
    # the parser's own refusal is a line that IS "Parse Error" -- a program that prints the words (beauty.sc does) parses
    # to a tree CONTAINING them, and a substring test called that tree a refusal
    if any(re.fullmatch(r"Parse Error\.?", l.strip()) for l in lines):
        return "REFUSED", "Parse Error"
    m = SPITBOL_ERR.search(text) or (SCRIP_ERR.search(text) if arm != "sbl" else None)
    if m:
        line = text[text.rfind("\n", 0, m.start()) + 1:].split("\n", 1)[0]
        return "CRASH", line.strip()[:160]
    if rc != 0:
        return "CRASH", f"rc={rc}: {(lines[-1] if lines else '')[:140]}"
    if not lines:
        return "EMPTY", ""
    return "PARSED", ""


def run_one(argv, cwd, src, outp, timeout):
    t0 = time.time()
    try:
        with open(src, "rb") as fin:
            r = subprocess.run(argv, stdin=fin, capture_output=True, cwd=cwd, timeout=timeout)
        out = r.stdout.decode("utf-8", "replace")
        err = r.stderr.decode("utf-8", "replace")
        rc, to = r.returncode, False
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode("utf-8", "replace")
        err = (e.stderr or b"").decode("utf-8", "replace")
        rc, to = -9, True
    outp.write_text(out + ("\n--- stderr ---\n" + err if err.strip() else ""))
    return rc, out + "\n" + err, to, time.time() - t0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("langs", nargs="+", choices=sorted(LANGS) + ["all"])
    ap.add_argument("--arm", default="sbl", choices=["sbl", "m3", "m4", "sc3", "sc4"])
    ap.add_argument("-j", "--jobs", type=int, default=6)
    ap.add_argument("--timeout", type=float, default=30.0, help="seconds per source (default 30)")
    ap.add_argument("--work", default="", help="work directory (default: $TMPDIR/bootstrap_parsers)")
    ap.add_argument("--only", default="", help="grade only members whose name contains this substring")
    ap.add_argument("--no-rungs", action="store_true", help="corpus files only")
    ap.add_argument("--list", action="store_true", help="print the population and exit 0")
    ap.add_argument("--show", type=int, default=40, help="names printed per class (default 40; 0 = all)")
    a = ap.parse_args()
    langs = sorted(LANGS) if "all" in a.langs else a.langs
    work = Path(a.work or (Path(os.environ.get("TMPDIR", "/tmp")) / "bootstrap_parsers")).resolve()
    work.mkdir(parents=True, exist_ok=True)
    worst = 0
    for lang in langs:
        pop = corpus_files(lang) + ([] if a.no_rungs else rungs_entries(lang, work))
        if a.only:
            pop = [(n, p) for n, p in pop if a.only in n]
        if a.list:
            for n, p in pop:
                print(f"{lang}\t{n}\t{p}")
            continue
        if not pop:
            refuse(f"{lang}: the population is EMPTY -- nothing to grade")
        argv, cwd = build_arm(lang, a.arm, work)
        outd = work / lang / a.arm
        if outd.exists():
            shutil.rmtree(outd)
        outd.mkdir(parents=True)
        results = {}
        with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, a.jobs)) as ex:
            futs = {}
            for i, (name, p) in enumerate(pop):
                safe = re.sub(r"[^A-Za-z0-9_.-]", "_", name)[-150:]
                futs[ex.submit(run_one, argv, cwd, p, outd / f"{i:05d}_{safe}.out", a.timeout)] = name
            for f in concurrent.futures.as_completed(futs):
                rc, text, to, dt = f.result()
                results[futs[f]] = classify(a.arm, rc, text, to) + (dt,)
        counts = {k: 0 for k in ("PARSED", "REFUSED", "CRASH", "TIMEOUT", "EMPTY")}
        for c, _, _ in results.values():
            counts[c] += 1
        nfile = sum(1 for n, _ in pop if not n.startswith("rungs:"))
        print(f"bootstrap parser {lang} arm={a.arm}" + (f" sbl {' '.join(sbl_args(lang))}" if a.arm == "sbl" else f" scrip {' '.join(scrip_arena(lang))}")
              + f" SCRIP {git_head(SCRIP_DIR)} corpus {git_head(CORPUS)} work={work / lang}")
        print(f"POPULATION {lang}: files={nfile} rungs={len(pop) - nfile} total={len(pop)}")
        print(f"BOARD {lang} {a.arm}: PARSED={counts['PARSED']} REFUSED={counts['REFUSED']} CRASH={counts['CRASH']} "
              f"TIMEOUT={counts['TIMEOUT']} EMPTY={counts['EMPTY']} / {len(pop)}")
        for cls in ("REFUSED", "CRASH", "TIMEOUT", "EMPTY"):
            names = sorted(n for n, (c, _, _) in results.items() if c == cls)
            if not names:
                continue
            shown = names if a.show == 0 else names[:a.show]
            print(f"  {cls} ({len(names)}):")
            for n in shown:
                why = results[n][1]
                print(f"    {n}" + (f"  [{why}]" if why and cls == "CRASH" else ""))
            if len(shown) < len(names):
                print(f"    ... {len(names) - len(shown)} more (--show 0 prints all)")
        worst = max(worst, 0 if counts["PARSED"] == len(pop) else 1)
    return worst


if __name__ == "__main__":
    sys.exit(main())

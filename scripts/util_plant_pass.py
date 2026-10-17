#!/usr/bin/env python3
"""util_plant_pass.py --scrip BIN --population NAME=DIR[:ARGS] ... --receipt OUT.tsv -- a tagged plant's census.

THE METHOD (cto, CTO-18x; memory: a tagged plant pass proves a road dead in ninety seconds): in a scratch worktree,
every arm under question prints one tag line PREFIX<ARM> to stderr AT EMIT TIME (fputs in the template or the emitter,
never a run-time bomb -- a bomb fires only on the paths a run executes); this driver compiles every source of every
population with that binary (scrip --compile, cwd the file's own directory, SNO_LIB the corpus include dir) twelve
wide and counts, per language and per arm, the files that fired and the tags. An arm at 0 on every population, with
a control arm that fired, is dead on that population; an arm that fires names its smallest witnesses.

POPULATIONS. A population is a directory walked for every extension scrip_exts[] admits. DIR/INDEX.tsv (written by
util_extract_rungs_entries.py) adds each entry's declared compile_args when the population is named with :declared;
a rung suite is a CONTAINER and is never compiled whole, so the rung suites' entries must be extracted one per file into a
population of their own (SCRIP 65b0bc779 retired an arm on corpus sources alone and two SnoRungs entries reached it).

RECEIPT (TSV, one row per language x population x arm; a header comment names the binary, its tree and the date):
  language population files compiled refused crashed timedout arm files_fired tags witnesses
rc 0 the pass ran and every population had files; rc 2 REFUSE (no binary, an empty population, no tag at all fired).
"""
import argparse
import collections
import concurrent.futures as cf
import datetime
import os
import subprocess
import sys
from pathlib import Path

EXT_LANG = {".sno": "snobol4", ".spt": "snobol4", ".sbl": "snobol4", ".sc": "snocone", ".reb": "rebus", ".icn": "icon",
            ".pl": "prolog", ".raku": "raku", ".pas": "pascal"}


def refuse(msg):
    print(f"REFUSE(2): {msg}", file=sys.stderr)
    sys.exit(2)


def population_files(d, declared):
    args = {}
    if declared:
        idx = d / "INDEX.tsv"
        for lang_idx in [idx] + sorted(d.glob("*/INDEX.tsv")):
            if lang_idx.is_file():
                for line in lang_idx.read_text().splitlines()[1:]:
                    f = line.split("\t")
                    if len(f) >= 3:
                        args[(lang_idx.parent / f[1].split("/", 1)[-1]).resolve()] = f[2].split()
    out = []
    for p in sorted(d.rglob("*")):
        if ".git" in p.parts or not p.is_file() or p.suffix not in EXT_LANG:
            continue
        out.append((p.resolve(), EXT_LANG[p.suffix], args.get(p.resolve(), [])))
    return out


def compile_one(scrip, sno_lib, prefix, timeout, item, run=False, extra_env=None):
    path, lang, cargs = item
    env = dict(os.environ, SNO_LIB=sno_lib, **(extra_env or {}))
    try:
        r = subprocess.run([scrip] + ([] if run else ["--compile"]) + cargs + [path.name], cwd=str(path.parent), env=env, stdin=subprocess.DEVNULL,
                           stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=timeout)
        rc, err = r.returncode, r.stderr.decode("utf-8", "replace")
    except subprocess.TimeoutExpired as e:
        rc, err = None, (e.stderr or b"").decode("utf-8", "replace")
    tags = collections.Counter(l[len(prefix):].strip() for l in err.splitlines() if l.startswith(prefix))
    return path, lang, rc, tags


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--scrip", required=True)
    ap.add_argument("--population", action="append", required=True, help="NAME=DIR or NAME=DIR:declared")
    ap.add_argument("--receipt", required=True)
    ap.add_argument("--prefix", default="PLANT:")
    ap.add_argument("--jobs", type=int, default=12)
    ap.add_argument("--timeout", type=float, default=60)
    ap.add_argument("--sno-lib", default=str(Path(__file__).resolve().parents[2] / "corpus" / "include"))
    ap.add_argument("--witnesses", type=int, default=5)
    ap.add_argument("--run", action="store_true", help="mode 3: compile AND run each source, so code compiled at run time (EVAL, CODE) prints its tags too")
    ap.add_argument("--env", action="append", default=[], help="K=V set for every compile (a forced-positive control, e.g. SCRIP_NO_TINY=1)")
    ap.add_argument("--lang", action="append", help="only these languages (repeatable)")
    a = ap.parse_args()
    extra_env = dict(kv.split("=", 1) for kv in a.env)
    scrip = str(Path(a.scrip).resolve())
    if not os.access(scrip, os.X_OK):
        refuse(f"no executable scrip at {scrip}")
    tree = subprocess.run(["git", "-C", str(Path(scrip).parent), "log", "-1", "--format=%h %s"], capture_output=True, text=True).stdout.strip()
    dirty = subprocess.run(["git", "-C", str(Path(scrip).parent), "diff", "--stat"], capture_output=True, text=True).stdout.strip().splitlines()
    rows, fired_any = [], 0
    for spec in a.population:
        name, _, rest = spec.partition("=")
        declared = rest.endswith(":declared")
        d = Path(rest[: -len(":declared")] if declared else rest).resolve()
        items = [it for it in population_files(d, declared) if not a.lang or it[1] in a.lang]
        if not items:
            refuse(f"population {name} at {d} holds no source scrip compiles")
        stat = collections.defaultdict(lambda: collections.Counter())
        arm_files = collections.defaultdict(collections.Counter)
        arm_tags = collections.defaultdict(collections.Counter)
        wit = collections.defaultdict(lambda: collections.defaultdict(list))
        with cf.ThreadPoolExecutor(max_workers=a.jobs) as ex:
            for path, lang, rc, tags in ex.map(lambda it: compile_one(scrip, a.sno_lib, a.prefix, a.timeout, it, a.run, extra_env), items):
                s = stat[lang]
                s["files"] += 1
                if rc is None:
                    s["timedout"] += 1
                elif rc == 0:
                    s["compiled"] += 1
                elif rc < 0 or rc >= 128:
                    s["crashed"] += 1
                else:
                    s["refused"] += 1
                for arm, n in tags.items():
                    arm_files[lang][arm] += 1
                    arm_tags[lang][arm] += n
                    fired_any += n
                    if len(wit[lang][arm]) < a.witnesses:
                        wit[lang][arm].append(str(path.relative_to(d)))
        for lang in sorted(stat):
            s = stat[lang]
            base = [lang, name, s["files"], s["compiled"], s["refused"], s["crashed"], s["timedout"]]
            arms = sorted(arm_files[lang]) or ["-"]
            for arm in arms:
                rows.append(base + [arm, arm_files[lang][arm], arm_tags[lang][arm], ",".join(wit[lang][arm])])
            print(f"POPULATION {name} {lang}: files={s['files']} compiled={s['compiled']} refused={s['refused']} crashed={s['crashed']} "
                  f"timedout={s['timedout']} arms={len(arm_files[lang])}")
    if not fired_any:
        refuse("no tag fired on any population -- the binary is not the planted one, or the prefix is wrong; nothing is proven")
    hdr = (f"# util_plant_pass.py {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')} -- binary {scrip} on tree {tree}; "
           f"{'mode 3 (compile and run)' if a.run else 'scrip --compile'}{'; env ' + ' '.join(a.env) if a.env else ''}; "
           f"planted files: {dirty[-1] if dirty else 'NONE (the tree is clean: no arm is tagged)'}\n"
           "language\tpopulation\tfiles\tcompiled\trefused\tcrashed\ttimedout\tarm\tfiles_fired\ttags\twitnesses\n")
    Path(a.receipt).write_text(hdr + "".join("\t".join(str(x) for x in r) + "\n" for r in rows))
    print(f"RECEIPT {a.receipt} rows={len(rows)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

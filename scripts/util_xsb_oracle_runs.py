#!/usr/bin/env python3
"""util_xsb_oracle_runs.py -- THE RUNS XSB'S OWN TEST SCRIPTS MAKE, RECORDED (the coo, 2026-10-23, on ceo CEO-1927).

Lon 2026-10-23 11:3x CDT, in-chat to the cfo, verbatim: "Since SWIPL does not have all XSB, we should begin to use XSB system as the third oracle."
RULES.md § Oracles, FACT RULE XSB IS THE THIRD PROLOG ORACLE, FOR THE XSB PACKAGE: each XsbTests program runs as XSB's own gentest.sh runs it, GOAL
from its directory's test.sh. This instrument does not parse those scripts; it RUNS them, each directory's own test.sh in a fresh copy of the
upstream tree (and incremental_tests/stest.sh, the one stest.sh XSB's testall.sh runs by default, ceo CEO-1927 (B)), with a recording XEMU in
front of xsb_bin(): every invocation's directory, argv and stdin are logged, its temp file kept. So a program's run -- its directory, options,
FILE and CMD, the cd's and loops of its script included -- is the one XSB's own scripts made, never one typed here.

  record <out-dir> [--strace]      one pass, serial, nice 19, headless, stdin /dev/null; --strace also logs every file each run opened
  runs <pass1> <pass2> <pkg-dir>   ORACLE_RUNS.tsv on stdout: one row per vendored program a gentest or wfs invocation ran, with its
                                   two answers' agreement and its NAME_old check in the trailing comment (the builder judges again itself)
  loaders <strace-pass> <pkg-dir>  ORACLE_LOADS.tsv on stdout: name<TAB>count<TAB>loaders -- every vendored file some run OPENED (its source,
                                   or the .xwam compiled from it) other than the run's own program, each loader a vendored program (NAME.pl)
                                   or a script's own run (DIR/SCRIPT (its own run of ...)): the measurement a CONTAINERS.tsv LOADED_BY row
                                   of an oracle=xsb-gentest package re-derives from (util_container_or_library.py verify)

The upstream tree is the package's CONTRACT.tsv `upstream` (corpus/packages/prolog/xsb_tests); SOURCES.tsv maps each vendored name to its file.
"""
import hashlib, os, re, shutil, subprocess, sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
GEN = re.compile(r"^\[([^\]]+)\]\.\ntell\(temp\)\.\n(.*)\ntold\.\n?$", re.S)
WFS = re.compile(r"^\[wfs_test\]\.\n(test\((\w+)\)\.)\ntold\.\n?$", re.S)
OPEN = re.compile(r'open(?:at)?\((?:AT_FDCWD, |-?\d+, )?"([^"]+)"')
OPTIONS = "-e segfault_handler(warn)."   # testall.sh: ./test.sh "$XEMU" "-e segfault_handler(warn). $options"
RECORDER = r"""#!/usr/bin/env bash
# XEMU for XSB's own test scripts (util_xsb_oracle_runs.py record): logs pwd, argv and stdin, runs xsb_bin under a 120 s timeout, keeps temp.
L="${XR_LOG:?}"; n="$(date +%s%N)-$$"
cat > "$L/$n.in"
t0=$(date +%s)
if [ -n "${XR_STRACE:-}" ]; then
  timeout -k 5 120 strace -f -qq -e trace=open,openat -e status=successful -o "$L/$n.strace" "$XR_REAL" "$@" < "$L/$n.in" > "$L/$n.out" 2> "$L/$n.err"; rc=$?
else
  timeout -k 5 120 "$XR_REAL" "$@" < "$L/$n.in" > "$L/$n.out" 2> "$L/$n.err"; rc=$?
fi
if [ -f temp ] && [ "$(stat -c %Y temp)" -ge "$t0" ]; then cp temp "$L/$n.temp"; fi
printf '%s\t%s\t%s\t%s\t%s\n' "$n" "$PWD" "$rc" "${XR_SCRIPT:-}" "$(printf '%q ' "$@")" >> "$L/inv.tsv"
cat "$L/$n.out"; cat "$L/$n.err" >&2
exit $rc
"""


def refuse(msg):
    print(f"REFUSED(2) [util_xsb_oracle_runs]: {msg}", file=sys.stderr)
    sys.exit(2)


def contract_upstream(pkg):
    cf = Path(pkg) / "CONTRACT.tsv"
    for ln in (cf.read_text().splitlines() if cf.is_file() else []):
        f = ln.split("\t")
        if len(f) >= 2 and f[0] == "upstream":
            return Path(f[1])
    refuse(f"{cf} names no upstream directory")


def xsb_bin():
    r = subprocess.run(["bash", "-c", f". '{HERE}/lib_oracle_flags.sh' && xsb_bin"], capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout.strip():
        refuse(f"xsb_bin refused: {r.stderr.strip()}")
    return r.stdout.strip()


def sources(pkg):
    """vendored name -> upstream path below xsbtests/, from SOURCES.tsv (source column xsb/xsbtests/<rel>)."""
    out = {}
    for ln in open(Path(pkg) / "SOURCES.tsv", encoding="utf-8"):
        c = ln.rstrip("\n").split("\t")
        if len(c) >= 3 and c[2].startswith("xsb/xsbtests/"):
            out[c[0]] = c[2][len("xsb/xsbtests/"):]
    return out


def cmd_record(out, strace, upstream):
    out = Path(out).resolve()
    if out.exists():
        refuse(f"{out} exists -- a pass records into a fresh directory")
    (out / "log").mkdir(parents=True)
    rec = out / "xemu_rec.sh"
    rec.write_text(RECORDER)
    rec.chmod(0o755)
    shutil.copytree(upstream, out / "xsbtests", ignore=shutil.ignore_patterns("*.xwam", "*_new", "temp"))
    env = {k: v for k, v in os.environ.items() if k not in ("DISPLAY", "WAYLAND_DISPLAY")}
    env.update(XR_LOG=str(out / "log"), XR_REAL=xsb_bin())
    if strace:
        env["XR_STRACE"] = "1"
    scripts = [(d, "test.sh") for d in sorted((out / "xsbtests").iterdir()) if (d / "test.sh").is_file()]
    scripts.append((out / "xsbtests" / "incremental_tests", "stest.sh"))   # testall.sh: ./stest.sh "$XEMU" "-e segfault_handler(warn).  $options"
    with open(out / "scripts.rc", "w") as rcf:
        for d, sh in scripts:
            env["XR_SCRIPT"] = f"{d.name}/{sh}"
            with open(out / "log" / f"{d.name}.{sh}.log", "w") as lf:
                p = subprocess.run(["timeout", "-k", "10", "3600", "nice", "-n", "19", "sh", f"./{sh}", str(rec), OPTIONS], cwd=d, env=env,
                                   stdin=subprocess.DEVNULL, stdout=lf, stderr=subprocess.STDOUT)
            rcf.write(f"{d.name}/{sh}\t{p.returncode}\n")
            print(f"{d.name}/{sh} rc={p.returncode}", file=sys.stderr)


def invocations(run):
    run = Path(run)
    root = str(run / "xsbtests")
    out = []
    for ln in open(run / "log" / "inv.tsv"):
        n, pwd, rc, script, argv = ln.rstrip("\n").split("\t", 4)
        rel = pwd[len(root) + 1:] if pwd.startswith(root + "/") else pwd
        stdin = (run / "log" / f"{n}.in").read_text(errors="replace")
        tp = run / "log" / f"{n}.temp"
        m, w = GEN.match(stdin), WFS.match(stdin)
        if m:
            kind, file, cmd = "gentest", m.group(1).strip(), m.group(2).strip()
        elif w and rel.split("/")[0] == "wfs_tests":
            kind, file, cmd = "wfs", w.group(2), w.group(1)
        else:
            kind, file, cmd = "other", "", ""
        out.append(dict(n=n, pwd=pwd, rel=rel, rc=rc, script=script, argv=argv.strip(), stdin=stdin, kind=kind, file=file, cmd=cmd,
                        temp=tp.read_bytes() if tp.is_file() else None, strace=run / "log" / f"{n}.strace"))
    return out


def lines(b):
    return sorted(x for x in b.decode("utf-8", "replace").split("\n") if x != "")


def name_of(src_by_stem, rel, file):
    return src_by_stem.get(f"{rel}/{file}")


def cmd_runs(p1, p2, pkg):
    upstream = contract_upstream(pkg)
    src = sources(pkg)
    by_stem = {rel.rsplit(".", 1)[0]: name for name, rel in src.items()}
    second = defaultdict(list)
    for v in invocations(p2):
        second[(v["rel"], v["argv"], v["stdin"])].append(v)
    used, rows = defaultdict(int), {}
    for v in invocations(p1):
        key = (v["rel"], v["argv"], v["stdin"])
        i = used[key]; used[key] += 1
        if v["kind"] == "other":
            continue
        name = name_of(by_stem, v["rel"], v["file"])
        if not name:
            continue
        if name in rows:
            refuse(f"{name} is run twice by XSB's scripts ({rows[name]['rel']} and {v['rel']}) -- one program, one recorded run; rule it first")
        w = second[key][i] if i < len(second[key]) else None
        a1 = lines(v["temp"]) if v["temp"] is not None else None
        a2 = lines(w["temp"]) if w and w["temp"] is not None else None
        twice = "SAME" if (w and a1 == a2) else "DIFFER"
        op = upstream / v["rel"] / f"{v['file']}_old"
        if a1 is None:
            old = "NO_TEMP"
        elif op.is_file():
            o = lines(op.read_bytes())
            old = "MATCH" if o == a1 else ("MATCH-w" if sorted("".join(x.split()) for x in o) == sorted("".join(x.split()) for x in a1) else f"DIFF({len(o)}v{len(a1)})")
        else:
            old = "NO_OLD"
        script = v["script"]
        rows[name] = dict(rel=v["rel"], kind=v["kind"], file=v["file"], cmd=v["cmd"].replace("\t", " ").replace("\n", " "), argv=v["argv"], script=script,
                          note=f"{twice} {old} {len(a1) if a1 is not None else '-'} lines")
    print("# ORACLE_RUNS.tsv -- xsb_tests: one row per vendored program XSB's own test scripts run, recorded by running them (harness")
    print("# util_xsb_oracle_runs.py record, twice; runs) with a recording XEMU in front of xsb_bin(), ceo CEO-1927. The builder (CONTRACT.tsv")
    print("# oracle=xsb-gentest) cuts each ref from this run: name, dir (below CONTRACT.tsv's upstream), kind (gentest: [FILE]. tell(temp). CMD.")
    print("# told.; wfs: [wfs_test]. CMD told.), file, cmd, emu_args (shell-quoted, as the script passed them), script.")
    for name in sorted(rows):
        r = rows[name]
        print("\t".join([name, r["rel"], r["kind"], r["file"], r["cmd"], r["argv"], r["script"]]))
    print(f"{len(rows)} programs run; " + ", ".join(f"{k} {sum(1 for r in rows.values() if r['note'].startswith(k))}" for k in ("SAME", "DIFFER")), file=sys.stderr)
    with open(Path(p1) / "runs.notes.tsv", "w") as f:
        for name in sorted(rows):
            f.write(f"{name}\t{rows[name]['note']}\n")


def cmd_loaders(run, pkg):
    src = sources(pkg)
    by_stem = {rel.rsplit(".", 1)[0]: name for name, rel in src.items()}
    root = str(Path(run).resolve() / "xsbtests")
    loaders = defaultdict(set)
    for v in invocations(run):
        me = name_of(by_stem, v["rel"], v["file"]) if v["kind"] != "other" else None
        if me:
            who = me + ".pl"
        else:
            first = v["stdin"].strip().splitlines()[0][:50] if v["stdin"].strip() else v["argv"][:50]
            who = f"{v['script']} (its own run of {first})"
        if not v["strace"].is_file():
            refuse(f"{v['strace']} missing -- loaders reads a pass recorded with --strace")
        for sl in open(v["strace"], errors="replace"):
            o = OPEN.search(sl)
            if not o:
                continue
            p = o.group(1) if o.group(1).startswith("/") else os.path.normpath(os.path.join(v["pwd"], o.group(1)))
            if not p.startswith(root + "/"):
                continue
            r = p[len(root) + 1:]
            stem = r.rsplit(".", 1)[0] if r.endswith((".P", ".pl", ".H", ".xwam")) else r
            name = by_stem.get(stem)
            if name and name != me:
                loaders[name].add(who)
    print("# ORACLE_LOADS.tsv -- xsb_tests: every vendored file XSB 5.0.0 OPENED while its own test scripts ran a program other than the file itself")
    print("# (harness util_xsb_oracle_runs.py record --strace; loaders, 2026-10-23, ceo CEO-1927): name<TAB>count<TAB>loaders (NAME.pl, or a")
    print("# script's own run). A CONTAINERS.tsv LOADED_BY row's first word re-derives from here (util_container_or_library.py verify).")
    for name in sorted(loaders):
        L = sorted(loaders[name], key=lambda s: ("(its own run" in s, s))
        print(f"{name}\t{len(L)}\t" + " | ".join(L))
    print(f"{len(loaders)} vendored files opened by a run other than their own", file=sys.stderr)


def main():
    a = sys.argv[1:]
    if a[:1] == ["record"] and len(a) in (2, 3):
        pkg = HERE.parent.parent / "corpus" / "packages" / "prolog" / "xsb_tests"
        cmd_record(a[1], a[2:] == ["--strace"], contract_upstream(pkg))
    elif a[:1] == ["runs"] and len(a) == 4:
        cmd_runs(a[1], a[2], a[3])
    elif a[:1] == ["loaders"] and len(a) == 3:
        cmd_loaders(a[1], a[2])
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)


main()

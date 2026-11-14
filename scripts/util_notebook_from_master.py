#!/usr/bin/env python3
"""util_notebook_from_master.py -- one Jupyter notebook for the one SCRIP kernel, built from named entries of a
language's test master (ALL.<ext> and ALL.ref), or from program files with a .ref beside each.

  util_notebook_from_master.py build --lang L --title TEXT --out PATH [--master DIR] ENTRY...
  util_notebook_from_master.py pairs --lang L --title TEXT --out PATH FILE...
  util_notebook_from_master.py --probe

Each ENTRY (or FILE) is one markdown cell naming it, then one code cell tagged %%L whose saved output is the
entry's ref, cut from the oracle already. The notebook's first cell is a markdown '# TITLE'. Exit 0 on success,
2 on a refusal (a missing master, entry, ref or language), 1 on a failed probe.
"""
import argparse
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import corpus_suite_harness as csh  # noqa: E402


def refuse(msg):
    print(f"REFUSE(2): {msg}", file=sys.stderr)
    sys.exit(2)


def corpus_root():
    return os.environ.get("S4E_CORPUS") or "/home/corpus"


def master_dir(lang, given):
    return Path(given) if given else Path(corpus_root()) / "tests" / lang


def block_entries(lang, d):
    cfg = csh.LANG_CONFIGS.get(lang)
    if cfg is None:
        refuse(f"no language {lang!r} in corpus_suite_harness.LANG_CONFIGS")
    src = d / ("ALL" + cfg["ext"])
    ref = d / "ALL.ref"
    if not src.exists():
        refuse(f"{src} does not exist: {lang} has no test master here; build it from program files with the pairs verb")
    if not ref.exists():
        refuse(f"{ref} does not exist")
    banner = csh.banner_re_for(cfg["comment_open"], cfg["comment_close"])
    try:
        return csh.read_block_suite(src, ref, banner)
    except ValueError as e:
        refuse(f"cannot read the master {src}: {e}")


def ref_text(lines):
    return "".join(line + "\n" for line in lines)


def md_cell(text):
    return {"cell_type": "markdown", "metadata": {}, "source": text}


def code_cell(lang, prog, out, count):
    return {"cell_type": "code", "execution_count": count, "metadata": {},
            "outputs": [{"output_type": "stream", "name": "stdout", "text": out}],
            "source": f"%%{lang}\n{prog}"}


def notebook(title, items, lang):
    cells = [md_cell("# " + title)]
    count = 0
    for name, prog, out in items:
        cells.append(md_cell("### " + name))
        count += 1
        cells.append(code_cell(lang, prog, out, count))
    # nbformat 4.5 asks every cell for an id (1 to 64 of [A-Za-z0-9-_], unique in the notebook); a cell's
    # place is its id, so the same entries always write the same bytes.
    for k, c in enumerate(cells):
        c["id"] = f"cell-{k}"
    return {"nbformat": 4, "nbformat_minor": 5,
            "metadata": {"kernelspec": {"name": "scrip", "display_name": "SCRIP", "language": "scrip"},
                         "language_info": {"name": "scrip"}},
            "cells": cells}


def write_nb(path, nb):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(nb, f, indent=1, ensure_ascii=False)
        f.write("\n")


def emit(a, items):
    nb = notebook(a.title, items, a.lang)
    write_nb(a.out, nb)
    print(f"NOTEBOOK_FROM_MASTER wrote {a.out} cells={len(nb['cells'])} entries={len(items)}")
    return 0


def cmd_build(a):
    d = master_dir(a.lang, a.master)
    by_name = {}
    for e in block_entries(a.lang, d):
        by_name.setdefault(e.name, e)
    items = []
    for n in a.entries:
        if n not in by_name:
            refuse(f"no entry {n!r} in {d}")
        e = by_name[n]
        items.append((n, "\n".join(e.sno_lines), ref_text(e.ref)))
    return emit(a, items)


def cmd_pairs(a):
    items = []
    for f in a.files:
        p = Path(f)
        if not p.exists():
            refuse(f"no program {p}")
        r = p.with_suffix(".ref")
        if not r.exists():
            refuse(f"no ref beside {p}: {r} is missing")
        prog = p.read_bytes().decode("utf-8", "replace")
        if prog.endswith("\n"):
            prog = prog[:-1]
        items.append((p.stem, prog, r.read_bytes().decode("utf-8", "replace")))
    return emit(a, items)


def segments(lines, banner):
    """(name, index of its banner line) for each banner line, in file order."""
    out = []
    for i, line in enumerate(lines):
        m = banner.match(line)
        if m:
            out.append((m.group("name"), i))
    return out


def probe():
    d = Path(tempfile.mkdtemp(prefix="nfm_probe_"))
    try:
        cfg = csh.LANG_CONFIGS["rebus"]
        banner = csh.banner_re_for(cfg["comment_open"], cfg["comment_close"])
        real = master_dir("rebus", None)
        src_lines = csh._read_lf_lines(real / "ALL.reb")
        ref_lines = csh._read_lf_lines(real / "ALL.ref")
        src_seg = segments(src_lines, banner)
        ref_seg = segments(ref_lines, banner)
        if len(src_seg) < 3 or len(ref_seg) < 3:
            return bad("the rebus master holds fewer than three entries to plant two from")
        names = [src_seg[0][0], src_seg[1][0]]

        def plant(lines, seg, out):
            start = seg[0][1]
            stop = seg[2][1]
            (d / out).write_text("\n".join(lines[start:stop]) + "\n", encoding="utf-8")

        plant(src_lines, src_seg, "ALL.reb")
        plant(ref_lines, ref_seg, "ALL.ref")
        planted_src = csh._read_lf_lines(d / "ALL.reb")
        planted_ref = csh._read_lf_lines(d / "ALL.ref")
        psrc = segments(planted_src, banner)
        pref = segments(planted_ref, banner)
        if [n for n, _ in psrc] != names or [n for n, _ in pref] != names:
            return bad(f"the planted master names {[n for n, _ in psrc]} not {names}")

        a = argparse.Namespace(lang="rebus", title="probe", out=str(d / "probe.ipynb"), master=str(d),
                               entries=names)
        items = []
        for k, (name, bi) in enumerate(psrc):
            end = psrc[k + 1][1] if k + 1 < len(psrc) else len(planted_src)
            prog = "\n".join(planted_src[bi + 1:end])
            rbi = pref[k][1]
            rend = pref[k + 1][1] if k + 1 < len(pref) else len(planted_ref)
            expect_out = "".join(line + "\n" for line in planted_ref[rbi + 1:rend])
            items.append((name, prog, expect_out))
        if cmd_build_quiet(a) != 0:
            return bad("the build of the planted master did not exit 0")
        with open(d / "probe.ipynb", encoding="utf-8") as f:
            nb = json.load(f)
        cells = nb["cells"]
        kinds = [c["cell_type"] for c in cells]
        if kinds != ["markdown", "markdown", "code", "markdown", "code"]:
            return bad(f"cell kinds {kinds} are not title, md, code, md, code")
        if nb["metadata"]["kernelspec"]["name"] != "scrip":
            return bad("kernelspec name is not scrip")
        ids = [c.get("id") for c in cells]
        if None in ids or len(set(ids)) != len(ids):
            return bad(f"cell ids {ids} are not one distinct id a cell")
        codes = [c for c in cells if c["cell_type"] == "code"]
        for (name, prog, expect_out), c in zip(items, codes):
            src = "".join(c["source"])
            if not src.startswith("%%rebus\n"):
                return bad(f"code cell of {name} does not start with %%rebus")
            if src != "%%rebus\n" + prog:
                return bad(f"code cell of {name} is not its program text")
            out = "".join(c["outputs"][0]["text"])
            if out != expect_out:
                return bad(f"output of {name} differs from its ref")
        return ok()
    except Exception as e:  # noqa: BLE001 -- a probe reports any failure as bad, never as a crash
        return bad(f"{type(e).__name__}: {e}")
    finally:
        shutil.rmtree(d, ignore_errors=True)


def cmd_build_quiet(a):
    try:
        import contextlib
        import io
        with contextlib.redirect_stdout(io.StringIO()):
            return cmd_build(a)
    except SystemExit as e:
        return int(e.code or 0)


def ok():
    print("NOTEBOOK_FROM_MASTER_PROBE ok")
    return 0


def bad(reason):
    print(f"NOTEBOOK_FROM_MASTER_PROBE bad {reason}")
    return 1


def main(argv=None):
    ap = argparse.ArgumentParser(description="One SCRIP-kernel Jupyter notebook from a master's entries or program files.")
    ap.add_argument("--probe", action="store_true", help="prove the tool on a planted two-entry rebus master")
    sub = ap.add_subparsers(dest="cmd")
    b = sub.add_parser("build", help="notebook from named entries of a language's master")
    b.add_argument("--lang", required=True)
    b.add_argument("--title", required=True)
    b.add_argument("--out", required=True)
    b.add_argument("--master", default="", metavar="DIR", help="default: $S4E_CORPUS/tests/<lang>")
    b.add_argument("entries", nargs="+", metavar="ENTRY")
    p = sub.add_parser("pairs", help="notebook from program files, each with a .ref beside it")
    p.add_argument("--lang", required=True)
    p.add_argument("--title", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("files", nargs="+", metavar="FILE")
    a = ap.parse_args(argv)
    if a.probe:
        return probe()
    if a.cmd == "build":
        a.master = a.master or ""
        return cmd_build(a)
    if a.cmd == "pairs":
        return cmd_pairs(a)
    ap.print_usage(sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())

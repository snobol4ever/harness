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
import re
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


# A LANGUAGE READ WITH ANOTHER'S TABLE: Unicon is the superset of Icon, its programs .icn files that SCRIP takes with --dialect=unicon, so
# its containers are read with icon's row of LANG_CONFIGS and that switch is the one compile argument a %%unicon cell carries itself.
READ_AS = {"unicon": "icon"}
OWN_SWITCH = {"unicon": "--dialect=unicon"}


def master_dir(lang, given):
    return Path(given) if given else Path(corpus_root()) / "tests" / lang


def block_entries(lang, d):
    cfg = csh.LANG_CONFIGS.get(READ_AS.get(lang, lang))
    if cfg is None:
        refuse(f"no language {lang!r} in corpus_suite_harness.LANG_CONFIGS")
    src = d / ("ALL" + cfg["ext"])
    ref = d / "ALL.ref"
    # A FORMAT-2 FOLDER (ONE-LINERS.EXT, ONE-LINERS.out, MULTI-LINERS.md) and a package in THE FILES FORM (ALL.csv with a path column, each
    # program with its NAME.out beside it) hold no ALL.EXT or ALL.ref: read_block_suite hands them to read_container_dir and
    # read_package_dir, so the two existence tests below are the old format's only (jupyter-steps 5 and 6, the cto's cure of 2026-11-14).
    if csh.fmt2_dir_of(src) is not None or csh.pkg_dir_of(src) is not None:
        ref = src.with_suffix(".ref")
    elif not src.exists():
        refuse(f"{src} does not exist: {lang} has no test master here; build it from program files with the pairs verb")
    elif not ref.exists():
        refuse(f"{ref} does not exist")
    banner = csh.banner_re_for(cfg["comment_open"], cfg["comment_close"])
    try:
        return csh.read_block_suite(src, ref, banner)
    except ValueError as e:
        refuse(f"cannot read the master {src}: {e}")


def ref_text(ref):
    """An entry of kind line carries its ref as ONE string, its output that string and one LF; a block entry a list of lines."""
    if isinstance(ref, str):
        return ref + "\n"
    return "".join(line + "\n" for line in ref)


# A CELL IS NOT A PROGRAM (the cao 2026-11-16, row jupyter-the-icon-and-unicon-notebooks-hold-cells-that-live-in-one-session): every cell of a notebook
# is one more unit of one live session, so an answer that holds only in a fresh process cannot be a cell's saved output. Read from the text:
# an image of a list, set, table, co-expression or record prints its serial number, which counts every structure the session made; exit()
# ends the session; &time and &collections count from the process's start. MEASURED on Icon_in_SCRIP.ipynb: cells 3, 10 and 11 differ by
# serial numbers alone (list_2 against list_7) and cell 5 ends the session with exit(0).
FRESH_SERIAL = re.compile(r"\b(?:list|set|table|co-expression)_\d+\b|\brecord [A-Za-z_][A-Za-z_0-9]*_\d+\(")
FRESH_SOURCE = re.compile(r"\bexit\s*\(|&time\b|&collections\b")


def unfit(e, lang=""):
    """Why a cell cannot be this entry, or "": a cell gives no stdin, no arguments and no companion file, and no cell's correct run ends
    in an error or a nonzero code (the cao's ruling, 2026-11-16 12:4x CST: a cell is not a program until the session host carries it)."""
    if e.stdin is not None:
        return "it reads stdin"
    if e.argv:
        return "it takes arguments"
    if getattr(e, "files", None):
        return "it reads a companion file"
    if getattr(e, "want_rc", 0):
        return f"its correct run exits {e.want_rc}"
    if getattr(e, "stderr_answer", None):
        return "its correct run writes stderr"
    extra = [a for a in (getattr(e, "compile_args", None) or []) if a != OWN_SWITCH.get(lang)]
    if extra:
        return f"it needs the compile switches {' '.join(extra)}"
    if getattr(e, "mask", None):
        return "its answer is masked (a line belongs to the implementation)"
    ref = e.ref if isinstance(e.ref, str) else "\n".join(e.ref or [])
    if FRESH_SERIAL.search(ref):
        return "its answer prints a structure's serial number, which in a session counts every structure the earlier cells made"
    src = "\n".join(getattr(e, "sno_lines", None) or [])
    if FRESH_SOURCE.search(src):
        return "it ends its process with exit() or reads &time or &collections, an answer that holds only in a fresh process"
    return ""


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
        why = unfit(e, a.lang)
        if why:
            refuse(f"entry {n!r} cannot be a cell: {why}")
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
        return probe_fmt2(d / "fmt2") or probe_pkg(d / "pkg")
    except Exception as e:  # noqa: BLE001 -- a probe reports any failure as bad, never as a crash
        return bad(f"{type(e).__name__}: {e}")
    finally:
        shutil.rmtree(d, ignore_errors=True)


def probe_fmt2(d):
    """THE FORMAT-2 ARM: a planted icon master of one one-liner, one multi-liner and one multi-liner that reads stdin; the first two build
    into two cells whose outputs are their answers (the one-liner's ONE string plus one LF), and the third is refused rc 2."""
    d.mkdir(parents=True)
    (d / "ALL.csv").write_text("rank,entry,kind,group,road,nonl\n1,p_one,line,one,direct,\n2,p_multi,block,multi,direct,\n"
                               "3,p_stdin,block,multi,direct,\n4,p_serial,block,multi,direct,\n5,p_exit,block,multi,direct,\n", encoding="utf-8")
    (d / "ONE-LINERS.icn").write_text('procedure main(); write("one-liner"); end\n', encoding="utf-8")
    (d / "ONE-LINERS.out").write_text("one-liner\n", encoding="utf-8")
    multi = 'procedure main()\n    write("a")\n    write("b")\nend\n'
    (d / "MULTI-LINERS.md").write_text("## p_multi\n\n```Icon\n" + multi + "```\n\n```stdout\na\nb\n```\n\n"
                                       "## p_stdin\n\n```Icon\nprocedure main(); write(read()); end\n```\n\n```stdin\nx\n```\n\n"
                                       "```stdout\nx\n```\n\n"
                                       "## p_serial\n\n```Icon\nprocedure main(); write(image([])); end\n```\n\n```stdout\nlist_1(0)\n```\n\n"
                                       "## p_exit\n\n```Icon\nprocedure main(); write(\"x\"); exit(0); end\n```\n\n```stdout\nx\n```\n\n", encoding="utf-8")
    a = argparse.Namespace(lang="icon", title="probe", out=str(d / "probe.ipynb"), master=str(d), entries=["p_one", "p_multi"])
    if cmd_build_quiet(a) != 0:
        return bad("the build of the planted format-2 master did not exit 0")
    with open(d / "probe.ipynb", encoding="utf-8") as f:
        codes = [c for c in json.load(f)["cells"] if c["cell_type"] == "code"]
    want = [("%%icon\n" + 'procedure main(); write("one-liner"); end', "one-liner\n"), ("%%icon\n" + multi[:-1], "a\nb\n")]
    got = [("".join(c["source"]), "".join(c["outputs"][0]["text"])) for c in codes]
    if got != want:
        return bad(f"format-2 cells {got!r} are not {want!r}")
    import contextlib
    import io
    for n in ("p_stdin", "p_serial", "p_exit"):
        a.entries = [n]
        with contextlib.redirect_stderr(io.StringIO()):
            rc = cmd_build_quiet(a)
        if rc != 2:
            return bad(f"the entry {n} built rc {rc}, not refused rc 2")
    return 0


def probe_pkg(d):
    """THE PACKAGE ARM: a planted package in the files form read as unicon; p_one (compile_args --dialect=unicon, the one switch a %%unicon cell
    carries) builds one %%unicon cell whose output is its NAME.out; p_in (a NAME.in beside it) and p_sw (one switch more) are refused rc 2."""
    (d / "a").mkdir(parents=True)
    (d / "ALL.csv").write_text("rank,entry,path,compile_args\n1,a/p_one,a/p_one.icn,--dialect=unicon\n2,a/p_in,a/p_in.icn,--dialect=unicon\n"
                               "3,a/p_sw,a/p_sw.icn,--dialect=unicon -S\n", encoding="utf-8")
    prog = 'procedure main()\n    write("pkg")\nend\n'
    for n in ("p_one", "p_in", "p_sw"):
        (d / "a" / f"{n}.icn").write_text(prog, encoding="utf-8")
        (d / "a" / f"{n}.out").write_text("pkg\n", encoding="utf-8")
    (d / "a" / "p_in.in").write_text("x\n", encoding="utf-8")
    a = argparse.Namespace(lang="unicon", title="probe", out=str(d / "probe.ipynb"), master=str(d), entries=["a/p_one"])
    if cmd_build_quiet(a) != 0:
        return bad("the build of the planted package did not exit 0")
    with open(d / "probe.ipynb", encoding="utf-8") as f:
        codes = [c for c in json.load(f)["cells"] if c["cell_type"] == "code"]
    got = [("".join(c["source"]), "".join(c["outputs"][0]["text"])) for c in codes]
    if got != [("%%unicon\n" + prog[:-1], "pkg\n")]:
        return bad(f"package cells {got!r} are not the one %%unicon cell of a/p_one")
    import contextlib
    import io
    for n in ("a/p_in", "a/p_sw"):
        a.entries = [n]
        with contextlib.redirect_stderr(io.StringIO()):
            rc = cmd_build_quiet(a)
        if rc != 2:
            return bad(f"{n} built rc {rc}, not refused rc 2")
    return ok()


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

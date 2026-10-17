#!/usr/bin/env python3
"""util_extract_rungs_entries.py OUTDIR [--lang L]... -- every entry of every rung suite suite, one file per entry.

A rung suite (corpus/tests/<lang>/ALL.<ext>) is a CONTAINER: it is never compiled whole (duplicate labels, one
program per banner), so a pass over corpus SOURCE FILES never compiles a single rung suite entry. SCRIP 65b0bc779
retired ten emitter arms on a tagged plant over 4693 corpus sources that held none of the 1991 SNOBOL4 entries
nor any other language's; two SnoRungs DEFINE entries (30 and 60 formals) reached the retired slim road and aborted
in both modes (hq_snobol4's shared-node verdict, restored at c103b8de5). This writes the missing population:
OUTDIR/<lang>/<entry><ext> for every entry, read through corpus_suite_harness.py's own readers (read_suite for
SNOBOL4's interleaved one-line and block dialect, read_block_suite for the banner-only rung suites -- the ONE
authority for the suite grammar), with every companion file the harness would copy beside a graded run.
OUTDIR/<lang>/INDEX.tsv names each entry, its file and the compile_args its attribute row declares.

rc 0 every requested rungs extracted; rc 2 REFUSE (no corpus, a rung suite or its ref missing, a reader raised).
"""
import argparse
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import corpus_suite_harness as H

LANGS = ["snobol4", "snocone", "rebus", "icon", "prolog", "pascal", "raku"]


def refuse(msg):
    print(f"REFUSE(2): {msg}", file=sys.stderr)
    sys.exit(2)


def rungs_of(corpus, lang):
    ext = ".sno" if lang == "snobol4" else H.LANG_CONFIGS[lang]["ext"]
    return corpus / "tests" / lang / f"ALL{ext}", ext


def read_entries(src, lang):
    ref = src.with_name("ALL.ref")
    if not ref.is_file():
        refuse(f"{src} has no ALL.ref beside it -- the readers pair every entry with its ref segment")
    modes = list(H.GRADED_MODES)
    kw = dict(in_path=H.sidecar_in_path(src), x_path=H.sidecar_xfail_path(src), w_path=H.sidecar_wantrc_path(src),
              a_path=H.sidecar_argv_path(src), modes=modes)
    if lang == "snobol4":
        return H.read_suite(src, ref, **kw)
    cfg = H.LANG_CONFIGS[lang]
    return H.read_block_suite(src, ref, H.banner_re_for(cfg["comment_open"], cfg["comment_close"]), **kw)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("outdir")
    ap.add_argument("--lang", action="append", choices=LANGS, help="one language (repeatable); default all seven")
    a = ap.parse_args()
    corpus = H.resolve_paths()["corpus"]
    if not corpus.is_dir():
        refuse(f"no corpus at {corpus} -- the rung suites live in the sibling corpus checkout")
    out = Path(a.outdir).resolve()
    total = 0
    for lang in a.lang or LANGS:
        src, ext = rungs_of(corpus, lang)
        if not src.is_file():
            refuse(f"no {lang} rungs at {src}")
        try:
            entries = read_entries(src, lang)
        except ValueError as e:
            refuse(f"{lang}: the harness reader raised on {src}: {e}")
        d = out / lang
        d.mkdir(parents=True, exist_ok=True)
        seen, rows = set(), []
        for e in entries:
            if e.name in seen:
                refuse(f"{lang}: entry name {e.name!r} occurs twice in {src} -- one file per entry needs unique names")
            seen.add(e.name)
            text = (e.sno_lines[0] + "\n") if e.kind == "line" else ("\n".join(e.sno_lines) + "\n")
            f = d / f"{e.name}{ext}"
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text(text)
            H._copy_companions(text, src.parent, f.parent)
            rows.append(f"{e.name}\t{f.relative_to(out)}\t{' '.join(e.compile_args or [])}")
        (d / "INDEX.tsv").write_text("entry\tfile\tcompile_args\n" + "\n".join(rows) + "\n")
        print(f"EXTRACTED {lang} entries={len(entries)} rungs={src}")
        total += len(entries)
    print(f"EXTRACTED total entries={total} into {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

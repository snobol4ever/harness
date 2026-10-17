#!/usr/bin/env python3
# util_migrate_snocone_procedure_to_function.py
#
# One-shot corpus migration: rewrite the Snocone `procedure` keyword
# to `function` across all .sc files.  Companion to LS-5's
# util_migrate_snocone_to_lang_space.py — that script handled
# &&/||/go-to in LS-5; this one handles the procedure→function
# rename that LS-4.h made on the lexer side ("function" is the new
# keyword; "procedure" remains as a backward-compat synonym in the
# lexer "until corpus migrated to function").
#
# Strategy: re-use the existing migration script's split_into_spans
# helper to keep strings and comments verbatim, then run a regex
# over CODE spans only.  Idempotent.
#
# Usage:
#   python3 util_migrate_snocone_procedure_to_function.py [ROOT]
#       --apply   write changes (default: dry run)
#
# session 2026-05-01 #7 — corpus syntax conversion to post-LS-4
# Snocone.

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import List, Tuple

# Re-use LS-5 migration script's span splitter.
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import util_migrate_snocone_to_lang_space as LS5  # noqa: E402

CODE = LS5.CODE

# `procedure` followed by whitespace and an identifier — declaration
# form.  We match the keyword as a whole word using lookahead/behind
# for non-identifier-char boundaries.  In practice every `procedure`
# in Snocone code IS a declaration (verified by grep audit), so the
# rewrite is uniform; we still use a word-boundary regex to avoid
# clobbering hypothetical compound identifiers.
PAT = re.compile(r"\bprocedure\b")


def migrate_code_span(text: str) -> str:
    return PAT.sub("function", text)


def migrate_text(src: str) -> str:
    """Idempotent rewrite of `procedure` → `function` in code spans."""
    out: List[str] = []
    for kind, text in LS5.split_into_spans(src):
        out.append(migrate_code_span(text) if kind == CODE else text)
    return "".join(out)


def gather_sc_files(root: Path) -> List[Path]:
    return sorted(p for p in root.rglob("*.sc") if p.is_file())


def main(argv: List[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Migrate procedure → function across corpus .sc files.")
    ap.add_argument("root", nargs="?", default=None, help="Corpus root (default: auto-detect)")
    ap.add_argument("--apply", action="store_true", help="Write changes (default: dry-run)")
    ap.add_argument("--quiet", action="store_true", help="Suppress per-file lines")
    args = ap.parse_args(argv)

    root = Path(args.root) if args.root else LS5.find_default_root()
    if not root.exists():
        print(f"FAIL  corpus root not found: {root}", file=sys.stderr)
        return 1

    files = gather_sc_files(root)
    changed = 0
    total_replacements = 0
    for path in files:
        try:
            src = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            print(f"SKIP  {path} (non-utf8)")
            continue
        out = migrate_text(src)
        if out == src:
            continue
        # Count replacements (cheap re-run, fine for one-shot tool)
        n = len(PAT.findall(src)) - len(PAT.findall(out))  # how many removed
        # Actually n is the count we replaced; PAT in `out` should not match anywhere
        # if all `procedure` were in code spans.
        # Use a different metric: delta-line-count is unreliable; compute matches
        # restricted to code spans.
        n_code = 0
        for kind, text in LS5.split_into_spans(src):
            if kind == CODE:
                n_code += len(PAT.findall(text))
        total_replacements += n_code
        changed += 1
        if not args.quiet:
            print(f"{'CHG ' if args.apply else 'WOULD-CHG'} {path}  ({n_code} replacement{'s' if n_code != 1 else ''})")
        if args.apply:
            path.write_text(out, encoding="utf-8")

    suffix = "applied" if args.apply else "would-apply (dry-run)"
    print(f"\n{changed} files changed, {total_replacements} replacements {suffix}.")
    if not args.apply:
        print("Re-run with --apply to write.")
    return 0


# ────────────────────────────────────────────────────────────────────
# Inline self-tests
# ────────────────────────────────────────────────────────────────────

def _test():
    cases = [
        # (input, expected)
        ("procedure foo() { return; }", "function foo() { return; }"),
        ("procedure foo() {}\nprocedure bar() {}",
         "function foo() {}\nfunction bar() {}"),
        # comment preserves verbatim
        ("// procedure body\nprocedure foo() {}",
         "// procedure body\nfunction foo() {}"),
        # block comment preserves verbatim
        ("/* procedure foo */ procedure foo() {}",
         "/* procedure foo */ function foo() {}"),
        # strings preserve verbatim
        ('s = "procedure"; procedure foo() {}',
         's = "procedure"; function foo() {}'),
        # idempotent
        ("function foo() { return; }", "function foo() { return; }"),
        # mixed
        ("procedure foo() {\n  // call procedure\n  bar();\n}",
         "function foo() {\n  // call procedure\n  bar();\n}"),
    ]
    failed = 0
    for i, (inp, want) in enumerate(cases):
        got = migrate_text(inp)
        if got != want:
            failed += 1
            print(f"FAIL test {i}:")
            print(f"  input:  {inp!r}")
            print(f"  want:   {want!r}")
            print(f"  got:    {got!r}")
    if failed:
        print(f"\n{failed}/{len(cases)} self-tests failed")
        return 1
    print(f"OK  {len(cases)}/{len(cases)} self-tests passed")
    return 0


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "--self-test":
        sys.exit(_test())
    sys.exit(main())

> MOVED 2026-11-12 by the cfo (row tests-consolidation-finish-cfo) from corpus/tests/prolog/parser/KEEP.md, beside the other languages' parser fixtures (harness/fixtures/parser_icon, the parser_snobol4 precedent, CIO-56): two programs that are parsed, never run, so no oracle answers them.

# KEEP.md — tests/prolog/parser

Per `suite-harness-lang-configs` (parent: `corpus-suites-consolidation`). 134 of 136 `.pl` fixtures
converted into `corpus/tests/prolog/parser.pl` / `.ref` (2026-08-27, `--lang prolog`, `modes=ast`).
The 2 below stay loose, deliberately.

## Category — `--dump-ast` produces empty output, no AST node built (2)

Both are a bare non-callable term used as a top-level clause: `42.` (a bare integer) and `X.` (a bare
unbound variable). `scrip --dump-ast` exits 0 with no output for either — not a crash, not a parse
error, just nothing printed. `convert-blocks` never considered them (no `.ref` was written, so
`discover_pairs` did not find them as pairs) rather than converting an empty reference. Whether SCRIP's
parser *should* build some AST node here (SWI/GNU Prolog would raise `type_error(callable, ...)` at
call time, but these files are never executed, only parsed) is a parser-shape question, not a
harness-wiring one — own row if anyone wants to chase it.

| file | reason |
|---|---|
| atom_int.pl | bare integer `42.` as clause head — empty `--dump-ast` output |
| atom_var.pl | bare variable `X.` as clause head — empty `--dump-ast` output |

## Re-running this classification

`./scrip --dump-ast tests/prolog/parser/<file>.pl` — re-run fresh rather than trusting this table,
per this project's standing rule that a fast-moving tree makes yesterday's board stale within hours.

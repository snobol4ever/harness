# KEEP.md — harness/fixtures/parser_pascal (was corpus/tests/pascal/parser; moved by the coo 2026-11-10, CIO-42, CIO-56)

Thirteen dialect witnesses for the Pascal dialect switch (CEO-1614; `.github/ARCH-PASCAL-DIALECTS.md` section 2) and four witnesses of gaps in `bootstrap/parser_pascal.sc` (the last two sections), one program each, kept loose on purpose.
They have no `.ref` and no `ALL.csv` row: they are never run, only parsed. Their grader is the tree gate, `test_gate_snocone_parsers_match_the_c_parsers_tree_for_tree.sh`
(and `util_parser_grid.sh`), which read every `.pas` of this folder (GATE_POPULATION=fixtures, or with the corpus population under the closure run) and require the C parser (`out/parser_pascal`) and
`bootstrap/parser_pascal.sc` to print the same tree hash for each file, or both to print `Parse Error`. Same shape as `tests/icon/parser` and `tests/raku/parser`.
Each file is the smallest program whose parse depends on the dialect; its `{$mode}` directive says which, and the C parser (`pascal.l`
`pascal_mode_directive`, `pascal_oo_keyword`, `pascal_context_keyword`) is the oracle.

## Explicit `{$mode iso}` refuses what ISO 7185 does not have (C: both lexer functions return 0 when the dialect is ISO)

- `dialect_iso_uses.pas` — `uses crt;`: C refuses, `uses` is a plain identifier under iso.
- `dialect_iso_class.pas` — `type c = class end;`: C refuses.
- `dialect_iso_try.pas` — `try ... finally ... end`: C refuses.
- `dialect_iso_unit.pas` — `unit u; interface implementation`: C refuses.

## objfpc and delphi reserve the object words (class try raise inherited constructor destructor property is as); fpc and the default do not

- `dialect_objfpc_program_is.pas` — `program is;` under objfpc: C refuses.
- `dialect_objfpc_var_is.pas` — `var is: integer;` under objfpc: C refuses.
- `dialect_objfpc_const_class.pas` — `const class = 1;` under objfpc: C refuses.
- `dialect_delphi_var_is.pas` — `var is: integer;` under delphi: C refuses.
- `dialect_fpc_var_property.pas` — `var property: integer;` under fpc: an identifier, both print a tree.
- `dialect_nomode_var_is.pas` — `var is: integer;` with no directive: an identifier, both print a tree.

## Where the mode directive sits

- `dialect_objfpc_after_program_var_is.pas` — `program t;` then `{$mode objfpc}` then `var is: integer;`, the shape of 202 of the 275 corpus files that carry a directive (a scan of 2026-10-28): the directive applies to the rest of the program, so C refuses `is`.
- `dialect_objfpc_after_uses.pas` — `uses crt;` BEFORE the directive: the `uses` flips the default to FPC (a `seen_mode` pragma event) and the directive then sets objfpc and raises its own, so the tree carries the `seen_mode` pragma marks of both (three in all with the program stamp); with `rosetta-pascal/amicable-pairs-1.pas` it is the one file shape where a dialect fixed before the match drops an event.
- `dialect_mode_after_decl_ignored.pas` — a `{$mode objfpc}` after the first `var` is a pragma event only; C honours the directive only before the first declaration.

## Two gaps of parser_pascal.sc, each a program the C parser parses (hq_snocone, 2026-10-29, the ceo's order)

- `switch_push_pop_restores_h.pas` — `{$H+}` then two nested `{$push}` / `{$pop}` pairs around `{$H-}` and `{$H+}`: the C lexer saves and restores the switch state (`pascal_sw_push` / `pascal_sw_pop`), so `string` under H+ carries the `ansistr` pragma child in `a` and `c` and not in `b`. The nesting is the point: a one-cell save restores `c` wrong.
- `stmt_designator_field_chain_call.pas` — `d.a.f(1);` and `d.a.b.f;` as statements: a designator with a field step before the called name. The .sc `MethodStmt` took the shortest prefix (`d.a`), the statement then ended short of `.f(1)`, and the cut after a finished statement list (`compound_cmd_rest` FENCE) forbade the retry; `MethodStmt` now refuses to end before a `.`.

## Call statements the C grammar parses by call_with_args and recv_primary (hq_snocone, 2026-10-29; pascal.y, hq_pascal's SCRIP 5b323919d)

- `stmt_designator_call_in_chain.pas` — a call in the MIDDLE of a statement's designator: `d.a(1).f(2);`, `d.a(1)[2].f(3);`, `d.a(1)^.f(2);`, `d.a.f(1).g(2);` (pascal.y call_with_args PERIOD IDENT LPARENT ... and call_with_args LBRACK / ARROW). The .sc's MethodStmt took the shortest prefix and its call prefix had no steps; a new CallStmt reads the expression grammar's own primary and postfixes and insists the chain ends in the `)` of a call.
- `stmt_receiver_literal_or_paren.pas` — a string literal or a parenthesised expression as the receiver: `'a'.F(1);`, `('abc' + 'd').Show(1, 2);`, `(s).Bar();`, `(s).F.G;`, `'a'.F.G(2);`. A bare final member needs one `.F` step after the receiver (`(s).F;` and `'a'.F;` are refused by C and by the .sc).

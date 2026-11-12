# KEEP.md — harness/fixtures/parser_raku (was corpus/tests/raku/parser-coverage; moved by the cfo 2026-11-12, the tests/raku consolidation, on the coo's ruling of 10:1x CST)

Two parse-coverage programs that no oracle answers, so they cannot be entries of the raku master (NO_ORACLE_ANSWER, CEO-1696), and no test is deleted
(Lon 2026-11-12). They have no `.ref` and no `ALL.csv` row: they are parsed, never graded against rakudo. Their grader is the tree gate,
`test_gate_snocone_parsers_match_the_c_parsers_tree_for_tree.sh` (GATE_POPULATION=fixtures reads every `.raku` here): the C parser and
`bootstrap/parser_raku.sc` must print the same tree for each, or both refuse.

- `stmt_ctrl_loop_inf.raku` — `loop { say "tick"; }`: never ends; rakudo 2026.05 timed out under util_add_ladder_witness.py's cut (MEASURED 2026-11-12).
- `stmt_pfx_start.raku` — `start { say("async"); }`: the answer races the program's exit; rakudo printed `async` in 11 of 12 runs and nothing in 1
  (MEASURED 2026-11-12, twelve runs of raku_oracle_run.sh). S17 (concurrency) is closed until Lon opens it.

The other 95 programs of that folder and of parser/ and parse_census/ are entries of the raku master (corpus d2f821568).

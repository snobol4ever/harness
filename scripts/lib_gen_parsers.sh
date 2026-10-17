#!/usr/bin/env bash
# lib_gen_parsers.sh -- THE ONE TABLE OF GRAMMAR GENERATION INVOCATIONS, shared by the regenerator and the gate that grades it.
# Extracted 2026-09-04 (hq_T, row parser-sources-and-generated-files-in-sync-gate-in-make-test) from
# regenerate_parser_and_lexer_from_sources.sh, which held the only copy. Consumers: that script, and
# test_gate_parser_generated_files_in_sync.sh.
# ⛔ WHY THIS IS A SHARED BODY AND NOT A SECOND COPY IN THE GATE. The gate's whole claim is "the committed output matches what the
# pinned tools produce from the source". A gate carrying its OWN copy of the invocations grades the source against the GATE'S idea of
# the flags, not the regenerator's -- so the day someone adds a sixth grammar, or changes raku's `--warnings=none`, the two tables
# disagree and the gate is either falsely red or (worse) silently not grading a grammar at all. One table, two readers, no drift.
# Same ruling, and the same reasoning, as lib_ladder.sh and lib_port_trace.sh.
# ⛔ THE FLAGS ARE LOAD-BEARING AND ARE NOT STYLE. Each row generates from INSIDE its own parser directory with the output's BARE
# basename, because bison bakes the input path into #line and the output basename into an #include and an include guard -- generating
# from anywhere else rewrites every committed file with pure path noise (GOAL-STYLE-200COL R4 measured it: 10 files, 4 non-#line
# lines). `flex --noline` is what keeps the lexer outputs path-free entirely. Change a flag here and the committed outputs must be
# regenerated in the same commit.
# ⛔ THE OUTPUT NAMES ARE NOT DERIVABLE FROM THE SOURCE NAMES -- rebus.l produces `lex.rebus.c`, not `rebus.lex.c`, while every other
# lexer takes the `<name>.lex.c` form. A consumer that computes the twin from the source name instead of reading it from this table
# grades eight of nine grammars and reports the ninth as absent, which reads exactly like a clean census.
# The Snocone lexer is a hand-written FSM (snocone_lex.c) and has no .l; Icon and Prolog are hand-written recursive-descent parsers
# with no grammar at all, which is why this table has five parser dirs and not seven.
# ⛔⭐⭐⭐ THE POST-PROCESS IS PART OF GENERATION, NOT A SEPARATE PASS OVER THE TREE (ceo CEO-851).  bison and flex emit a skeleton that calls
# malloc and free and includes <malloc.h>, and RULES.md line 29 forbids every libc allocation in every file of this tree, GENERATED OUTPUT
# INCLUDED, because a generated file that is committed is source and Lon's acceptance test is a grep over the whole base.  The CEO-842 sweep
# rewrote the committed outputs and DID NOT wire this, so `regenerate_parser_and_lexer_from_sources.sh` put the four names back and the
# in-sync gate went RED on all NINE generated files at SCRIP 36f0edab5 -- committed output ct_alloc against fresh output malloc, 12 to 132
# non-#line lines apiece.  It lives HERE rather than in the regenerator for the same reason the invocation table does: the gate regenerates
# into a scratch tree and diffs, so a post-process only the regenerator applied would make the gate red forever on exactly the difference
# the post-process exists to create.  One table, one post-process, two readers, no drift.
gen_postprocess() { python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_sweep_c_allocators.py" --apply "$@" >/dev/null; }
GEN_BISON_PIN=3.8.2
GEN_FLEX_PIN=2.6.4
# gen_parsers_table -- one row per generation step: <parser-dir> TAB <source basename> TAB <primary output basename> TAB <command>.
# The command is run with the parser directory as cwd. A bison row with -d also produces the matching .tab.h; consumers discover that
# by looking at what the run actually produced rather than by predicting it here.
gen_parsers_table() {
    printf '%s\t%s\t%s\t%s\n' \
        snobol4 snobol4.y       snobol4.tab.c       "bison -d -o snobol4.tab.c snobol4.y" \
        snobol4 snobol4.l       snobol4.lex.c       "flex --noline -o snobol4.lex.c snobol4.l" \
        snocone snocone_parse.y snocone_parse.tab.c "bison -d -o snocone_parse.tab.c snocone_parse.y" \
        rebus   rebus.y         rebus.tab.c         "bison -d -o rebus.tab.c rebus.y" \
        rebus   rebus.l         lex.rebus.c         "flex --noline -o lex.rebus.c rebus.l" \
        pascal  pascal.y        pascal.tab.c        "bison -d -o pascal.tab.c pascal.y" \
        pascal  pascal.l        pascal.lex.c        "flex --noline -o pascal.lex.c pascal.l"
}

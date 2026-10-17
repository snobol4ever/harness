#!/usr/bin/env bash
# regenerate_parser_and_lexer_from_sources.sh -- regenerate the committed bison/flex outputs from their .y/.l sources.
# Run after editing any .y or .l; commit the source and its generated .tab.c/.tab.h/.lex.c together (the outputs are committed so a normal
# build never needs bison/flex). Every parser is generated from INSIDE its own directory with the output's bare basename: bison bakes the
# input path into #line and the output basename into an #include and an include guard, so generating from anywhere else rewrites every
# committed file with pure path noise (GOAL-STYLE-200COL R4 measured it: 10 files, 4 non-#line lines; snobol4.tab.h carried a
# SRC_PARSER_ guard from a root-relative run for months). The Snocone lexer is a hand-written FSM (snocone_lex.c), not a flex source.
# ⛔ A generated file is NEVER hand-edited: the June 2026 dead-code sweeps pruned lex.rebus.c and snocone_parse.tab.c by hand, and from then
# on neither could be reproduced from its source (hq_B 2026-09-02 FINDING). Cure at the SOURCE (%option noinput nounput; delete the dead
# helper from the .y) and regenerate; prove it with ../harness/scripts/util_style200_oracle_yl.sh.
# Tools: bison 3.8.2 / flex 2.6.4 -- gen_tools_ready (lib_build_flags.sh) resolves BISON_PKGDATADIR for the rootless ~/.local install and
# PROVES bison generates before anything is touched. Usage: bash ../harness/scripts/regenerate_parser_and_lexer_from_sources.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SCRIP="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_build_flags.sh"
. "$HERE/lib_gen_parsers.sh"
gen_tools_ready || exit 2
echo "OK  bison $BF_BISON_VERSION, flex $BF_FLEX_VERSION${BISON_PKGDATADIR:+ (BISON_PKGDATADIR=$BISON_PKGDATADIR)}"
P="$SCRIP/src/parsers"
# ⛔ THE INVOCATION TABLE MOVED TO ../harness/scripts/lib_gen_parsers.sh (hq_T 2026-09-04) and this script is now one of its TWO readers -- the
# other is test_gate_parser_generated_files_in_sync.sh, which grades the committed outputs against exactly these commands. It was one
# table with one reader; a gate that carried its own copy would grade the tree against a second, silently drifting idea of the flags.
gen() { echo "GEN $1/$2"; ( cd "$P/$1" && eval "$3" ); gen_postprocess "$P/$1/$2" $( [ -f "$P/$1/${2%.c}.h" ] && echo "$P/$1/${2%.c}.h" ); }
while IFS=$'\t' read -r d src out cmd; do gen "$d" "$out" "$cmd"; done < <(gen_parsers_table)
echo "DONE -- generated files now differing from HEAD (empty = the committed outputs already match their sources):"
git -C "$SCRIP" status --short -- src/parsers | grep -E '\.tab\.[ch]|\.lex\.c|lex\.[a-z]+\.c' | sed 's/^/   /' || true
echo "commit .y/.l and their outputs together; prove object identity with: bash ../harness/scripts/util_style200_oracle_yl.sh src/parsers/*/*.y src/parsers/*/*.l"

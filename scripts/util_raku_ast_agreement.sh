#!/usr/bin/env bash
# util_raku_ast_agreement.sh -- does the new Raku parser build the tree the flex/bison parser builds?
#   The entry point row raku-the-new-parser-builds-the-tree-... (CEO-1289 phase 2) names in its DONE-WHEN; the body
#   is util_raku_ast_agreement.py beside it (its docstring is the contract). Prints
#   RAKU_AST_AGREEMENT population=N identical=I excepted=E differ=D; rc 0 when D == 0, 1 when D > 0, 2 when it
#   could not measure. `--cut` cuts the reference from the old parser; `--flag F` names the subject's dump flag.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$HERE/util_raku_ast_agreement.py" "$@"

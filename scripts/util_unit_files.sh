#!/usr/bin/env bash
# util_unit_files.sh SRC_ROOT REL -- the files that hold SCRIP/src/REL now (DESIGN-PLAN cache-tree, CTO-636, law C8): REL itself, or the head, export
# headers and pieces its cut wrote (harness/designs/cache_tree/SPLITS.tsv), one per line. rc 2 when neither exists. A shell reader of an old unit path:
#   files=$(bash "$HERE/util_unit_files.sh" "$ROOT/src" runtime/by_name_dispatch.c) || exit 2; cat $files | grep -c PATTERN
exec python3 "$(dirname "${BASH_SOURCE[0]}")/lib_split_units.py" "$@"

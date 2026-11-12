#!/usr/bin/env bash
# gprolog_oracle_run.sh SRC -- THE ONE-STEP GNU PROLOG ORACLE for a GNU-dialect witness of the Prolog master (the cto 2026-11-12, row tests-folder-consolidation-cto):
# GNU Prolog 1.6.0 through gprolog_bin() in lib_oracle_flags.sh (never a bare gprolog, test_gate_no_bare_gprolog_or_gplc_outside_the_accessors.sh) consults a
# scratch copy of SRC with --consult-file and --query-goal halt, from that scratch directory with the caller's stdin, as test_design_prolog_gnu_gaps_steps.sh
# --cut does; its stdout passes through gprolog_output_filter (the banner, the consult lines and the toplevel prompt are the oracle's, not the program's) and
# its exit code is gprolog's. A missing oracle exits 127.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_oracle_flags.sh" || exit 127
G="$(gprolog_bin)" || exit 127
src="${1:-}"; [ -f "$src" ] || { echo "gprolog_oracle_run.sh: no such file: $src" >&2; exit 127; }
shift
work=$(mktemp -d) || exit 127
trap 'rm -rf "$work"' EXIT
cp "$src" "$work/$(basename "$src")"
cd "$work" || exit 127
"$G" --consult-file "$(basename "$src")" --query-goal halt "$@" | gprolog_output_filter
exit "${PIPESTATUS[0]}"

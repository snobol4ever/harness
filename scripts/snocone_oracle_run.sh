#!/bin/bash
# ONE-STEP SNOCONE ORACLE DRIVER (hq_snocone 2026-10-21, cfo's ask on the ten fakeable SncRungs entries). resolve_oracle_bin()/run_oracle() in
# corpus_suite_harness.py invoke every oracle as a SINGLE process: `<oracle_bin> <flags...> <bare-filename>`, cwd already set to the source file's own
# directory. Snocone has no implementation of its own to rival SCRIP, so SPITBOL grades it (lib_oracle_flags.sh sbl_correctness_bin; the grade side's
# mapping is corpus_suite_harness.py _fatal_render_voice_for: snobol4 and snocone both "spitbol"): this wrapper supplies the missing first half --
# scrip --transpile carries the entry's statements across to SNOBOL4 text in a private tmpdir (never beside the source), then sbl -bf RUNS THAT TEXT and
# its stdout and rc are the ref's. The transpiler only translates; the answer is SPITBOL's, never SCRIP's own run. stdin reaches sbl untouched. A
# transpile that fails or writes nothing prints scrip's diagnostic to stderr and exits 126 (never a silent empty ref); sbl's own flags come from the lib.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_oracle_flags.sh" || exit 127
SCRIP_BIN="${SCRIP:-$HERE/../../SCRIP/scrip}"
[ -x "$SCRIP_BIN" ] || { echo "snocone_oracle_run.sh: no scrip at $SCRIP_BIN -- make" >&2; exit 127; }
SBL="$(sbl_correctness_bin)" || exit 127
FLAGS="$(sbl_lang_flags)"
while [ $# -gt 1 ]; do shift; done
src="$1"
[ -f "$src" ] || { echo "snocone_oracle_run.sh: no such file: $src" >&2; exit 127; }
src="$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"
work=$(mktemp -d) || exit 127
trap 'rm -rf "$work"' EXIT
"$SCRIP_BIN" --transpile "$src" < /dev/null > "$work/prog.sno" 2> "$work/transpile.log"
rc=$?
if [ $rc -ne 0 ] || [ ! -s "$work/prog.sno" ]; then
    cat "$work/transpile.log" >&2
    exit 126
fi
cd "$work" && exec "$SBL" $FLAGS prog.sno

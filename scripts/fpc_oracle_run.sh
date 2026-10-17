#!/bin/bash
# ONE-STEP FPC ORACLE DRIVER (seat02 2026-09-06, row pascal-every-non-package-source-...-with-oracle-refs).
# resolve_oracle_bin()/run_oracle() in corpus_suite_harness.py invoke every oracle as a SINGLE process:
# `<oracle_bin> <flags...> <bare-filename>`, cwd already set to the source file's own directory (icon_bin's
# own precedent: the shared `icon` binary compiles-and-runs in one step). FPC has no such one-step mode --
# it only compiles -- so this wrapper supplies the missing "and run it" half: compile to a private tmpdir
# (never the source directory -- a stray .o/.ppu beside a corpus source is not an acceptable side effect of
# grading it), then exec the result, inheriting this process's own stdin/stdout so run_oracle's stdin_text
# feed (when the caller supplies one) reaches the compiled program exactly as it would a real single-binary
# oracle. Compile failure prints fpc's own diagnostic to stderr and exits 126 (never silently "ran empty").
set -u
work=$(mktemp -d) || exit 127
trap 'rm -rf "$work"' EXIT
flags=()
while [ $# -gt 1 ]; do flags+=("$1"); shift; done
src="$1"
[ -f "$src" ] || { echo "fpc_oracle_run.sh: no such file: $src" >&2; exit 127; }
name="${src%.*}"
/usr/bin/fpc "${flags[@]}" -o"$work/$name" "$src" < /dev/null > "$work/compile.log" 2>&1
rc=$?
if [ $rc -ne 0 ] || [ ! -x "$work/$name" ]; then
    cat "$work/compile.log" >&2
    exit 126
fi
exec "$work/$name"

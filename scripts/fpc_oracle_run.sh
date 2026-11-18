#!/bin/bash
# ONE-STEP FPC ORACLE DRIVER (seat02 2026-09-06, row pascal-every-non-package-source-...-with-oracle-refs).
# resolve_oracle_bin()/run_oracle() in corpus_suite_harness.py invoke every oracle as a SINGLE process:
# `<oracle_bin> <flags...> <bare-filename>`, cwd already set to the source file's own directory (icon_bin's
# own precedent: the shared `icon` binary compiles-and-runs in one step). FPC has no such one-step mode --
# it only compiles -- so this wrapper supplies the missing "and run it" half: compile to a private tmpdir
# (never the source directory -- a stray .o/.ppu beside a corpus source is not an acceptable side effect of
# grading it), then exec the result, inheriting this process's own stdin/stdout so run_oracle's stdin_text
# feed (when the caller supplies one) reaches the compiled program exactly as it would a real single-binary
# oracle. The binary and every unit object go to the tmpdir (-FU, the basename), so an absolute source path works and
# nothing lands beside the source. Compile failure prints fpc's own diagnostic to stderr and exits 126 (never silently "ran empty").
set -u
work=$(mktemp -d) || exit 127
trap 'rm -rf "$work"' EXIT
flags=()
# THE PROGRAM'S OWN ARGUMENTS FOLLOW A -- AFTER THE SOURCE (the grader 2026-11-18, for the Benchmarks Game's sizes: binarytrees 10, nbody 1000): fpc_oracle_run.sh
# [FPC-FLAGS] SRC [-- ARG...]; with no -- every word but the last is a flag, as before.
pargs=(); _all=("$@"); for ((_i=0; _i<${#_all[@]}; _i++)); do [ "${_all[$_i]}" = -- ] && { pargs=("${_all[@]:$((_i+1))}"); set -- "${_all[@]:0:$_i}"; break; }; done
while [ $# -gt 1 ]; do flags+=("$1"); shift; done
src="$1"
[ -f "$src" ] || { echo "fpc_oracle_run.sh: no such file: $src" >&2; exit 127; }
name="$(basename "${src%.*}")"
/usr/bin/fpc "${flags[@]}" -FU"$work" -o"$work/$name" "$src" < /dev/null > "$work/compile.log" 2>&1
rc=$?
if [ $rc -ne 0 ] || [ ! -x "$work/$name" ]; then
    cat "$work/compile.log" >&2
    exit 126
fi
# THE ANSWER IS CUT WITH C STDIO LINE-BUFFERED (the coo 2026-11-14, row rosetta-pascal-paraffins-1-ref-is-recut-with-stdout-flushed; MEASURED: paraffins-1 writes through
# libgmp's C stdio (mp_printf) and fpc's exit does not flush it, so its ref was 483 of 500 lines, 53249 bytes (13 x 4096 + 1), the last line cut mid-number; under stdbuf -oL
# fpc prints every line, twice equal). stdbuf touches C stdio alone: a program that writes only through the Pascal RTL answers byte for byte as before.
if command -v stdbuf > /dev/null 2>&1; then exec stdbuf -oL "$work/$name" "${pargs[@]}"; fi
exec "$work/$name" "${pargs[@]}"

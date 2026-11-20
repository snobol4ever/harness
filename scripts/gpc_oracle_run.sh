#!/bin/bash
# ONE-STEP GNU PASCAL ORACLE DRIVER (the grader 2026-11-20; Lon, in the grader's window: "Yes, build gpc and cut a sample" / "keep on cutting, grading, and scoring.").
# The twin of fpc_oracle_run.sh for GNU Pascal (gpc 20070904 on gcc-3.4.6, gpc_bin of lib_oracle_flags.sh, its build BUILD.md beside it): compile to a private
# tmpdir, units, objects and the binary included (--unit-destination-path, --object-destination-path), so nothing lands beside the source and a mined folder's
# scratch copy is never changed; then exec the result with this process's stdin. Compile failure prints gpc's diagnostic to stderr and exits 126.
# FLAGS: the caller's, then the program's own declaration in GPC's test-suite form, a comment line `{ FLAG ... }` or `(* FLAG ... *)` (p/test/test_run reads
# it the same way; MEASURED: 5105 of the suite's programs carry none, and a program with none compiles under the base flags alone). The base flags are
# test_run's own PFLAGS without -g: --automake -O3 -W -Wall -Wno-unused.
# usage: gpc_oracle_run.sh [GPC-FLAGS] SRC [-- ARG...]
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_oracle_flags.sh"
gpc="$(gpc_bin)" || exit 127
work=$(mktemp -d) || exit 127
trap 'rm -rf "$work"' EXIT
flags=()
pargs=(); _all=("$@"); for ((_i=0; _i<${#_all[@]}; _i++)); do [ "${_all[$_i]}" = -- ] && { pargs=("${_all[@]:$((_i+1))}"); set -- "${_all[@]:0:$_i}"; break; }; done
while [ $# -gt 1 ]; do flags+=("$1"); shift; done
src="$1"
[ -f "$src" ] || { echo "gpc_oracle_run.sh: no such file: $src" >&2; exit 127; }
name="$(basename "${src%.*}")"
own=$(grep -E '(\{|\(\*) *FLAG ' "$src" | sed -e 's/.*FLAG *//;s/ *\*).*//;s/ *}.*//')
dir="$(cd "$(dirname "$src")" && pwd)"
# shellcheck disable=SC2086
"$gpc" --automake -O3 -W -Wall -Wno-unused --unit-path="$dir" -I "$dir" --unit-destination-path="$work" --object-destination-path="$work" \
    --executable-path="$work" "${flags[@]}" $own -o "$work/$name" "$src" < /dev/null > "$work/compile.log" 2>&1
rc=$?
if [ $rc -ne 0 ] || [ ! -x "$work/$name" ]; then
    sed "s|$work/||g" "$work/compile.log" >&2
    exit 126
fi
if command -v stdbuf > /dev/null 2>&1; then exec stdbuf -oL "$work/$name" "${pargs[@]}"; fi
exec "$work/$name" "${pargs[@]}"

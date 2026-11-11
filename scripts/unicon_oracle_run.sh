#!/usr/bin/env bash
# unicon_oracle_run.sh SRC -- THE ONE-STEP UNICON ORACLE for a Unicon witness (the coo 2026-11-04, Lon: "do the RUNGS for Unicon"). It is the Pascal
# wrapper's shape (fpc_oracle_run.sh): compile SRC with the Unicon translator through unicon_bin() in lib_oracle_flags.sh (never a bare `unicon`,
# test_gate_no_bare_unicon_outside_the_accessor.sh) into a scratch directory, then exec the result with the caller's stdin, so its stdout and exit code
# are the program's own. A compile failure exits 126 with the translator's text on stderr; a missing oracle exits 127.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_oracle_flags.sh" || exit 127
U="$(unicon_bin)" || exit 127
# --here SRC (the coo 2026-11-11, the miner's Icon arm): SRC is translated where it stands, in the caller's current directory (a scratch copy of the
# program's own folder, so the files it links from that folder are found), the executable goes to the private directory, and the program runs from
# the caller's directory with the caller's stdin. The translator's .u files land in that scratch copy, never beside a collection's source.
if [ "${1:-}" = --here ]; then
    src="${2:-}"; [ -f "$src" ] || { echo "unicon_oracle_run.sh: no such file: $src" >&2; exit 127; }
    work=$(mktemp -d) || exit 127
    trap 'rm -rf "$work"' EXIT
    name="$(basename "${src%.*}")"
    "$U" -s "$src" -o "$work/$name" < /dev/null > "$work/compile.log" 2>&1
    if [ ! -x "$work/$name" ]; then cat "$work/compile.log" >&2; exit 126; fi
    "$work/$name"; exit $?
fi
src="${1:-}"; [ -f "$src" ] || { echo "unicon_oracle_run.sh: no such file: $src" >&2; exit 127; }
work=$(mktemp -d) || exit 127
trap 'rm -rf "$work"' EXIT
name="$(basename "${src%.*}")"
cp "$src" "$work/$name.icn"
( cd "$work" && "$U" -s "$name.icn" -o "$name" < /dev/null > "$work/compile.log" 2>&1 )
if [ ! -x "$work/$name" ]; then cat "$work/compile.log" >&2; exit 126; fi
cd "$work" && "./$name"

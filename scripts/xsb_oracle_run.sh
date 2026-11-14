#!/usr/bin/env bash
# xsb_oracle_run.sh SRC -- THE ONE-STEP XSB ORACLE for an XSB-dialect witness of the Prolog master (row xsb-dialect-a-call-of-a-dynamic-predicate-sees-the-immediate-update-view, senior_05 2026-11-14):
# XSB 5.0.0 through xsb_bin() in lib_oracle_flags.sh (never a bare xsb) consults a scratch copy of SRC from that scratch directory with the caller's stdin, banner and prompt off,
# and halts; its stdout is the program's own, its exit code is xsb's. A missing oracle exits 127.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_oracle_flags.sh" || exit 127
X="$(xsb_bin)" || exit 127
src="${1:-}"; [ -f "$src" ] || { echo "xsb_oracle_run.sh: no such file: $src" >&2; exit 127; }
shift
work=$(mktemp -d) || exit 127
trap 'rm -rf "$work"' EXIT
cp "$src" "$work/prog.pl"
cd "$work" || exit 127
"$X" --nobanner --noprompt --quietload -e "consult(prog), halt." "$@"
exit $?

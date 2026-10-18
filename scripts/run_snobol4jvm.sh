#!/bin/bash
# run_snobol4jvm.sh [-dNk] [-sNk] [-u STR] name.sno [-- arg ...]   |   run_snobol4jvm.sh --binaries [--lang LANG]
# THE jvm ENGINE ARM (CEO-1822; Lon 2026-10-17, in-chat to hq_jvm, verbatim: "The suite banner should represent the snobol4jvm program,
# not SCRIP." · "I suspect getting the test harness and benchmarks to run is the first order of business."): run one SNOBOL4 program
# under snobol4jvm, the engine sibling at <root>/snobol4jvm, in the calling shape every port runner shares (hq_dotnet's proposal,
# CEO-1822): the harness's SPITBOL-shaped switches, the bare file name in the entry's own folder, stdin from the input sidecar, and the
# program's own argv after a bare --. The runner execs the engine; stdout, stderr and the exit code are the program's.
# THE SWITCHES ARE ACCEPTED AND NOT MAPPED, and each is a measured gap rather than a silent one: snobol4jvm has no heap cap (-d), its
# recursion depth is the JVM thread stack rather than a SPITBOL stack (-s), it has no HOST() for -u to feed, and its command line takes
# no program argv (everything after -- reaches no program). The JVM's own defaults stand until a measurement asks for more.
# stdout carries the program's OUTPUT and nothing else: the JVM's log goes to stderr at error level, so a stale class archive (a
# warning) never lands in a graded stream. build_snobol4jvm.sh records the archive; it is used only while it is at least as new as the jar.
# --binaries prints the graded file, one path per line (the jar): bin_fingerprint, the progress digest and the tree pin read it. It is
# the board's one check, called before the first entry: it refuses rc 2 for a language snobol4jvm has no front end for (--lang, default
# snobol4), and when the jar is missing or older than the snobol4jvm source it would stand for, so no board grades a stale build.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SJ="$(cd "$HERE/../.." && pwd)/snobol4jvm"
J="$(ls -t "$SJ"/target/uberjar/*-standalone.jar 2>/dev/null | head -1)"
[ -f "$J" ] || { echo "⛔ REFUSE(rc=2): no snobol4jvm jar under $SJ/target/uberjar -- build it: bash $HERE/build_snobol4jvm.sh" >&2; exit 2; }
if [ "${1:-}" = "--binaries" ]; then
  lang=snobol4; [ "${2:-}" = --lang ] && lang="${3:-}"
  [ "$lang" = snobol4 ] || { echo "⛔ run_snobol4jvm.sh: NO ENGINE for $lang -- snobol4jvm's command line runs SNOBOL4 source only (its src holds a Snocone lexer and expression emitter that nothing calls, and nothing of Rebus)" >&2; exit 2; }
  newer="$(find "$SJ/src" -name '*.clj' -newer "$J" -print -quit 2>/dev/null)"; [ "$SJ/project.clj" -nt "$J" ] && newer="$SJ/project.clj"
  [ -z "$newer" ] || { echo "⛔ REFUSE(rc=2): the snobol4jvm jar $J is older than $newer -- rebuild: bash $HERE/build_snobol4jvm.sh" >&2; exit 2; }
  printf '%s\n' "$J"; exit 0
fi
while [ $# -gt 0 ]; do
  case "$1" in
    -d*|-s*) shift ;;
    -u) shift 2 ;;
    --) echo "⛔ REFUSE(rc=2): no program file before --" >&2; exit 2 ;;
    *) break ;;
  esac
done
[ $# -ge 1 ] || { echo "⛔ REFUSE(rc=2): usage: $0 [-dNk] [-sNk] [-u STR] name.sno [-- arg ...] | --binaries" >&2; exit 2; }
prog="$1"; shift
[ "${1:-}" = "--" ] && shift
A="${J%.jar}.jsa"
cds=(); [ -f "$A" ] && ! [ "$J" -nt "$A" ] && cds=("-XX:SharedArchiveFile=$A")
exec java -Xlog:disable -Xlog:all=error:stderr "${cds[@]}" -XX:+UseSerialGC -jar "$J" "$prog" "$@"

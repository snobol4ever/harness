#!/bin/bash
# run_port_as_scrip.sh [SCRIP's m3 command line: --run [switches] name.sno [-- arg ...]]
# THE PORT ENGINE IN SCRIP'S CALLING SHAPE (CEO-1822; Lon 2026-10-18, in-chat to hq_jvm, verbatim: "Get all SNOBOL4 test suite package
# runners working with snobol4jvm."): the SNOBOL4 package runners call the program they grade as "$SCRIP" --run [switches] prog, each with
# its own grading around that one line (live oracle diffs, masks, overlays). Under S4E_ENGINE=<port> one_runner_port_face names this file
# as their SCRIP, and it re-says the m3 call in the shape every port runner shares (run_<engine>.sh [-dNk] [-sNk] [-u STR] name [-- args]),
# the same argv corpus_suite_harness.py's _engine_argv builds. So a package runner grades a port with its own grading, untouched.
# THE VOCABULARY IS CLOSED: --run is m3 and is dropped; -dNk, -sNk and -u STR reach the port runner; --stlimit is SCRIP's own switch (a
# unit's compile_args, clause 8 (f)) and is dropped, as _engine_argv drops it, since SPITBOL and the ports always count statements;
# --compile is m4, SCRIP's compiled binary, which a port does not have: refused rc 2, so a runner that forgets to skip m4 under a port
# reads a refusal and never a grade. Any other switch is refused rc 2 by name, so no switch a runner passes is ever silently lost.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
e="${S4E_ENGINE:-scrip}"
case "$e" in dotnet) run=run_snobol4dotnet.sh;; jvm) run=run_snobol4jvm.sh;;
  *) echo "⛔ REFUSE(rc=2): run_port_as_scrip.sh: S4E_ENGINE=$e names no port engine (dotnet, jvm)" >&2; exit 2;; esac
sw=()
while [ $# -gt 0 ]; do
  case "$1" in
    --run|--stlimit) shift ;;
    -d?*|-s?*) sw+=("$1"); shift ;;
    -u) [ $# -ge 2 ] || { echo "⛔ REFUSE(rc=2): run_port_as_scrip.sh: -u takes a string" >&2; exit 2; }; sw+=(-u "$2"); shift 2 ;;
    --compile) echo "⛔ REFUSE(rc=2): run_port_as_scrip.sh: --compile is m4, SCRIP's compiled binary; the $e engine is graded in m3 alone" >&2; exit 2 ;;
    --) echo "⛔ REFUSE(rc=2): run_port_as_scrip.sh: no program file before --" >&2; exit 2 ;;
    -*) echo "⛔ REFUSE(rc=2): run_port_as_scrip.sh: $1 is not a switch this face carries to the $e engine (--run -dNk -sNk -u STR --stlimit)" >&2; exit 2 ;;
    *) break ;;
  esac
done
[ $# -ge 1 ] || { echo "⛔ REFUSE(rc=2): run_port_as_scrip.sh: no program file" >&2; exit 2; }
exec bash "$HERE/$run" "${sw[@]}" "$@"

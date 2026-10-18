#!/bin/bash
# build_snobol4jvm.sh -- build snobol4jvm, the engine sibling at <root>/snobol4jvm, for the harness to run (Lon 2026-10-17, in-chat to
# hq_jvm, verbatim: "The suite banner should represent the snobol4jvm program, not SCRIP." · "I suspect getting the test harness and
# benchmarks to run is the first order of business.").
# It runs lein uberjar (core is AOT-compiled, about 1.4 s a start), then records an AppCDS class archive beside the jar from one warm-up
# run (about 1.0 s a start). run_snobol4jvm.sh uses the archive only while it is at least as new as the jar, so a jar rebuilt without
# this script is slower, never wrong. corpus_suite_harness.py --modes jvm refuses a jar older than the snobol4jvm source it was built from.
# Prints one BUILT line naming the tree, the jar and the archive; rc 2 on any refusal.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SJ="$(cd "$HERE/../.." && pwd)/snobol4jvm"
[ -f "$SJ/project.clj" ] || { echo "⛔ REFUSE(rc=2): no snobol4jvm checkout at $SJ"; exit 2; }
command -v lein >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2): no lein on the PATH"; exit 2; }
(cd "$SJ" && lein uberjar) || { echo "⛔ REFUSE(rc=2): lein uberjar failed in $SJ"; exit 2; }
J="$(ls -t "$SJ"/target/uberjar/*-standalone.jar 2>/dev/null | head -1)"
[ -f "$J" ] || { echo "⛔ REFUSE(rc=2): lein uberjar left no standalone jar under $SJ/target/uberjar"; exit 2; }
A="${J%.jar}.jsa"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
printf "        DEFINE('F(X)')         :(F_END)\nF       F = X                  :(RETURN)\nF_END   OUTPUT = F('snobol4jvm')\nEND\n" > "$W/warm.sno"
rm -f "$A"
out="$(cd "$W" && java -Xlog:disable -Xlog:all=error:stderr -XX:ArchiveClassesAtExit="$A" -jar "$J" warm.sno 2>&1)"
[ "$out" = snobol4jvm ] && [ -f "$A" ] || { echo "⛔ REFUSE(rc=2): the warm-up run printed [$out] or wrote no archive at $A"; exit 2; }
tree="$(git -C "$SJ" rev-parse --short HEAD)$( [ -n "$(git -C "$SJ" status --porcelain --untracked-files=no)" ] && echo +dirty)"
echo "BUILT snobol4jvm tree=$tree jar=$J archive=$A"

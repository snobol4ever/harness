#!/usr/bin/env bash
# test_gate_no_o2_arm_in_scripts.sh -- NO -O2 BUILDS OF SCRIP'S OWN RUNTIME, EVER (Lon s262 FACT RULE,
# RULES.md sec FACT RULES; Makefile:34 carries RT_OPT ?= -O0 verbatim).
#
# WHY THIS GATE EXISTS: test_gate_digest_matches_rules.sh polices the per-root CLAUDE.md digests, so a live
# -O2 arm could sit in ../harness/scripts/ indefinitely while every digest read clean. Two did: jcon_selfhost_build.sh
# (PERF=1 -> RTOPT='-O2 ...') and build_o2_working_snobol4.sh (make libscrip_rt RT_OPT="$O2"). A rule policed
# only where it is WRITTEN DOWN and never where it is EXECUTED is a rule about documents.
#
# SCOPE, AND WHY IT IS NARROWER THAN "any -O2 in ../harness/scripts/". The FACT RULE governs the optimisation level of
# SCRIP'S RUNTIME, not every compiler invocation a script makes. A bare grep for -O2 over ../harness/scripts/*.sh matches
# 26 files here, and the great majority are legitimate and MUST stay:
#   - gcc -O2 -o tools/bench_rusage        the measurement harness itself. Building the stopwatch at -O0 would
#                                          add the stopwatch's own cost to every benchmark number.
#   - fpc -O2 / rival oracles              the rival compiled at ITS released default, which is the whole
#                                          basis of a fair two-number three-angle comparison.
#   - build_monitor_ipc_sync_library.sh    a separate IPC helper .so, not libscrip_rt.
# So this gate refuses exactly what the rule forbids: an -O2 reaching SCRIP's runtime optimisation level via
# RT_OPT= / RTOPT=. A gate broader than its rule gets disabled by the first person it blocks for a good
# reason, and then it guards nothing at all.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT"
# REFUSES rc=2 WHEN IT CANNOT MEASURE -- never skip-as-success (RULES.md: a test that cannot measure refuses).
[ -d scripts ] || { echo "GATE REFUSED (rc=2): cannot see ../harness/scripts/ from $ROOT -- nothing was checked" >&2; exit 2; }
n=$(ls ../harness/scripts/*.sh 2>/dev/null | wc -l)
[ "$n" -gt 0 ] || { echo "GATE REFUSED (rc=2): ../harness/scripts/*.sh matched 0 files -- a green here would be an empty claim" >&2; exit 2; }
# DETECTION, in two stages, because the real offenders do not spell it literally. First cut of this gate
# matched the string -O2 near RT_OPT and got BOTH answers wrong at once: it flagged two lines of
# test_gate_digest_matches_rules.sh (that gate's own SEARCH PATTERNS for this very violation -- a detector, not
# a build) and it MISSED build_o2_working_snobol4.sh, whose arm reads RT_OPT="$O2" with -O2 assigned to $O2
# eleven lines earlier. A pattern that reports a detector and spares the offender is worse than no gate.
#   skip:    comment lines, and lines whose first non-blank character is a quote (a string ARGUMENT -- a grep
#            pattern or a documented example -- never a command).
#   stage A: shell variables assigned a literal -O2 in this file.
#   stage B: RT_OPT= / RTOPT= set to a literal -O2, or to a variable stage A found.
hits="$(awk '
  FNR==1 { delete o2var }
  { line=$0; sub(/^[ \t]+/,"",line) }
  line ~ /^#/ { next }
  line ~ /^["\x27]/ { next }
  match(line, /^[A-Za-z_][A-Za-z0-9_]*=/) {
      nm=substr(line, 1, RLENGTH-1)
      if (line ~ /-O2/) { o2var[nm]=1 }
  }
  {
      if (line ~ /(RT_OPT|RTOPT)=["\x27]?-O2/) { printf "%s:%d: %s\n", FILENAME, FNR, line; next }
      if (match(line, /(RT_OPT|RTOPT)=["\x27]?\$\{?[A-Za-z_][A-Za-z0-9_]*/)) {
          ref=substr(line, RSTART, RLENGTH); sub(/^.*\$\{?/,"",ref)
          if (ref in o2var) { printf "%s:%d: %s\n", FILENAME, FNR, line }
      }
  }
' ../harness/scripts/*.sh 2>/dev/null || true)"
if [ -n "$hits" ]; then
    echo "GATE FAIL (rc=1): a LIVE -O2 arm builds SCRIP's runtime -- the s262 FACT RULE says there are NO -O2 builds, EVER:" >&2
    echo "$hits" | sed 's/^/    /' >&2
    echo "  Cure the arm; do not add an exemption. RT_OPT is -O0 (Makefile:34)." >&2
    exit 1
fi
echo "GATE OK: $n ../harness/scripts/*.sh checked, 0 carry a live -O2 arm for SCRIP's runtime (RT_OPT stays -O0, Makefile:34)"
exit 0

#!/bin/bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the SNOBOL4 statement instrumentation (the --stlimit switch; Lon 2026-09-24 16:0x: the feature is off by default and never inferred from the source, the correctness graders turn it on because the oracle always has it)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ WITNESS GATE for the rung21 forms `only_errtype_fnclevel_and_stcount_may_be_traced` and
# `the_keyword_name_carries_no_ampersand` of row snobol4-ladder-every-feature-in-isolation-with-variations
# (cfo 2026-09-13).  SPITBOL manual Ch10 p.148: "Only keywords &ERRTYPE, &FNCLEVEL, and &STCOUNT may be
# traced.  The name is specified without an ampersand."  MEASURED on 71b32337f, BOTH modes: SCRIP accepted
# TRACE('ALPHABET','KEYWORD'), TRACE('&FNCLEVEL','KEYWORD') and STOPTR('ALPHABET','KEYWORD') silently and
# ran on, where `sbl -bf` raises ERROR 198 / ERROR 198 / ERROR 190 -- three programs that printed the
# success shape over a refusal.  These three forms CANNOT be rungs witnesses: the oracle answers each with
# a fatal listing carrying its own banner date (RULING R5), so they are graded here instead, through the
# sanctioned trace grader, which compares the ERROR NUMBER both implementations raise and never their text.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
PROBES="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}/.github/probes/trace"
[ -x "$ROOT/../harness/scripts/util_sno_trace_witness.sh" ] || { echo "⛔ REFUSE(2): no ../harness/scripts/util_sno_trace_witness.sh"; exit 2; }
rc=0; ran=0
for arm in trace_keyword_untraceable_name:198 trace_keyword_name_with_ampersand:198 trace_keyword_stoptr_untraceable_name:190; do
  w="$PROBES/${arm%:*}.sno"; e="${arm#*:}"
  [ -f "$w" ] || { echo "⛔ REFUSE(2): no witness $w"; exit 2; }
  out="$(cd "$ROOT" && bash ../harness/scripts/util_sno_trace_witness.sh "$w" --expect-error "$e" 2>&1)"; arc=$?
  [ "$arc" = 2 ] && { printf '%s\n' "$out" | tail -2; echo "⛔ REFUSE(2): could not measure ${arm%:*}"; exit 2; }
  ran=$((ran + 1)); [ "$arc" = 0 ] || { rc=1; printf '%s\n' "$out" | grep -E '^FAIL' | sed "s/^/⛔ RED ${arm%:*}: /"; }
done
[ "$ran" = 3 ] || { echo "⛔ REFUSE(2): measured $ran of 3 arms"; exit 2; }
[ "$rc" = 0 ] && echo "GATE OK: 3 arms x 2 modes -- an untraceable keyword name, an ampersanded one, and STOPTR of an untraceable name each raise the oracle's own error number"
exit $rc

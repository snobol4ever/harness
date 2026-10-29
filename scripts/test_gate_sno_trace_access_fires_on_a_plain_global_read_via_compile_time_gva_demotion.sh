#!/bin/bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the SNOBOL4 statement instrumentation (the --stlimit switch; Lon 2026-09-24 16:0x: the feature is off by default and never inferred from the source, the correctness graders turn it on because the oracle always has it)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ WITNESS GATE for rung22 of row snobol4-ladder-every-feature-in-isolation-with-variations (cfo 2026-09-13).
# THE FORM THIS GATE EXISTS FOR is the SPITBOL manual's own ACCESS example (Ch10 p.147): "If you say X = N, that
# does not change the value of N, but it is a reference -- an 'access' to N."  A PLAIN read of a global took the
# g_gva_active fast path in bb_var_global -- two movs straight out of the GVA slot with NO call -- so the read-tap
# in NV_GET_fn could not see it AT ANY PRICE, and the sibling gate ...fires_on_a_reference_and_is_silent_on_an_
# assignment.sh had to route every arm through $() indirection to reach a tappable site.  MEASURED on the pre-cure
# binary, BOTH modes: this gate's ACCESS arms printed NOTHING AT ALL.
# ⛔ THE CURE IS COMPILE-TIME DEMOTION, NOT A RUNTIME GUARD (hq_P RULING 2026-09-13).  A load-and-branch per global
# read, on the hottest path in the language, shared by all seven frontends, paid by every program forever so that
# programs which debug themselves can be debugged, was REFUSED -- and rightly.  Instead the driver declines to build
# the GVA island at all for a program that qualifies, reaching the SAME off-state a program with no eligible globals
# already reaches.  bb_var_global is UNTOUCHED.  The trigger is CONSERVATIVE on hq_P's refinement: it fires on any
# TRACE call whose type argument is not a literal we can prove is non-ACCESS, so a COMPUTED type demotes too (arm
# 'computed') and there is no silent miss; it is latched to the SNOBOL4 family where lower_snobol4 seeds the keyword
# refusals, so no other frontend can reach it.
# ⛔ WHY THE 'gva_off_only_when_it_qualifies' ARM IS NOT DECORATION.  Whole-corpus byte identity (3121 vendored
# sources across SNOBOL4/Icon/Pascal/Prolog, 2019 of them emitting real assembly, ZERO moved) is a ONE-OFF two-binary
# measurement a gate cannot repeat.  What a gate CAN assert on ONE binary is the discrimination itself, positively:
# the GVA machinery is ABSENT from the qualifying program and PRESENT in its otherwise-identical non-qualifying twin.
# An arm that only checked absence would pass on a compiler that had lost GVA entirely.
# ⛔ NOT ASSERTED HERE, AND NAMED RATHER THAN HIDDEN: a LOWERCASE type argument.  sbl -bf accepts TRACE('N','access')
# and TRACE('N','value'); SCRIP's trace_type_parse matches with strcmp and raises error 199 for both.  That is a
# SEPARATE divergence of the type parse (it is not about ACCESS -- lowercase 'value' shows it too), it is rowed on
# its own, and curing it here would be scope riding on this cure.  The demotion itself is CORRECT for that program:
# the conservative trigger fires and the assembly demotes; the runtime then refuses the type.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ⛔ THE SUBJECT TREE IS THE TREE THIS SCRIPT LIVES IN, never the literal name SCRIP (lib_subject_tree.sh):
# the round trip up-to-the-root-and-back-down-into-SCRIP lands in the MAIN checkout even when you are standing
# in a worktree, and then the gate grades a tree the seat is not pushing.  Caught on this very gate by
# test_gate_no_worktree_blind_subject.sh, which went 68 -> 69 the moment I copied the old idiom from a sibling.
. "$HERE/lib_subject_tree.sh"
ROOT="$(s4e_subject_repo "${BASH_SOURCE[0]}")"
[ -f "$ROOT/../harness/scripts/util_sno_trace_witness.sh" ] || { echo "⛔ REFUSE(2): no ../harness/scripts/util_sno_trace_witness.sh"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
body() { printf "\t&TRACE = 1000\n\tN = 5\n\tM = 7\n%b\n\tX = N\n\tN = 9\n\tY = N + M\n\tZ = M\n\tOUTPUT = N\n\tOUTPUT = M\nEND\n" "$1"; }
body "\tTRACE('N','ACCESS')"          > "$T/plain_read.sno"
body "\tTRACE('N','A')"               > "$T/spelling.sno"
body "\tT = 'ACC' 'ESS'\n\tTRACE('N',T)" > "$T/computed.sno"
body "\tTRACE('N','VALUE')"           > "$T/ctl_value.sno"
body "\tTRACE('N')"                   > "$T/ctl_omitted.sno"
body "\tTRACE('STCOUNT','KEYWORD')"   > "$T/ctl_keyword.sno"
body "\tOUTPUT = 'no trace here'"     > "$T/ctl_untraced.sno"
body "\tTRACE('N','access')"          > "$T/ctl_lowercase.sno"
rc=0; ran=0
# ⭐ Every 'must' below is CUT FROM THE LIVE ORACLE by the helper, which REFUSES rc=2 if sbl does not print it.
# ⭐ THE ACCESS AND VALUE ARMS ARE THE SAME SOURCE DIFFERING ONLY IN THE TYPE LITERAL, and they disagree in a way
# that could not be faked by a trace that simply fires a lot: with ACCESS the banner lands on the three READS of N
# (stmts 5, 7, 9 -- a bare assignment, a binop operand and an OUTPUT) and NOT on the assignment N = 9 at stmt 6;
# with VALUE it lands on stmt 6 ALONE.  Statement 8 (Z = M) never mentions N and is the silence control in both.
# 'ctl_omitted' pins the default: an omitted type argument must behave as VALUE, which is also what makes a
# one-argument TRACE provably non-ACCESS and therefore NOT a demotion trigger.
for arm in \
  "plain_read:****5*******  N = 5" \
  "spelling:****5*******  N = 5" \
  "computed:****6*******  N = 5" \
  "ctl_value:****6*******  N = 9" \
  "ctl_omitted:****6*******  N = 9" \
  "ctl_keyword:****5*******  &STCOUNT = 5" \
  "ctl_untraced:no trace here" ; do
  w="$T/${arm%%:*}.sno"; must="${arm#*:}"
  out="$(cd "$ROOT" && bash ../harness/scripts/util_sno_trace_witness.sh "$w" "$must" 2>&1)"; arc=$?
  [ "$arc" = 2 ] && { printf '%s\n' "$out" | tail -3; echo "⛔ REFUSE(2): could not measure ${arm%%:*}"; exit 2; }
  ran=$((ran + 1)); [ "$arc" = 0 ] || { rc=1; printf '%s\n' "$out" | grep -E '^(FAIL|[<>])' | head -8 | sed "s/^/⛔ RED ${arm%%:*}: /"; }
done
[ "$ran" = 7 ] || { echo "⛔ REFUSE(2): measured $ran of 7 oracle arms"; exit 2; }
# ⭐ THE DISCRIMINATION ARM, asserted POSITIVELY IN BOTH DIRECTIONS on one binary (hq_P: "a positive assertion over
# the delta, not a not-equal check").  Absence alone would pass on a compiler with no GVA left, so presence in the
# twin is asserted in the same breath.  The two sources differ ONLY in the TRACE type literal.
(cd "$ROOT" && ./scrip --compile --out="$T/q.s" "$T/plain_read.sno" </dev/null >/dev/null 2>&1) || { echo "⛔ REFUSE(2): qualifying witness did not compile in m4"; exit 2; }
(cd "$ROOT" && ./scrip --compile --out="$T/n.s" "$T/ctl_value.sno"  </dev/null >/dev/null 2>&1) || { echo "⛔ REFUSE(2): control witness did not compile in m4"; exit 2; }
# ⛔⭐ THE FOURTH QUALIFYING FORM, ASSERTED STRUCTURALLY ONLY, AND THAT IS DELIBERATE.  A lowercase type is
# rowed as a SEPARATE divergence (trace_type_parse uses strcmp; sbl folds), so its RUNTIME behaviour is red today
# and is not asserted anywhere here.  What IS asserted is that the TRIGGER does not care: it demotes on a spelling
# the runtime will go on to refuse, which is the whole point of a trigger that fails TOWARD demotion.  This arm
# stays TRUE whether or not that row ever lands, so curing it cannot turn this gate red.
(cd "$ROOT" && ./scrip --compile --out="$T/lc.s" "$T/ctl_lowercase.sno" </dev/null >/dev/null 2>&1) || { echo "⛔ REFUSE(2): lowercase witness did not compile in m4"; exit 2; }
lcn=$(grep -c '__gva_names' "$T/lc.s" || true)
[ "$lcn" -eq 0 ] || { echo "⛔ RED lowercase_still_demotes: a lowercase ACCESS type left the GVA island in place ($lcn) -- the trigger has started trusting the runtime's type parse"; rc=1; }
qn=$(grep -c '__gva_names' "$T/q.s" || true); qs=$(grep -cE 'qword ptr \[r9 \+ [0-9]+\]' "$T/q.s" || true)
nn=$(grep -c '__gva_names' "$T/n.s" || true); ns=$(grep -cE 'qword ptr \[r9 \+ [0-9]+\]' "$T/n.s" || true)
[ "$nn" -gt 0 ] && [ "$ns" -gt 0 ] || { echo "⛔ REFUSE(2): the NON-qualifying twin carries no GVA island ($nn names, $ns slot refs) -- this arm cannot discriminate, re-measure before trusting any green here"; exit 2; }
if [ "$qn" -ne 0 ] || [ "$qs" -ne 0 ]; then
  echo "⛔ RED gva_off_only_when_it_qualifies: the ACCESS-traced program still emits the GVA island ($qn names, $qs slot refs); its plain reads cannot reach the tap"; rc=1
fi
# ⛔⭐ THE CLIFF CANARY (hq_P ASK 2026-09-13).  A demoted program is still CORRECT, so NO board, ref or gate in
# this tree will ever report that it got slower -- and measured on this box a demoted global read costs roughly
# 1.82x-2.15x, a range that bounds INSTRUMENT NOISE HERE and is NOT a published property of any kernel.  Today the
# qualifying set is EMPTY in both corpus and benchmarks (hq_P measured it: every TRACE under corpus/benchmarks is
# one of the non-qualifying controls above), so the cliff falls on nobody -- which is exactly why it is invisible.
# THESE FOUR QUALIFYING WITNESSES ARE THE CANARY FOR ONE OF THE TWO ABSENCES, AND ONLY ONE (hq_P, 2026-09-13).
# They detect THE TRIGGER BEING SWITCHED OFF: a future change that stops the demotion firing makes them red.
# ⛔ THEY DO NOT DETECT A NEW PROGRAM FALLING ONTO THE CLIFF.  The day someone writes a kernel or corpus program
# with a computed or ACCESS trace type, THIS GATE STAYS GREEN -- correctly -- and that program silently takes the
# hit, because a demoted program is still CORRECT.  Do not read a green here as covering that; it never could.
# That second absence is guarded in hq_P's lane by a hermetic census asserting that NO benchmark kernel qualifies.
# The two guards share ONE ground truth -- the emitted GVA island -- and answer opposite questions over it: here
# that the island is GONE for four programs that must demote, there that it is PRESENT for every kernel that must
# not.  Keyed that way neither can drift from the predicate (gva_trace_type_provably_non_access, gva_collect.c).
[ "$rc" = 0 ] && echo "GATE OK: 7 oracle arms x 2 modes + 2 structural arms -- an ACCESS trace fires on a PLAIN global read at all three sinks, a computed type demotes conservatively, a lowercase type demotes even though the runtime then refuses it, and the GVA island is dropped ONLY for a qualifying program (non-qualifying twin carries $nn names / $ns slot refs; all 4 qualifying forms carry 0). A demoted program is still CORRECT, so these 4 named witnesses are the ONLY canary for the cliff."
exit $rc

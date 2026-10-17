#!/usr/bin/env bash
# test_gate_gate_wiring_ratchet.sh — the invariant gate over ../harness/scripts/util_gate_wiring.py, THE RATCHET that
# keeps a gate from landing on disk and being run by nothing (row requested by hq_S 2026-09-06, routed by the
# ceo as CEO-326; built by hq_T).
#
# WHAT IT PROTECTS. hq_S's measured case: test_gate_sno_fence_body_dynamic_operand.sh landed IN THE SAME PUSH
# as the cure it grades and was never added to the recipe, so for a day the one instrument that could grade
# that cure was run by nothing. ⛔ AND NOTHING COULD HAVE NOTICED — the gate was green by hand, ls found it,
# the commit looked complete, and every board was byte-identical with and without the cure BY CONSTRUCTION, so
# no suite could miss it either. An unwired gate is indistinguishable from a wired one by every check except
# reading the recipe. util_gate_wiring.py is that check; this gate is what keeps IT honest.
#
# ⛔ IT GRADES THE INSTRUMENT ON FIXTURES, NOT THE LIVE TREE, AND THAT IS THE POINT. The live check belongs in
# handoff_status.sh (hq_S's placement argument, and it is the half that would not have been got right alone:
# handoff is the moment a seat asks "is there anything I owe", whereas a recipe check fires every seat's
# `make test` for everybody else's debt). What belongs HERE is the proof that the instrument's REFUSALS still
# fire — because the failure this whole family is about is an instrument that looks like it is measuring.
#
# ⭐ EVERY ARM IS A FAIL-ONCE PROOF. Each fixture is built so that exactly one refusal can fire, and the arm
# asserts the refusal NAMES the gate it is about. A ratchet that says "the floor moved" sends its reader to
# diff two files by hand, and the reader who has to do that is the reader who mutes the check (hq_S). The two
# arms that carry the design are:
#   · the COUNT-UNCHANGED REGRESSION — one WIRED name leaves and another arrives in the same edit, so the
#     count is identical and a count-only floor is GREEN OVER A REAL REGRESSION. The name set still refuses.
#   · REACHABILITY IS EXECUTION, NOT MENTION — a gate named only in a comment, only in an echo, or only inside
#     a glob-census that READS the files is NOT reachable, and counting it would be the instrument lying in
#     the comfortable direction (under-reporting debt is exactly the direction nobody would notice).
#
# ⛔ AND IT ASSERTS THE LIVE FILE IS SANE without grading it: the population must cover ../harness/scripts/test_gate_*.sh
# exactly once, or `check`'s SUM arm is asserting over a file that cannot be right. That is a shape check on
# the record, not a verdict on the debt — the debt is handoff_status.sh's to report and nobody's to be blocked
# by here.
#
# Usage: bash ../harness/scripts/test_gate_gate_wiring_ratchet.sh    (hermetic, offline, ~0.2s)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="gate_wiring_ratchet"
gate_parse_args "$@"
HELPER="$HERE/util_gate_wiring.py"
gate_require "$HELPER" "the gate-wiring ratchet util_gate_wiring.py"
gate_require "$HERE/gate_wiring.tsv" "the one gate population ../harness/scripts/gate_wiring.tsv"
violations=0
examined=0
ck() { examined=$((examined + 1)); if [ "$1" = "ok" ]; then printf '  ok   %s\n' "$2"; else printf '  FAIL %s\n' "$2"; violations=$((violations + 1)); fi; }

echo "--- ARM 1 — the instrument's own selftest: hermetic arms over scratch fixtures ---"
out="$(python3 "$HELPER" selftest 2>&1)"; rc=$?
printf '%s\n' "$out" | sed 's/^/    /'
[ "$rc" -eq 0 ] && ck ok "selftest rc=0" || ck fail "selftest rc=$rc — a refusal path of the ratchet no longer fires"

echo "--- ARM 2 — the selftest actually GRADED something (a green that examined nothing is the shape we are here about) ---"
arms="$(printf '%s\n' "$out" | grep -cE '^  (ok|FAIL) ')"
[ "${arms:-0}" -ge 46 ] && ck ok "selftest ran $arms arm(s), floor 46" || ck fail "selftest ran only ${arms:-0} arm(s) — below the floor of 46"

echo "--- ARM 3 — every refusal class the design names is still reachable in the selftest output ---"
for cls in "left-the-wired-set" "count-unchanged regression" "landed unwired" "wired-but-listed-TASK" \
           "recorded-but-gone" "ruling without reason" "declare empty reason" "declare TASK over ceiling" \
           "duplicate + unknown class" "unmeasurable is rc=2" "only the executed gate is reachable" \
           "declared-population arm is reachable" "unexpandable optional targets are named" \
           "wired twice in one recipe" "flags the divergent cost comments" "identical lines still refuse" \
           "wired twice across a sub-make" "a signed second line is clean" "signed with no reason refuses" \
           "one line, a comment and an echo are not a double"; do
  printf '%s\n' "$out" | grep -q -- "$cls" && ck ok "arm present: $cls" || ck fail "arm MISSING: $cls — a refusal class lost its proof"
done

echo "--- ARM 4 — the record is well formed: no name in two buckets, and no line about a file that is not there ---"
# ⛔⭐ IT GRADES THE RECORD, NEVER THE DEBT, AND THE FIRST DRAFT GOT THAT WRONG. It asserted that the population
# COVERS ../harness/scripts/test_gate_*.sh -- and within the hour a gate from another seat landed unwired, so this gate
# went red inside `make test` for somebody else's debt. That is precisely the failure the whole design argues
# against and would have got this line `|| true`-d out within the week. Coverage is the LIVE question and it is
# reported WARN-ONLY by handoff_status.sh, at the moment a seat asks what it owes. What belongs here is whether
# the instrument's own record is sane: a name in two buckets destroys the one-bucket property that is the only
# reason this is one file, and a line about a file that is not there is a claim about nothing.
listed="$(grep -cE '^test_gate_[A-Za-z0-9_]+\.sh	(WIRED|RULING|TASK)	' "$HERE/gate_wiring.tsv")"
uniq_listed="$(grep -oE '^test_gate_[A-Za-z0-9_]+\.sh' "$HERE/gate_wiring.tsv" | sort -u | wc -l)"
[ "$listed" -eq "$uniq_listed" ] && ck ok "no name listed twice ($uniq_listed distinct)" \
                                 || ck fail "$((listed - uniq_listed)) name(s) listed twice — one file buys exactly one bucket per name, or it buys nothing"
malformed="$(grep -cvE '^(#|$|test_gate_[A-Za-z0-9_]+\.sh	(WIRED|RULING|TASK)	)' "$HERE/gate_wiring.tsv")"
[ "$malformed" -eq 0 ] && ck ok "every line is a comment or a well-formed row" \
                       || ck fail "$malformed malformed line(s) — check(1) cannot read a bucket it cannot parse"
# REPORTED, NOT GRADED — the live debt, so a reader of this gate still sees the number without being blocked by it.
disk="$(ls "$HERE"/test_gate_*.sh 2>/dev/null | wc -l)"
echo "    REPORTED (not graded here — handoff_status.sh owns the live verdict): $listed listed, $disk on disk, delta $((disk - listed))"

echo "--- ARM 5 — the ceiling is present and is a number (a debt with no cap is not a ratchet) ---"
ceil="$(sed -n 's/^# TASK-CEILING: *\([0-9][0-9]*\).*/\1/p' "$HERE/gate_wiring.tsv" | head -1)"
[ -n "$ceil" ] && ck ok "TASK-CEILING present: $ceil" || ck fail "no TASK-CEILING header — the debt has no cap"
tasks="$(grep -cE '	TASK	' "$HERE/gate_wiring.tsv")"
[ -n "$ceil" ] && [ "$tasks" -le "$ceil" ] && ck ok "TASK $tasks <= ceiling $ceil" \
                                           || ck fail "TASK $tasks exceeds ceiling ${ceil:-unset} — the debt may only go DOWN"

echo "--- ARM 6 — every RULING carries a reason AND a declarer (hq_S's constraint 2: an exemption nobody signed is not a ruling) ---"
bad="$(awk -F'\t' '$2=="RULING" && ($3=="-" || $3=="" || $4=="-" || $4=="") {print $1}' "$HERE/gate_wiring.tsv")"
[ -z "$bad" ] && ck ok "all RULING rows signed and reasoned" || { ck fail "RULING without reason/declarer:"; printf '%s\n' "$bad" | sed 's/^/       /'; }

echo "--- ARM 7 — ONE LINE PER SCRIPT, graded on the LIVE Makefile (hq_U 2026-09-10, ceo CEO-516) ---"
# ⛔⭐ THIS IS THE ONE ARM HERE THAT GRADES THE LIVE TREE, AND ARM 4 ABOVE ARGUES AT LENGTH THAT IT MUST NOT.
# The argument is right and this arm is not the exception to it — it is the case the argument does not reach,
# and the difference is the SIZE OF THE POPULATION, not the strength of anyone's opinion. Coverage has ~190
# unwired gates: a live coverage arm here reds every seat's `make test` for a stranger's debt, gets `|| true`-d
# out inside a week, and the muted check is worse than none. The wired-twice population is a MEASURED ZERO
# (2026-09-10, hq_T, over `test` + `test-postoffice`), so a red here is never a backlog — it is a defect that
# landed since the last green, it costs ONE LINE to cure, and its author is still in the room. ⭐ THE GENERAL
# FORM, adopted as the criterion by the ceo as CEO-520 and sharpened by hq_U: whether a check belongs in the
# recipe or at handoff is decided by whether its refusal is a TASK somebody must schedule or a TYPO somebody
# must delete -- equivalently, A LIVE-TREE ARM IS LEGITIMATE EXACTLY WHEN ITS RED POPULATION IS SMALL ENOUGH
# THAT EVERY RED HAS A NAMED AUTHOR STILL IN THE ROOM. The honest way to know is to measure the backlog
# before wiring it, never to reason about how important the check feels.
# ⛔ THE MEASURED ZERO IS THE PRECONDITION, NOT A PLEASANT FACT ABOUT TODAY (hq_U, 2026-09-10). If this count
# is ever nonzero AT REST -- a double nobody is about to delete -- the argument above has EXPIRED and ARM 7
# moves to handoff_status.sh, where a standing red is a census rather than a blocker. A standing red left in
# a recipe trains every reader to skip the arm, which is the exact failure ARM 4 was written against.
# ⭐ AND THE SUB-MAKE WALK IS WHAT MAKES THE ZERO TRUSTWORTHY (hq_U): the overlap between `test:` and the
# `test-postoffice:` it invokes is empty ONLY BECAUSE BOTH RECIPES WERE LOOKED IN. A count that stopped at
# the target boundary would report the same zero with a cross-target double in plain sight, and the
# precondition would then rest on the instrument's blind spot rather than on the tree.
# Hermetic: Makefile TEXT only — no `make -n`, no build, no scripts read, <0.05s MEASURED.
dbl_out="$(python3 "$HELPER" doubles 2>&1)"; dbl_rc=$?
printf '%s\n' "$dbl_out" | sed 's/^/    /'
case "$dbl_rc" in
  0) ck ok "no script is on two executing recipe lines" ;;
  2) ck fail "CANNOT MEASURE the recipe (rc=2) — not clean and not a refusal, nothing was examined" ;;
  *) ck fail "a script is wired TWICE — \`make test\` runs it twice and the two comments mislead the next reader" ;;
esac

GATE_EXAMINED="$examined"
gate_verdict "$violations" "violation(s)"

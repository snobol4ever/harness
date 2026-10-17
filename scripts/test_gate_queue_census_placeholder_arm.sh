#!/usr/bin/env bash
# test_gate_queue_census_placeholder_arm.sh — the invariant gate for class P of util_queue_visibility_census.py
# (ceo ruling CEO-289, 2026-09-05, from hq_P's 44-baton FINDING; built by hq_T).
#
# WHAT IT PROTECTS.  A baton whose DONE-WHEN is still the mint skeleton is UNCLOSABLE: `done` executes that
# line whole, prose is not a command, so a seat can do the whole job correctly and get a refusal that is
# INDISTINGUISHABLE from the one a genuinely wrong cure produces.  Class E cannot catch it — the DONE-WHEN
# line EXISTS, it is just not runnable.
#
# ⛔⭐ THE PROPERTY THIS GATE ACTUALLY DEFENDS IS THE KEY, NOT THE COUNT.  The obvious instrument — grep the
# placeholder text over the whole task file — OVER-REPORTS BY 2.5x (112 against a true 44, measured by hq_P
# 2026-09-05), because ledger lines, handoff notes and QA answers MENTION the placeholder; two of the false
# hits were lines hq_P had written an hour earlier recording that they had REMOVED one.  The instrument
# counted the cure as the disease, and it failed in the INFLATING direction, which is the more persuasive
# one — a scary number invites action rather than scrutiny.  So ARM 2 is the load-bearing arm: a baton with a
# REAL DONE-WHEN that merely mentions the placeholder in its prose must NOT be counted, and ARM 3 proves that
# is a real discrimination by showing the whole-file grep does count it.
#
# Every arm runs against a SYNTHETIC postoffice via S4E_PO — this gate never reads, and never writes, the
# live /home/resources/postoffice.  Offline, sub-second.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CENSUS="$HERE/util_queue_visibility_census.py"
PLACE='⛔ MUST BE MADE RUNNABLE BEFORE done CAN EVER PASS — minted with no executable acceptance test; replace this line with a real command (see other tasks/*.task.md for the shape) before anyone can close this row.'
fail=0
ck() { if [ "$1" = ok ]; then echo "  ✅ $2"; else echo "  ⛔ $2"; fail=$((fail+1)); fi; }
[ -f "$CENSUS" ] || { echo "⛔ REFUSE(2): no util_queue_visibility_census.py beside this gate at $CENSUS"; exit 2; }
mkpo() {
    # mkpo <dir> — a minimal postoffice the census can read: QUEUE.tsv, QUEUE.done.tsv, MODE, claims/, tasks/
    mkdir -p "$1/claims" "$1/tasks" || return 2
    printf '# synthetic\n' > "$1/QUEUE.tsv"
    printf '# synthetic\n' > "$1/QUEUE.done.tsv"
    printf 'FLEET-16\n'    > "$1/MODE"
}
baton() { # baton <po> <topic> <first-line> <done-when> <extra-body>
    { printf '# TASK %s\n' "$2"; printf 'GOAL: %s\n' "$3"; printf 'DONE-WHEN: %s\n' "$4"; printf '%s\n' "$5"; } > "$1/tasks/$2.task.md"
}
# ⛔⭐ A ROW EXISTS ONLY WHILE A MEASUREMENT SAYS THE PROBLEM EXISTS (Lon 2026-10-01, CEO-1386/1387): class P reads only
# LIVE rows, so every baton the arms below plant sits on a QUEUE.tsv row (rank, topic, owner, state) unless the arm
# is proving the opposite -- ARM 1b plants the same placeholder baton on a RETIRED row and wants it NOT counted.
row()  { printf '0\t%s\thq_X\tFREE\n' "$2" >> "$1/QUEUE.tsv"; }           # row <po> <topic>  -- a live FREE row
rrow() { printf '0\t%s\thq_X\tRETIRED\n' "$2" >> "$1/QUEUE.retired.tsv"; } # rrow <po> <topic> -- a retired row
pcount() { # pcount <po> — the number class P reports, or 'REFUSED'
    local out; out=$(S4E_PO="$1" python3 "$CENSUS" 2>&1); local rc=$?
    [ "$rc" = 2 ] && { echo REFUSED; return; }
    printf '%s\n' "$out" | sed -n 's/^P  DONE-WHEN is still the mint placeholder (\([0-9]*\)).*/\1/p' | head -1 | grep -q . \
        && printf '%s\n' "$out" | sed -n 's/^P  DONE-WHEN is still the mint placeholder (\([0-9]*\)).*/\1/p' | head -1 || echo 0
}
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT
echo "--- ARM 1 (fail once): a baton whose DONE-WHEN IS the placeholder is COUNTED ---"
mkpo "$T/a" || exit 2
baton "$T/a" synth_placeholder 'a synthetic row' "$PLACE" '## LEDGER'; row "$T/a" synth_placeholder
n=$(pcount "$T/a"); ck "$([ "$n" = 1 ] && echo ok || echo no)" "class P counts the placeholder baton on a LIVE row (got '$n', want 1)"
echo "--- ARM 1b (CEO-1386/1387): the SAME placeholder baton on a RETIRED row is history, NOT counted ---"
mkpo "$T/r" || exit 2
baton "$T/r" synth_retired 'a synthetic row' "$PLACE" '## LEDGER'; rrow "$T/r" synth_retired
n=$(pcount "$T/r"); ck "$([ "$n" = 0 ] && echo ok || echo no)" "class P does NOT count a placeholder baton whose row is retired (got '$n', want 0)"
echo "--- ARM 2 (pass once, THE LOAD-BEARING ARM): a REAL DONE-WHEN whose PROSE mentions the placeholder is NOT counted ---"
mkpo "$T/b" || exit 2
baton "$T/b" synth_cured 'a synthetic row' 'echo GREEN' "## LEDGER
- [hq_X] Replaced the ⛔ MUST BE MADE RUNNABLE BEFORE done CAN EVER PASS line with a real criterion."; row "$T/b" synth_cured
n=$(pcount "$T/b"); ck "$([ "$n" = 0 ] && echo ok || echo no)" "class P does NOT count a cured baton that mentions the placeholder in prose (got '$n', want 0)"
echo "--- ARM 3 (the control that makes ARM 2 mean something): the whole-file grep DOES count that same baton ---"
if grep -q 'MUST BE MADE RUNNABLE' "$T/b/tasks/synth_cured.task.md"; then
    ck ok "the naive whole-file grep counts the cured baton, so ARM 2 is a real discrimination and not a vacuous pass"
else
    ck no "the cured baton does not even contain the placeholder text -- ARM 2 proved nothing; fix this gate's fixture"
fi
echo "--- ARM 4: a TOMBSTONE baton (SUPERSEDED header) carrying the placeholder is NOT counted ---"
mkpo "$T/c" || exit 2
baton "$T/c" synth_tomb 'a synthetic row' "$PLACE" '## LEDGER'; row "$T/c" synth_tomb
sed -i '1s/.*/# TASK synth_tomb — SUPERSEDED by another topic/' "$T/c/tasks/synth_tomb.task.md"
n=$(pcount "$T/c"); ck "$([ "$n" = 0 ] && echo ok || echo no)" "a redirect stub needs no runnable criterion (got '$n', want 0)"
echo "--- ARM 5: an unreadable postoffice REFUSES rc=2, never a silent green ---"
n=$(pcount "$T/does_not_exist"); ck "$([ "$n" = REFUSED ] && echo ok || echo no)" "census refuses rc=2 on an unreadable postoffice (got '$n')"
echo "--- ARM 6: the live postoffice is untouched by every arm above ---"
ck "$([ -z "${S4E_PO:-}" ] && echo ok || echo no)" "this gate never exported S4E_PO into the caller's environment"
[ "$fail" = 0 ] && { echo "✅ GATE OK: util_queue_visibility_census.py class P keys on the DONE-WHEN LINE, not the file"; exit 0; }
echo "⛔ GATE RED: $fail arm(s) failed"; exit 1

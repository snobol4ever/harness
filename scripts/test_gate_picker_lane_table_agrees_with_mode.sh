#!/bin/bash
# test_gate_picker_lane_table_agrees_with_mode.sh -- the picker's language->owner table is a SECOND COPY of
# MODE line 2, and this is what keeps the copy honest.
#
# ⛔⭐ THE MEASURED CASE (ceo CEO-672, 2026-09-13; re-measured independently by hq_B before acting on it).
# `s4e_topic_lane`'s language fallback was a FLEET-era map that NONET invalidated wholesale. SIX OF SEVEN
# languages named a seat that does not own them: icon->hq_B where Icon is the ceo · snobol4->hq_P where it is
# the cfo · snocone->hq_P where it is hq_I · pascal->hq_P where it is the coo · rebus->hq_T where it is hq_S ·
# prolog->hq_C where the cto owns completeness. Exactly one, raku->hq_T, was still right.
# ⛔ IT FAILED IN BOTH DIRECTIONS AT ONCE, which is why it ran for as long as NONET had been open: `next`
# served rows to seats that do not own them AND skipped them for the seats that do. hq_S watched it skip
# thirty rows before locking a SNOBOL4 row it then released unworked. A dispatcher that is wrong in one
# direction starves a lane loudly; wrong in both, every seat sees a plausible queue and nobody sees a gap.
#
# ⭐⭐ WHY THIS IS A GATE AND NOT A DERIVATION, WHICH IS THE PART WORTH ARGUING. The ceo offered both and left
# the choice here. Deriving the owner from MODE line 2 at call time sounds strictly better -- no copy, no rot.
# ⛔ IT WAS MEASURED AND REJECTED. The only parseable ownership shape in line 2 is the phrase "THE SEATS: RAKU
# -- hq_T; ... ICON -- the ceo", and `grep -c 'THE SEATS:'` over the MODE backups says it appears in ONE of the
# last TEN versions: line 2 is prose whose phrasing is reinvented at every mode cut. A parser over it would
# have found nothing for nine of ten modes and fallen back to the hardcoded table -- today's bug, with
# machinery on top and a false claim of freshness. ⭐ The general form: you cannot derive a fact from a
# document that does not promise to state it the same way twice. What you CAN do is refuse to be silently
# wrong about it, which is this gate.
# ⭐ THE REAL CURE IS UPSTREAM AND IS AN ASK, NOT A LANDING: MODE line 1 is machine-readable and line 2 is not.
# A machine-readable lane field would let the picker derive at call time and delete the copy for good. Until
# that exists, this gate is the honest second-best, and it says so rather than pretending to be the first.
#
# THE THREE EXIT CODES (lib_gate.sh's rule): 0 agree · 1 DISAGREE, naming the language and both owners ·
# 2 could-not-measure (MODE unreadable, or line 2 carries no ownership statement this can parse).
# ⛔ rc=2 IS NOT A PASS AND IS NOT A FAILURE. "MODE line 2 does not say who owns Snocone in a shape I can read"
# is a fact about the MODE file, not about the table; spelling it rc=1 would blame the wrong file and train
# seats to edit the table until the gate goes quiet.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_subject_tree.sh"
REPO="$(s4e_subject_repo "${BASH_SOURCE[0]}")"
MSG="${LANE_GATE_MSG:-$REPO/../harness/scripts/s4e_msg.sh}"
PO="${S4E_POST:-/home/resources/postoffice}"
MODEF="${LANE_GATE_MODE:-$PO/MODE}"

echo "picker lane table vs MODE line 2 -- recomputed live, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
s4e_subject_announce "$REPO" >/dev/null || true
# ⛔ TWO CLOCKS, BOTH STAMPED (the cfo's ask, CEO-1056). This arm compares a REPO FILE moved by git against a
# LIVE SHARED FILE moved by another seat's write, so its red cannot say WHICH SIDE IS BEHIND -- and on 2026-09-21
# that ambiguity produced three false reds in one day, the third from a seat who had the LAW fresh and the TREE
# thirty minutes stale and checked only the clock that had burned them twice already. Printing both turns an
# accusation into a one-line self-diagnosis: if the table commit is older than the MODE mtime, PULL before
# believing this gate. Every other instrument in this fleet says which population it read; this one did not.
echo "  table: $MSG"
echo "         commit $(git -C "$(dirname "$MSG")" log -1 --format='%h %cr (%ci)' -- "$MSG" 2>/dev/null || echo 'UNKNOWN -- not a git checkout')"
echo "  law:   $MODEF"
echo "         written $(date -r "$MODEF" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || echo 'UNKNOWN -- cannot stat MODE')"
echo "  ⛔ TWO CLOCKS: a red here means the TABLE and the LAW disagree, never which of them is stale. If the table commit above predates the MODE write, PULL AND RE-RUN BEFORE REPORTING A RED."
[ -r "$MSG" ]   || { echo "⛔ REFUSES rc=2: cannot read the picker at $MSG"; exit 2; }
[ -r "$MODEF" ] || { echo "⛔ REFUSES rc=2: cannot read MODE at $MODEF -- a lane check with no law to check against must not print a verdict."; exit 2; }

# ── what the TABLE says. Read out of the script by running its own functions, never by re-parsing the case
# arms: a gate that reimplements the thing it grades can agree with a table nobody executes. ──────────────────
LANGS="$(bash -c '. /dev/stdin <<<"$(sed -n "/^s4e_lane_languages()/,/^s4e_lane_help()/p" "$1")"; s4e_lane_languages' _ "$MSG" 2>/dev/null)"
if [ -z "${LANGS:-}" ]; then
    echo "⛔ REFUSES rc=2: could not read s4e_lane_languages out of $MSG."
    echo "   The table moved or was renamed. A lane gate that cannot find the table must not report agreement."
    exit 2
fi
table_owner() { bash -c '. /dev/stdin <<<"$(sed -n "/^s4e_lane_languages()/,/^s4e_lane_help()/p" "$1")"; s4e_lane_owner_of_language "$2"' _ "$MSG" "$1" 2>/dev/null; }

# ── what MODE LINE 2 says. ⭐ Two independent shapes, because line 2 has used both and neither is promised:
#   (a) "THE SEATS: RAKU -- hq_T; ... ICON -- the ceo"     (the NONET cut)
#   (c) "THE SEATS: ... REBUS -- CLOSED, NO OWNER"          a language with NO owner by declaration
#   (b) "<seat> ICON", "<seat> SNOBOL4", ...               (the CONCERN-1 roster earlier in the same line)
# A language found by NEITHER is UNPARSEABLE, and unparseable is rc=2 for that language -- never an assumed
# agreement. ⛔ The two shapes must not be allowed to disagree silently either: when both match and differ,
# that is a defect in the LAW, and it is reported as a refusal rather than resolved by preferring one. ───────
L2="$(sed -n '2p' "$MODEF")"
[ -n "$L2" ] || { echo "⛔ REFUSES rc=2: MODE line 2 is empty -- nothing to check the table against."; exit 2; }
mode_owner() {
    local _lang_uc _a _b
    _lang_uc="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
    _a="$(printf '%s' "$L2" | grep -oE "$_lang_uc -- (the )?(ceo|cto|coo|cfo|hq_[A-Za-z0-9]+)" | head -1 | sed -E 's/.* -- (the )?//')"
    _b="$(printf '%s' "$L2" | grep -oE "(ceo|cto|coo|cfo|hq_[A-Za-z0-9]+) $_lang_uc[ ,]" | head -1 | sed -E 's/ .*//')"
    if [ -z "${_a:-}" ] && [ -z "${_b:-}" ] && printf '%s' "$L2" | grep -qE "$_lang_uc -- CLOSED"; then printf 'CLOSED'; return 0; fi
    if [ -n "$_a" ] && [ -n "$_b" ] && [ "$_a" != "$_b" ]; then printf 'CONFLICT:%s/%s' "$_a" "$_b"; return 0; fi
    printf '%s' "${_a:-$_b}"
}

FAIL=0; UNPARSED=0; CONFLICT=0; N=0
printf '  %-9s %-8s %-8s %s\n' LANGUAGE TABLE "MODE-L2" VERDICT
for L in $LANGS; do
    N=$((N+1)); T="$(table_owner "$L")"; M="$(mode_owner "$L")"
    case "$M" in
      CONFLICT:*) printf '  %-9s %-8s %-8s ⛔ MODE LINE 2 CONTRADICTS ITSELF (%s)\n' "$L" "${T:-?}" "--" "${M#CONFLICT:}"; CONFLICT=$((CONFLICT+1));;
      "")         printf '  %-9s %-8s %-8s ⚠️  unparseable in line 2 -- cannot check\n' "$L" "${T:-?}" "--"; UNPARSED=$((UNPARSED+1));;
      CLOSED)     if [ "$T" = "${LANE_GATE_CLOSED_OWNER:-ceo}" ]; then printf '  %-9s %-8s %-8s ✅ closed language, table routes to the arbiter\n' "$L" "$T" "$M";
                  else printf '  %-9s %-8s %-8s ⛔ DISAGREE -- MODE line 2 declares %s CLOSED, so a %s-* row is a REOPENING question and belongs to the arbiter (%s), not to %s\n' "$L" "${T:-?}" "$M" "$L" "$L" "${LANE_GATE_CLOSED_OWNER:-ceo}" "${T:-<nothing>}"; FAIL=$((FAIL+1)); fi;;
      "$T")       printf '  %-9s %-8s %-8s ✅\n' "$L" "$T" "$M";;
      *)          printf '  %-9s %-8s %-8s ⛔ DISAGREE -- the table sends %s-* rows to %s; MODE line 2 says %s owns %s\n' "$L" "${T:-?}" "$M" "$L" "${T:-<nothing>}" "$M" "$L"; FAIL=$((FAIL+1));;
    esac
done

# ⭐ ANTI-VACUITY: a table that has stopped listing languages agrees with everything. The floor is the count of
# languages the ANNOUNCEMENT ships, not zero -- and it is stated here rather than derived so that shrinking the
# table cannot also shrink the expectation in the same edit.
if [ "$N" -lt "${LANE_GATE_MIN_LANGS:-7}" ]; then
    echo "⛔ REFUSES rc=2: the table lists $N language(s), fewer than the ${LANE_GATE_MIN_LANGS:-7} the announcement ships."
    echo "   A shrunken table agrees with MODE about everything it no longer mentions."
    exit 2
fi
[ "$CONFLICT" -ne 0 ] && { echo "⛔ REFUSES rc=2: MODE line 2 names two different owners for $CONFLICT language(s)."; echo "   That is a defect in the LAW, not in the table, and this gate will not resolve it by preferring one reading."; exit 2; }
[ "$FAIL" -ne 0 ] && { echo "⛔ GATE FAILED: $FAIL of $N language(s) send rows to a seat MODE line 2 does not give them to."; echo "   Cure the table in s4e_msg.sh (s4e_lane_owner_of_language), and reassign QUEUE.tsv column 3 on the affected rows."; exit 1; }
if [ "$UNPARSED" -ne 0 ]; then
    echo "⛔ REFUSES rc=2: $UNPARSED of $N language(s) have no ownership statement this can parse in MODE line 2."
    echo "   NOT a pass: the table may be right or wrong about them and this gate cannot tell which."
    echo "   ⭐ THE STRUCTURAL CURE IS UPSTREAM: MODE line 1 is machine-readable and line 2 is prose reinvented"
    echo "      at each cut. A machine-readable lane field would let the picker derive at call time and delete"
    echo "      this copy entirely. Until then a language can drift here and nobody is told."
    exit 2
fi
echo "✅ GATE OK -- all $N language fallbacks name the owner MODE line 2 names (a CLOSED language must route to ${LANE_GATE_CLOSED_OWNER:-ceo})"
exit 0

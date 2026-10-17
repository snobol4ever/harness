#!/usr/bin/env bash
export S4E_DB_CHECK_OVERRIDE="gate fixture: this gate plants no progress rows (util_score_row.py db_crosscheck, hq_raku 2026-09-16)"
# test_gate_seat_identity_one_map.sh — seat identity is ONE map, and no runner may sign a board row with a
# placeholder (row `vendor-runners-stamp-unknown-seat-into-the-leaderboard-when-s4e-seat-is-unset`, hq_T
# 2026-09-04, GOAL routed by ceo CEO-175).
#
# WHAT WENT WRONG, AND WHY A GREP WAS NOT ENOUGH. Every runner spelled its measurer default
# ${S4E_SEAT:-unknown-seat}. S4E_SEAT is unset in a plain shell, so the vendor boards wrote the literal
# string "unknown-seat" into THE ONE LEADERBOARD — and it defeated the helper's own "an unattributed row is
# a claim with nobody behind it" guard by being non-empty. The cure was to DERIVE the identity from the root
# path instead of refusing harder, because the identity was never actually unknown: it is a fact on disk.
#
# ⛔ THE REASON THIS GATE EXISTS RATHER THAN A ONE-SHOT SWEEP. The cure left the root->seat map in THREE
# hand-synced copies — s4e_msg.sh, s4e_inbox_hook.sh, and util_score_row.py's derive_measurer(). They agree
# today. Nothing made them agree, and nothing would say so if one drifted: a drifted map does not crash, it
# signs somebody else's name to a measurement. So this gate pins the agreement itself, and pins the ONE
# place they are deliberately allowed to differ. It is the permanent form of that row's DONE-WHEN, which was
# a grep that could only ever be true once.
#
# ⭐ THE DELIBERATE ASYMMETRY IS PINNED, NOT PAPERED OVER. On an UNRECOGNISED root the bus falls back to
# basename($S4E) while the leaderboard REFUSES. That is correct in both directions and for opposite reasons:
# a seat with no name cannot be mailed, so the bus must invent one; a board row signed with a guess is
# exactly the unattributed claim this row exists to kill, so the board must not. Pinning it means a future
# "fix" that makes them agree has to be a deliberate act with a reason, instead of a tidy-up.
#
# Usage: bash ../harness/scripts/test_gate_seat_identity_one_map.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"

HELPER="$HERE/util_score_row.py"
BUS="$HERE/s4e_msg.sh"
HOOK="$HERE/s4e_inbox_hook.sh"
gate_require "$HELPER" "the one leaderboard helper util_score_row.py"
gate_require "$BUS"    "the postoffice bus s4e_msg.sh (carries a root->seat map)"
gate_require "$HOOK"   "the inbox hook s4e_inbox_hook.sh (carries a root->seat map)"

violations=0
examined=0
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ⛔ THE MAP IS LIFTED FROM THE FILE, NOT RETYPED HERE. A gate carrying its own expected map would be a
# FOURTH copy, and would pass while the file it grades was wrong.
awk '/^if \[ -z "\$ME" \]; then case "\$S4E" in/,/esac; fi$/' "$BUS"  > "$TMP/bus.map"
awk '/^if \[ -z "\$ME" \]; then case "\$S4E" in/,/esac; fi$/' "$HOOK" > "$TMP/hook.map"
if [ ! -s "$TMP/bus.map" ] || [ ! -s "$TMP/hook.map" ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: could not lift the root->seat case block out of s4e_msg.sh and/or"
    echo "    s4e_inbox_hook.sh — the block was renamed or reshaped, so this gate is grading nothing."
    gate_stamp
    exit 2
fi

# ARM 1 — the two bus copies are byte-identical to each other. They are hand-synced; drift between them is
# the live risk, and it is the cheapest thing here to check.
examined=$((examined + 1))
if ! diff -q "$TMP/bus.map" "$TMP/hook.map" >/dev/null 2>&1; then
    echo "GATE FAIL: s4e_msg.sh and s4e_inbox_hook.sh carry DIFFERENT root->seat maps:"
    diff "$TMP/bus.map" "$TMP/hook.map" | sed 's/^/    /'
    violations=$((violations + 1))
fi

# ARM 2 — the bus map and the leaderboard map agree on every KNOWN root.
#
# ⛔⭐ THE ROSTER IS LIFTED, NOT RETYPED — CURED BY hq_I 2026-09-05, AND THIS IS THE SAME LESSON THE HEADER
# ALREADY TEACHES, APPLIED ONE LEVEL UP. This gate correctly refuses to retype the MAPPING ("a gate carrying
# its own expected map would be a FOURTH copy, and would pass while the file it grades was wrong") — and then
# hand-typed the POPULATION, which fails in exactly the way the header forbids: on 2026-09-05 Lon opened
# /home/claude_U, _S, _I and _R, s4e_msg.sh learned all four, util_score_row.py learned none, and this gate
# passed GREEN because its roster stopped at claude_T. Four of eight HQs could not write THE ONE LEADERBOARD
# at all (every vendor run printed "REFUSED(2) ... root is not in the seat map" and "SCORE.md NOT UPDATED"),
# and the instrument built to catch precisely that drift reported no violation, because a gate only grades
# the population it is given. A hand-maintained roster is a second place a new root must be registered, and
# the whole point of this gate is that there must be ONE.
# So the enumerated roots now come OUT of the lifted case block itself. The header's asymmetry ruling is
# untouched: an UNRECOGNISED root must still diverge (bus invents, board refuses) and ARM 3 still pins that.
# The synthetic numbered seats stay spelled out — they are pattern arms, matched by [0-9] globs and named by
# no literal label, so nothing can lift them.
ROOTS="$(sed -n 's|^[[:space:]]*\(/home/claude[A-Za-z_]*\)).*|\1|p' "$TMP/bus.map" | tr '\n' ' ')"
ROOTS="$ROOTS /home/claude1 /home/claude7 /home/claude01 /home/claude07 /home/claude16"
# ⛔ REFUSE rather than grade a roster the lift could not produce: an empty literal-root list would make every
# assertion below vacuously true and print the success shape over nothing (RULES.md — a test that cannot
# measure REFUSES rc=2, it never skips as success).
if [ "$(printf '%s' "$ROOTS" | tr ' ' '\n' | grep -c '^/home/claude_[A-Za-z]')" -lt 2 ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: lifted fewer than two named-HQ roots out of the bus case block --"
    echo "    the block was reshaped and this arm would grade an empty roster. Roster lift: [$ROOTS]"
    rm -rf "$TMP"; exit 2
fi
graded=0
for r in $ROOTS; do
    bus_me="$(S4E="$r" ME="" bash -c '. "$1"; printf "%s" "$ME"' _ "$TMP/bus.map" 2>/dev/null)"
    py_me="$(S4E_HOME="$r" S4E_SEAT="" python3 "$HELPER" seat-name 2>/dev/null)"
    examined=$((examined + 1)); graded=$((graded + 1))
    if [ -z "$bus_me" ] || [ -z "$py_me" ]; then
        echo "GATE FAIL: root $r resolved to nothing (bus='$bus_me' leaderboard='$py_me')"
        violations=$((violations + 1))
    elif [ "$bus_me" != "$py_me" ]; then
        echo "GATE FAIL: root $r — the bus says '$bus_me', the leaderboard says '$py_me'."
        echo "    A drifted map does not crash; it signs somebody else's name to a measurement."
        violations=$((violations + 1))
    fi
done
if [ "$graded" -eq 0 ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: graded zero roots"
    gate_stamp
    exit 2
fi

# ARM 3 — the deliberate asymmetry on an UNRECOGNISED root: the bus NAMES, the leaderboard REFUSES.
examined=$((examined + 1))
u_bus="$(S4E=/home/definitely_not_a_root ME="" bash -c '. "$1"; printf "%s" "$ME"' _ "$TMP/bus.map" 2>/dev/null)"
u_out="$(S4E_HOME=/home/definitely_not_a_root S4E_SEAT="" python3 "$HELPER" seat-name 2>/dev/null)"; u_rc=$?
if [ "$u_bus" != "definitely_not_a_root" ]; then
    echo "GATE FAIL: on an unrecognised root the bus must still name someone (basename fallback), got '$u_bus'"
    violations=$((violations + 1))
fi
if [ "$u_rc" -eq 0 ] || [ -n "$u_out" ]; then
    echo "GATE FAIL: on an unrecognised root the leaderboard must REFUSE, not invent — got rc=$u_rc out='$u_out'."
    echo "    A board row signed with a guessed identity is the unattributed claim this gate exists to kill."
    violations=$((violations + 1))
fi

# ARM 4 — no script may carry a placeholder identity literal. This is the permanent form of the row's
# DONE-WHEN. util_score_row.py is exempt: it is where the placeholders are ENUMERATED in order to be caught.
examined=$((examined + 1))
# ⛔ THIS GATE EXEMPTS ITSELF, for the same reason util_score_row.py is exempt: both must SPELL the
# forbidden strings in order to catch them. The exemption is by exact path, never a pattern, so it
# cannot widen to cover a real offender.
SELF="$(basename "${BASH_SOURCE[0]}")"
# ⛔ THIRD MEMBER OF THE SAME CATEGORY, ADDED 2026-09-06 (hq_I) BECAUSE IT WAS RED ON HEAD AND NO HQ COULD
# LAND. test_gate_progress_append_writes_a_row.sh (hq_T, SCRIP 7a455e68d) spells the placeholder at its own
# line 40 in a `!=` comparison -- it ASSERTS the measurer is NOT the placeholder, which is this arm's own
# purpose written as a test. ⭐ Same collision as ARM 5 versus the deliberate --measurer negative fixture in
# test_gate_score_row_rewrites_in_place.sh, and the general rule is hq_U's: A PREDICATE OVER SOURCE TEXT SEES
# SPELLING, NOT EFFECT, so a gate that greps for a dangerous literal will reliably flag the tests written to
# prove its own rule. Both were green when they landed, a day apart, and neither author could have seen it.
# ⛔ BY EXACT PATH, never a pattern, exactly as this arm's own note requires -- and MEASURED, not pre-empted:
# it is the one offender on disk today, not a category someone might add to. Proven not to blind the arm: a
# scratch script carrying the literal still convicts by name with this exemption in place.
EXEMPT="$SELF|test_gate_progress_append_writes_a_row.sh"
offenders="$(command grep -lE 'unknown-seat|unknown-hq' "$HERE"/*.sh 2>/dev/null | command grep -vE "/($EXEMPT)\$" || true)"
if [ -n "$offenders" ]; then
    echo "GATE FAIL: these scripts carry a placeholder identity literal, which is how 'unknown-seat' reached"
    echo "    the leaderboard the first time (it is non-empty, so it defeats an is-it-set guard):"
    printf '%s\n' "$offenders" | sed 's/^/    /'
    violations=$((violations + 1))
fi

# ARM 5 — every --measurer in a runner is the ONE call shape. A hardcoded identity is worse than a
# placeholder: it is plausible, so nobody reviews it.
examined=$((examined + 1))
# ⛔ SHELL ESCAPING IS NORMALISED AWAY BEFORE MATCHING, AND THE COMPARISON USES NO REGEX.
# handoff_status.sh prints this very call shape as ADVICE inside a double-quoted echo, where it is spelled
# with backslashes -- the same shape, different bytes. Matching raw text reds a correct line; loosening the
# pattern would stop catching real offenders. So strip backslashes and compare against a literal glob.
# ⭐ IT IS A GLOB AND NOT A REGEX ON PURPOSE: two earlier attempts at this arm used awk and grep regexes,
# and BOTH silently graded nothing -- the backslashes were consumed by a shell layer before the regex engine
# ever saw them, so the arm reported every runner as an offender while actually testing an impossible
# pattern. A gate whose matcher is wrong does not go quiet; it goes loud and wrong.
# ⭐⭐ ONE CLASSIFIER, USED BY THE ARM *AND* BY THE ARM THAT PROVES THE ARM (hq_T 2026-09-05). Factored out
# of the loop so the exemption below can be graded without writing a SECOND copy of the rule to grade it
# against -- which is this gate's own founding principle applied one level in: a gate carrying its own
# expected copy of what it checks passes while the thing it checks is wrong.
# rc 0 = sanctioned or exempt · rc 1 = offender.
_measurer_site_ok() {   # $1 = a raw `grep -n` line from a runner
    local _norm="${1//\\/}"
    case "$_norm" in
        *'--measurer "${S4E_SEAT:-}"'*) return 0;;
        # ⛔⭐ A --dry-run CALL SITE IS EXEMPT, AND THE REASON IS THIS ARM'S OWN PURPOSE, NOT A CONVENIENCE
        # (hq_I 2026-09-05, curing a RED that took the whole blocking set with it). ARM 5 exists to stop a row
        # being SIGNED with a hardcoded identity -- "it is plausible, so nobody reviews it", two lines up.
        # `--dry-run` writes no row at all: it previews and exits, so there is no signature to be stale and
        # nothing this arm is protecting. The offender it hunts is a runner that RECORDS under a fixed name.
        # ⭐ WHAT MADE THIS BITE: the only --dry-run call site in the tree is arm d10 of
        # test_gate_score_row_rewrites_in_place.sh, a NEGATIVE FIXTURE whose entire job is to hand the helper a
        # literal measurer and prove it behaves. So the gate reddened the gate that proves the helper works,
        # and since both sit inside `make test`, one deliberate fixture stopped every HQ from landing behind a
        # green blocking set. A grep cannot see intent; it can see that a dry run signs nothing.
        *'--dry-run'*) return 0;;
    esac
    return 1; }
bad=""
while IFS= read -r _line; do
    [ -n "$_line" ] || continue
    _measurer_site_ok "$_line" || bad="$bad$_line"$'\n'
done < <(command grep -n -- '--measurer' "$HERE"/*.sh 2>/dev/null | command grep -v "^$HERE/$SELF:")
if [ -n "$bad" ]; then
    echo "GATE FAIL: a --measurer argument is not the one call shape \"\${S4E_SEAT:-}\" (the helper resolves an"
    echo "    empty one from the root; a literal there signs every future run with a stale name):"
    printf '%s\n' "$bad" | sed "s|$HERE/||; s/^/    /"
    violations=$((violations + 1))
fi

# ARM 5b — ⛔⭐⭐ THE EXEMPTION MUST NOT BLIND THE ARM, AND THAT IS PINNED HERE RATHER THAN RE-VERIFIED BY
# HAND. When the --dry-run exemption landed (hq_I, a6d794b68) it was proved correct in both directions on a
# scratch runner and then the proof was thrown away, so the NEXT person to widen this exemption inherits no
# instrument. An exemption is a hole cut in a gate; the arm that proves the hole is the right shape belongs
# in the gate, permanently, next to the hole. Three synthetic sites, both directions plus the sanctioned form.
# ⭐ THE REASON THIS CLASS EXISTS AT ALL (row gate-arms-and-their-own-fixtures-are-never-graded-against-each-
# other): ARM 5 and the --dry-run fixture in test_gate_score_row_rewrites_in_place.sh were each GREEN when
# they landed, a day apart, by the same owner, and were never graded against each other until a full run
# forced it -- at which point the gate that proves the leaderboard write-path is honest became the single
# thing reddening the blocking set for every HQ.
# ⛔ THESE THREE PROBES ARE THEMSELVES DELIBERATE NEGATIVE INSTANCES LIVING INSIDE A GATE FILE, i.e. exactly
# the shape that caused the incident. They are safe for ONE reason: ARM 5's scan excludes $SELF, and this is
# the only script in the tree that greps for `--measurer` across the others (verified 2026-09-05 -- every
# other hit CALLS it, none scans for it). ⭐ If you ever remove that self-exclusion, or teach another gate to
# scan for this flag, these lines red it. That is not a reason to delete them; it is the reason they are
# annotated here rather than left for someone to rediscover the expensive way.
examined=$((examined + 1))
if _measurer_site_ok '../harness/scripts/x.sh:12:  python3 util_score_row.py write --lang icon --column vendor --measurer hq_B'; then
    echo "GATE FAIL: ARM 5 no longer flags a hardcoded --measurer on a REAL write -- the --dry-run exemption"
    echo "    has been widened until it blinds the arm it was cut into."
    violations=$((violations + 1))
fi
if ! _measurer_site_ok '../harness/scripts/x.sh:12:  python3 util_score_row.py write --lang icon --measurer hq_B --dry-run'; then
    echo "GATE FAIL: ARM 5 flags a --dry-run REHEARSAL site, which signs no row. That is the false positive"
    echo "    that took the whole blocking set down on 2026-09-05 -- a predicate over source text sees"
    echo "    SPELLING, not EFFECT, and will flag the very fixtures written to prove its own rule."
    violations=$((violations + 1))
fi
if ! _measurer_site_ok '../harness/scripts/x.sh:12:  python3 util_score_row.py write --lang icon --measurer "${S4E_SEAT:-}"'; then
    echo "GATE FAIL: ARM 5 flags the ONE sanctioned call shape -- the arm now convicts correct runners."
    violations=$((violations + 1))
fi

# ARM 6 — the shell accessor exists and carries NO map of its own. An accessor that grew a case block would
# be the fourth copy, and would be the one nobody thinks to check.
examined=$((examined + 1))
if ! declare -F s4e_seat_name >/dev/null 2>&1; then
    echo "GATE FAIL: lib_gate.sh defines no s4e_seat_name — bash has no single way to name the seat, which is"
    echo "    how each caller grows its own."
    violations=$((violations + 1))
else
    body="$(declare -f s4e_seat_name)"
    case "$body" in
        *'/home/claude'*)
            echo "GATE FAIL: s4e_seat_name has grown a root->seat map of its own. It must stay a call shape."
            violations=$((violations + 1)) ;;
    esac
fi

echo "    graded $graded known roots + the unrecognised-root asymmetry; maps compared: bus, hook, leaderboard"
GATE_EXAMINED="$examined arms"
gate_verdict "$violations" "seat-identity map copies disagree, or a runner signs with a placeholder"

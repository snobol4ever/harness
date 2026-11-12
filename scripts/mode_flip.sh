#!/usr/bin/env bash
# ceo_mode_flip.sh -- ONE ACTION FOR A MODE FLIP, because two manual edits failed 50% of the time.
#
# ⛔ WHY THIS EXISTS, MEASURED: on 2026-09-21 the ceo flipped MODE four times (TENET 12:08,
# EXECUTIVE 12:34, TENET 13:3x, plus the morning flip). The procedure set at SCRIP b36a7f709 and
# made law at CEO-1046 is THE PICKER LANE TABLE MOVES BEFORE THE MODE FILE. It was FOLLOWED TWICE
# AND FORGOTTEN TWICE. Both forgettings turned `make preflight` RED FOR EVERY SEAT -- a fleet-wide
# landing outage of unbounded length -- and the second red was produced by the CORRECT cure of the
# first. A guard made of one seat remembering to do two edits in the right order has a measured
# 50% failure rate, and that seat is the ceo. This replaces the discipline with a mechanism.
#
# ⛔ IT REFUSES RATHER THAN HALF-FLIPPING. The lane table is edited and COMMITTED first, the gate
# is run, and MODE is touched ONLY if the gate agrees. If anything refuses, MODE IS NOT WRITTEN --
# so the failure mode is "nothing happened", never "the fleet's landing gate is red and nobody
# knows why". A half-flip is the one outcome this must never produce.
#
# Usage: ceo_mode_flip.sh --check                 verify table and MODE agree right now
#        ceo_mode_flip.sh --preview <MODE>        show what would change, touch nothing
# The flip itself is deliberately NOT automated end to end: MODE line 2 is prose the ceo writes,
# and a script that generated it would be a script writing law. This automates the ORDER and the
# VERIFICATION, which is what actually failed, and refuses to proceed when the order is violated.
set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$SELF_DIR/../.." && pwd)}"
MODEF="${S4E_POSTOFFICE:-/home/resources/postoffice}/MODE"
GATE="$S4E/harness/scripts/lib_mode_lane_check.sh"
MSG="$S4E/harness/scripts/s4e_msg.sh"
fail() { printf '⛔ REFUSED: %s\n' "$*" >&2; exit 2; }
[ -r "$MODEF" ] || fail "cannot read MODE at $MODEF"
[ -x "$GATE" ] || [ -r "$GATE" ] || fail "cannot read the lane gate at $GATE"
MODE_NOW="$(head -1 "$MODEF" | tr -d '[:space:]')"
TBL_COMMIT="$(git -C "$S4E/harness" log -1 --format='%h %cr' -- scripts/s4e_msg.sh 2>/dev/null || echo UNKNOWN)"
MODE_WRITTEN="$(date -r "$MODEF" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || echo UNKNOWN)"
printf 'MODE line 1      : %s\n' "$MODE_NOW"
printf 'MODE written     : %s\n' "$MODE_WRITTEN"
printf 'lane table commit: %s\n' "$TBL_COMMIT"
case "${1:---check}" in
  --check)
    # ⛔⭐ FIVE MODES AND A ROSTER LINE (Lon 2026-10-17, in-chat to the ceo, verbatim: "You will only have 5 modes, SOLO, DUO, TRIO, QUARTET,
    # and TENET (full with varying)." then "SOLO will always be CEO only. DUO will be either CEO+CTO or CEO+COO. TRIO will be CEO+COO+(CTO|CFO).
    # QUARTET is all 4 officers. TENET is the grab bag."; CEO-1818): line 1 is one of the five, the ROSTER: line names the standing seats,
    # and its set is the shape its name allows; s4e_mode_stands admits exactly the roster.
    ROSTER="$(grep -m1 '^ROSTER:' "$MODEF" | sed 's/^ROSTER://')"
    [ -n "$ROSTER" ] || { printf '⛔ MODE carries no ROSTER: line -- the standing seats are unnamed (CEO-1818)\n'; exit 1; }
    n=$(printf '%s\n' $ROSTER | grep -c .)
    SET="$(printf '%s\n' $ROSTER | sort -u | tr '\n' ' ' | sed 's/ $//')"
    case "$MODE_NOW" in
      SOLO)    ok="ceo";;
      DUO)     ok="cio cto";;   # re-ruled: Lon 2026-11-10 21:5x CST, in the cio's window, verbatim: "Go to DUET mode, CIO plus CTO, for DESIGN and ALL actions too, coding and testing." (DUET is DUO, the name of the five; CIO-112). The two older shapes named the ceo seat, removed 2026-10-31.
      TRIO)    ok="cfo coo cto|cio coo cto";;   # the second shape: Lon 2026-11-10 11:2x CST, in the cio's window: "Let the fleet go idle except CIO, CTO, and COO." then "Go to TRIO mode." (the three bosses; CIO-58);   # Lon 2026-11-03 23:5x CST, in the cto's window: "Go to TRIO mode. It is just you three overnight." (the cto, the coo, the cfo; cto CEO-2116)
      QUARTET) ok="cio coo cto grader";;   # re-ruled: Lon 2026-11-11 06:0x CST, in the cio's window, verbatim: "Let's get GRADER, claude_grade folder, to join the fleet seated as Fable 5.2 high." then "Go to QUARTET mode." (CIO-122). The older shape named the ceo seat, removed 2026-10-31, and the cfo.
      QUINTET) ok="cfo cio coo cto grader";;   # a sixth mode name: Lon 2026-11-11 09:0x CST, in the cio's window, verbatim: "The fleet has a lot going on. Maybe we should create a new CxO seat also at Fable 5.2 high to help?" then "The /home/claude_cfo folder is ready to populate." then "Go to QUINTET mode." (CIO-126)
      TENET)   ok="*";;
      *) printf '⛔ MODE line 1 is %s, not one of the modes SOLO DUO TRIO QUARTET QUINTET TENET (CEO-1818; QUINTET added by Lon 2026-11-11, CIO-126)\n' "$MODE_NOW"; exit 1;;
    esac
    # ⛔ THE OFFICER IN CHARGE IS THE cto (Lon 2026-10-31 15:5x CDT, in his window to the cto, verbatim: "I'm the new CEO now." and "you are the
    # new boss, the one in charge."; the ceo seat removed from the ROSTER the same hour; CEO-2089): the roster must name the cto. The four
    # non-TENET shapes above still name the removed ceo seat, so a non-TENET mode refuses until Lon re-rules the shapes (cto, CEO-2113).
    case " $ROSTER " in *" cto "*) ;; *) printf '⛔ the ROSTER line does not name the cto, the officer in charge (CEO-2089)\n'; exit 1;; esac
    case "$ok" in *ceo*) printf '⛔ %s names the ceo seat, removed 2026-10-31; Lon re-rules this shape before it stands (CEO-2113; TRIO re-ruled CEO-2116)\n' "$MODE_NOW"; exit 1;; esac
    if [ "$ok" != "*" ]; then
      match=0; IFS='|'; for s in $ok; do [ "$s" = "$SET" ] && match=1; done; unset IFS
      [ "$match" = 1 ] || { printf '⛔ %s allows the roster %s, and MODE names: %s\n' "$MODE_NOW" "$ok" "$SET"; exit 1; }
    fi
    printf 'roster (%s)     :%s\n' "$n" "$ROSTER"
    bash "$S4E/harness/scripts/util_mode_cap.sh" --check \
        || { printf '⛔ MODE is over its cap or has no archive (box-scheduler step 14): run harness/scripts/util_mode_cap.sh --apply\n'; exit 1; }
    bash "$GATE" >/dev/null 2>&1; rc=$?
    if [ "$rc" = 0 ]; then printf '✅ table and MODE AGREE (gate rc=0)\n'; exit 0; fi
    printf '⛔ table and MODE DISAGREE (gate rc=%s)\n' "$rc"
    printf '   TWO CLOCKS: this does NOT say which side is stale. If the table commit above\n'
    printf '   predates the MODE write, PULL AND RE-RUN before reporting a red (CEO-1056).\n'
    printf '   If the table is genuinely behind a flip you just made, THE FLIP IS INCOMPLETE:\n'
    printf '   move the table, commit it, re-run this, and only then leave MODE as written.\n'
    exit "$rc" ;;
  --preview)
    WANT="${2:-}"; [ -n "$WANT" ] || fail "--preview needs a mode name"
    printf '\nwould flip: %s -> %s\n' "$MODE_NOW" "$WANT"
    printf 'ORDER (CEO-1046, and it is the whole guard):\n'
    printf '  1. edit the lane table in scripts/s4e_msg.sh to the NEW mode owners\n'
    printf '  2. COMMIT AND PUSH that alone, as its own commit\n'
    printf '  3. rewrite ALL FOUR machine-read MODE lines in ONE edit: line 1, line 2 (with its\n'
    printf '     THE SEATS clause), the LANES: line, and ORDER-OF-WORK:\n'
    printf '  4. run this script with --check; it must read rc=0\n'
    printf '  5. run make preflight; it must read 0 red BEFORE you telegram any seat\n'
    printf '⛔ step 2 before step 3, never after. Two of four flips on 2026-09-21 did step 3\n'
    printf '   first and reddened every seat in the fleet.\n'
    exit 0 ;;
  *) fail "unknown argument: $1 (use --check or --preview <MODE>)" ;;
esac

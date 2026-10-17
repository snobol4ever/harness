#!/usr/bin/env bash
# lib_handoff_verdict.sh -- THE LANE OF AN OWED .s ARTIFACT, A SEAT'S LANES, AND WHAT OWED DEBT DOES TO A HANDOFF VERDICT (coo
# 2026-09-16; hq_prolog's and hq_snobol4's witnesses; row handoff-status-artifact-check-blocks-every-seat-for-one-lanes-debt-and-
# a-refused-check-still-reads-complete). Sourced by handoff_status.sh and by its gate; every function prints, never exits.
#
# THE TWO FACES OF ONE DEFECT: (1) handoff_status.sh's .s-artifact check was FLEET-WIDE while the debt is LANE-OWNED -- 27 owed .s
# artifacts, all Prolog, read BLOCKED to hq_snobol4 whose lane was clean, and the printed remedy told that innocent seat to
# regenerate another lane's evidence (a plausible, green, WRONG artifact set); (2) the same check, refusing on a stale binary
# (rc=2, warn-only), let the composite print CHAT SESSION COMPLETE with the check never having run. THE GENERAL FORM (hq_prolog):
# A SUB-CHECK THAT COULD NOT MEASURE MUST MAKE THE COMPOSITE REFUSE, NEVER PASS -- and the remedy printed is part of the verdict.

# handoff_lane_of_artifact <repo-relative path>  -> the language lane that owns it (benchmarks/<lang>/..., demos/<lang>/...,
# prolog_bench -> prolog, icon_bench -> icon), or 'unknown'
handoff_lane_of_artifact() {
  local p="$1"
  case "$p" in
    prolog_bench:*|*/prolog_bench/*) printf 'prolog\n';;
    icon_bench:*|*/icon_bench/*|benchmarks/icon/*) printf 'icon\n';;
    benchmarks/*/*|demos/*/*) printf '%s\n' "$p" | cut -d/ -f2;;
    *) printf 'unknown\n';;
  esac
}
# handoff_seat_lanes <seat> [MODE file] -> the languages MODE's LANES: line gives that seat (space-separated; empty for an officer
# that owns none -- coo, ceo, cto today)
handoff_seat_lanes() {
  local seat="$1" mode="${2:-${S4E_POST:-/home/resources/postoffice}/MODE}" lanes
  lanes="$(grep -m1 '^LANES:' "$mode" 2>/dev/null | sed 's/^LANES://')"
  printf '%s' "$lanes" | tr ' ' '\n' | awk -F= -v s="$seat" '$2==s{print $1}' | tr '\n' ' ' | sed 's/ $//'
}
# handoff_lane_owner <lang> [MODE file] -> the seat LANES: names for that language, or '' when none
handoff_lane_owner() {
  local lang="$1" mode="${2:-${S4E_POST:-/home/resources/postoffice}/MODE}"
  grep -m1 '^LANES:' "$mode" 2>/dev/null | sed 's/^LANES://' | tr ' ' '\n' | sed -n "s/^$lang=//p" | head -1
}
# handoff_owed_verdict <seat> <owed file list, one repo-relative path per line> [MODE file]
#   prints one line per lane: BLOCK (the seat's own lane owes) or INFO (another seat's lane owes, that seat named, the remedy
#   addressed to it); rc 1 when this seat is blocked, 0 otherwise. An officer that owns no language is never blocked by artifact
#   debt and sees every lane's debt as INFO.
handoff_owed_verdict() {
  local seat="$1" files="$2" mode="${3:-${S4E_POST:-/home/resources/postoffice}/MODE}" mine lane n owner blocked=0
  mine=" $(handoff_seat_lanes "$seat" "$mode") "
  for lane in $(printf '%s\n' "$files" | grep . | while read -r f; do handoff_lane_of_artifact "$f"; done | sort -u); do
    n="$(printf '%s\n' "$files" | grep . | while read -r f; do [ "$(handoff_lane_of_artifact "$f")" = "$lane" ] && echo x; done | grep -c .)"
    owner="$(handoff_lane_owner "$lane" "$mode")"
    if [ "$lane" != unknown ] && [[ "$mine" == *" $lane "* ]]; then
      printf 'BLOCK lane=%s owed=%s -- YOUR lane (%s): regenerate with the three regen scripts (RULES.md handoff step 4) and commit the artifacts\n' "$lane" "$n" "$seat"; blocked=1
    elif [ "$lane" = unknown ]; then
      printf 'BLOCK lane=unknown owed=%s -- artifacts whose lane cannot be read from their path; named below, nobody is cleared of them\n' "$n"; blocked=1
    else
      printf 'INFO  lane=%s owed=%s -- owed by %s, not by %s: do NOT regenerate evidence of another lane; %s regenerates and commits them\n' "$lane" "$n" "${owner:-no seat named on the LANES: line}" "$seat" "${owner:-the HQ of that lane}"
    fi
  done
  return $blocked
}

#!/usr/bin/env bash
# lib_suites_tsv.sh -- THE ONE AUTHORITY ON WHERE THE SUITE TABLE IS.
#
# ⛔⭐⭐ ONE FILE, ONE LOCATION (Lon 2026-10-09 15:2x CDT, in-chat to the coo, verbatim: "You choose to put the one single data location to be
# spread across all root via GitHub instead of choosing one file in /home/resources. That was stupid."). SUITES.tsv lived in .github, so every
# root read its own clone of it, as current as that seat's last pull: hq_collector's banner read 27 suites at 100% while the coo's read 31.
# The record is now /home/resources/progress/SUITES.tsv beside the progress database, and every seat root reads and writes that one file.
#
#   suites_tsv [ROOT]   prints the path: S4E_SUITES_TSV when set (a fixture's scratch table); else the one file for a seat root
#                       (/home/claude_<seat>) or no root; else ROOT/.github/SUITES.tsv -- a scratch root keeps its scratch table, so a
#                       fixture that redirects S4E_HOME alone never reads or writes the real record. util_score_row.py holds the same rule.
SUITES_TSV_REAL=/home/resources/progress/SUITES.tsv
suites_tsv() {
  local root="${1:-}"
  if [ -n "${S4E_SUITES_TSV:-}" ]; then printf '%s\n' "$S4E_SUITES_TSV"; return 0; fi
  if [ -z "$root" ] || [[ "$(realpath -m "$root")" =~ ^/home/claude_[A-Za-z0-9_]+$ ]]; then printf '%s\n' "$SUITES_TSV_REAL"; return 0; fi
  printf '%s\n' "$root/.github/SUITES.tsv"
}
#
#   suites_real_mark          the shared record's state before a fixture runs: its md5 and the line count of SUITES.history.tsv beside it
#   suites_real_untouched M   rc 0 when the shared record still matches mark M, or every change since is a history line another session wrote
#                             (the testing officer's loop writes rows while other seats run gates; a write from this gate's session reds)
suites_real_mark() {
  printf '%s %s\n' "$(md5sum < "$SUITES_TSV_REAL" 2>/dev/null | cut -c1-32)" "$(wc -l < "${SUITES_TSV_REAL%/*}/SUITES.history.tsv" 2>/dev/null || echo 0)"
}
suites_real_untouched() {
  local md5 n new sid
  read -r md5 n <<<"$1"
  [ -n "$md5" ] || return 1
  [ "$(md5sum < "$SUITES_TSV_REAL" 2>/dev/null | cut -c1-32)" = "$md5" ] && return 0
  new="$(tail -n +"$((n + 1))" "${SUITES_TSV_REAL%/*}/SUITES.history.tsv" 2>/dev/null | grep -v '^#')"
  [ -n "$new" ] || return 1
  sid="$(ps -o sid= -p $$ | tr -d ' ')"
  awk -F'\t' -v s="$sid" '$3 == s {f = 1} END {exit f}' <<<"$new"
}

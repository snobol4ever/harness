#!/usr/bin/env bash
# util_queue_dangling_blocker.sh -- row `picker-dangling-blocker-parks-a-row-forever-in-silence` (hq_B mint 2026-08-29), cure (2).
#
# ⛔⭐ THE DEFECT THIS EXISTS FOR: a row's state column can read BLOCKED-ON:<name>/PARKED-AWAITING:<name> where <name> is
# not a real row at all -- a sub-item gloss appended to a real topic ("icon-n2-generator-activation-frames-items-3-4",
# meaning "items 3-4 of icon-n2-generator-activation-frames"), a typo, or a topic that was renamed/retired. The two
# mechanisms that would ever free such a row both key on the blocker NAME: the promotion walk's dangling branch
# ("no row exists to serve") and the self-heal check (s4e_blocker_done, which needs a claim/QUEUE.done.tsv hit for
# that exact name) both just silently return false forever. MEASURED (hq_B, queue-wide sweep, 2026-08-29):
# prolog-pz4-gamma-retain-activation-frames named exactly this shape; 3 more rows sat parked behind pz4, all
# unresolvable until a human happened to notice. `s4e_msg.sh park` now REFUSES (rc=2) writing a new dangling
# blocker (cure 1) -- this script is cure 2, for the ones already written before that guard existed, or written
# some other way (direct QUEUE.tsv edit).
#
# ⛔ THIS SCRIPT ONLY REPORTS. It never edits QUEUE.tsv and never touches a claim -- repairing a dangling block
# (re-point it at the real row, or park FREE if the intended blocker no longer applies) is a judgement call with
# an owner, exactly per util_queue_donewhen_state_disagree.sh's own precedent.
#
# A blocker name counts as REAL (not dangling) if it is either a live QUEUE.tsv row, or already swept into
# QUEUE.done.tsv -- the same two facts s4e_msg.sh's own qrow()/s4e_blocker_done() consult, so this script flags
# exactly what the now-fixed `park` would have refused, no more and no less.
#
# usage: bash ../harness/scripts/util_queue_dangling_blocker.sh [--quiet]
#        S4E_QUEUE=/path/to/QUEUE.tsv  S4E_QUEUE_DONE=/path/to/QUEUE.done.tsv   (overrides, for testing this script's own arms)
# exit:  0 = no dangling blocker found   1 = at least one dangling blocker found   2 = REFUSES (cannot measure)
set -u
PO="${S4E_PO:-/home/resources/postoffice}"
QUEUE="${S4E_QUEUE:-$PO/QUEUE.tsv}"
QUEUE_DONE="${S4E_QUEUE_DONE:-$PO/QUEUE.done.tsv}"
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1
# ⛔ REFUSE, NEVER SKIP-AS-SUCCESS: an audit that cannot read its inputs must not print a clean board (RULES.md).
[ -r "$QUEUE" ] || { echo "⛔ REFUSES rc=2: cannot read QUEUE at $QUEUE" >&2; exit 2; }
rows="$(grep -v '^#' "$QUEUE" | awk -F'\t' 'NF>=4 && $2!=""')"
[ -n "$rows" ] || { echo "⛔ REFUSES rc=2: QUEUE at $QUEUE has zero parsable rows -- wrong file, or the format changed" >&2; exit 2; }
live_topics="$(printf '%s\n' "$rows" | awk -F'\t' '{print $2}' | sort -u)"
[ -n "$live_topics" ] || { echo "⛔ REFUSES rc=2: zero live topics parsed -- the topic column is not where this script thinks it is" >&2; exit 2; }
done_topics=""
if [ -r "$QUEUE_DONE" ]; then
  done_topics="$(grep -v '^#' "$QUEUE_DONE" 2>/dev/null | awk -F'\t' 'NF>=2 && $2!=""{print $2}' | sort -u)"
fi
# ⛔ QUEUE.done.tsv is OPTIONAL, not required: a fresh/test root may genuinely have swept nothing yet. Only the
# live QUEUE is load-bearing enough to refuse on (checked above) -- an absent or empty done-file is real, not a
# read failure, so it must not REFUSE the whole audit.
n_dangling=0; out=""
while IFS=$'\t' read -r rank topic owner state; do
  case "$state" in
    BLOCKED-ON:*|PARKED-AWAITING:*) blk="${state#*:}" ;;
    *) continue ;;
  esac
  [ -n "$blk" ] || continue
  found=0
  printf '%s\n' "$live_topics" | grep -qxF "$blk" && found=1
  [ "$found" = 0 ] && [ -n "$done_topics" ] && printf '%s\n' "$done_topics" | grep -qxF "$blk" && found=1
  if [ "$found" = 0 ]; then
    n_dangling=$((n_dangling+1))
    out="$out  ⛔ rank $rank  $topic  (owner $owner)  state=$state\n      blocker \"$blk\" is not a QUEUE.tsv row (live or swept-done) -- this park can NEVER self-clear\n"
  fi
done <<< "$rows"
if [ "$QUIET" = 0 ] || [ "$n_dangling" -gt 0 ]; then
  echo "queue dangling-blocker audit -- $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "  scanned $(printf '%s\n' "$rows" | wc -l) row(s) from $QUEUE against $(printf '%s\n' "$live_topics" | wc -l) live + $([ -n "$done_topics" ] && printf '%s\n' "$done_topics" | wc -l || echo 0) swept-done topic(s)"
fi
if [ "$n_dangling" -gt 0 ]; then
  printf '⛔ %d row(s) parked behind a DANGLING blocker -- permanently and silently stuck until repaired by hand:\n' "$n_dangling"
  printf "$out"
  echo "  -> re-point each (s4e_msg.sh park <topic> BLOCKED-ON:<the real row>) or park FREE if the intended blocker no longer applies."
  echo "     If the blocker names a SUB-ITEM of a real row, name the ROW itself here and put the sub-item detail in that row's baton prose."
  exit 1
fi
[ "$QUIET" = 0 ] && echo "✅ no BLOCKED-ON:/PARKED-AWAITING: row names a dangling blocker"
exit 0

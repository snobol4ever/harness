#!/usr/bin/env bash
# util_queue_donewhen_state_disagree.sh -- row `perf-roman-8x` umbrella (hq_P 2026-08-27 rank0-picker-livelock), cure (1), minted on hq_B's measured witness 2026-08-29.
#
# ⛔⭐ THE DEFECT THIS EXISTS FOR: A ROW'S DONE-WHEN IS PROSE THE PICKER NEVER READS; ITS STATE COLUMN IS WHAT THE PICKER OBEYS; AND NOTHING CHECKS THEY AGREE.
# `icon-bench-correct-suspend-residue`'s DONE-WHEN began "after N-2 lands" while its state column read FREE.  The picker served it, correctly by its own rules, to NINE
# consecutive sessions on 2026-08-29 (11:42 12:07 12:18 12:37 14:55 15:08 15:13 15:24 15:29) -- all zero-cure, ten NEXT blocks, ten "not worked" markers.
# ⭐ AND THE LOSS ACCELERATES, WHICH IS THE PART WORTH UNDERSTANDING: a rank-0 FREE row is the top free row for a share of the fleet that GROWS as other rows get claimed,
# so the pump runs FASTEST exactly when the fleet is busiest -- the measured curve was 4-in-55min, then 5-in-34min.  Witness + arithmetic: hq_B, .github 43061128.
#
# ⭐⭐ AND THE PUMP IS INVISIBLE FROM INSIDE A SINGLE SESSION, WHICH IS WHY IT NEEDED COUNTING RATHER THAN NOTICING (hq_P, adopted into this header at hq_B's
# suggestion): the umbrella's own owner was ONE OF THE NINE -- served the row, re-scored its board, released, and did not notice. Each session's own work
# looks locally reasonable: you pull, you measure, you record honestly, you release. The waste exists only in the aggregate, so no participant can see it.
# ⛔ That is the argument for an instrument over a habit, and it is why "just be careful" was never going to work here.
#
# ⚠️ A THIRD CLASS THIS SCRIPT DOES NOT YET NAME (hq_B, 2026-08-29): a PARTIALLY-GATED row, where the gated and the workable parts live in ONE row -- so
# neither FREE nor PARKED is honest, and both classes below misreport it. `tests-consolidate-prolog` is the worked example: 4 consecutive sessions
# re-derived the same external block, yet its items 3-7 held real tractable work (measured -- a later pass converted 13 files from exactly those items).
# ⛔ Parking it would have HIDDEN workable work; leaving it FREE kept re-serving the blocked half. The cure is probably to SPLIT the row, which is a
# judgement call with an owner and therefore not something an audit may do. Named here so the next reader does not try to force it into Class A or B.
#
# ⛔ THIS SCRIPT ONLY REPORTS.  It never edits QUEUE.tsv and never touches a claim -- parking a row is a judgement call with an owner, and an audit that silently re-states
# the queue would be a second uncheckable authority over the same column.  Fix the row, or fix the DONE-WHEN.
#
# usage: bash ../harness/scripts/util_queue_donewhen_state_disagree.sh [--quiet]
#        S4E_QUEUE=/path/to/QUEUE.tsv  S4E_TASKS=/path/to/tasks   (overrides, for testing this script's own arms)
# exit:  0 = no disagreement   1 = at least one FREE row names a live blocker in its DONE-WHEN   2 = REFUSES (cannot measure)
set -u
PO="${S4E_PO:-/home/resources/postoffice}"
QUEUE="${S4E_QUEUE:-$PO/QUEUE.tsv}"
TASKS="${S4E_TASKS:-$PO/tasks}"
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1
# ⛔ REFUSE, NEVER SKIP-AS-SUCCESS: an audit that cannot read its inputs must not print a clean board (RULES.md).
[ -r "$QUEUE" ] || { echo "⛔ REFUSES rc=2: cannot read QUEUE at $QUEUE" >&2; exit 2; }
[ -d "$TASKS" ] || { echo "⛔ REFUSES rc=2: no tasks dir at $TASKS" >&2; exit 2; }
rows="$(grep -v '^#' "$QUEUE" | awk -F'\t' 'NF>=4 && $2!=""')"
[ -n "$rows" ] || { echo "⛔ REFUSES rc=2: QUEUE at $QUEUE has zero parsable rows -- wrong file, or the format changed" >&2; exit 2; }
# A topic is LIVE if its state is not a terminal one.  ⭐ Terminal set is spelled out rather than "not DONE": PARKED/BLOCKED rows are still live blockers, which is the point.
live_topics="$(printf '%s\n' "$rows" | awk -F'\t' '{st=$4; sub(/:.*/,"",st); if(st!="DONE" && st!="SUPERSEDED" && st!="RETIRED") print $2}' | sort -u)"
[ -n "$live_topics" ] || { echo "⛔ REFUSES rc=2: zero live topics parsed -- the state column is not where this script thinks it is" >&2; exit 2; }
n_free=0; n_blk=0; n_nc=0; out_blk=""; out_nc=""
while IFS=$'\t' read -r rank topic owner state; do
  [ "$state" = "FREE" ] || continue
  n_free=$((n_free+1))
  f="$TASKS/$topic.task.md"; [ -r "$f" ] || continue
  # DONE-WHEN text = from the DONE-WHEN: marker up to the next top-level marker (LINKS:/## ), which is where the closing criterion ends.
  dw="$(awk '/^DONE-WHEN:/{f=1} f&&/^(LINKS:|## )/{exit} f' "$f")"
  [ -n "$dw" ] || continue
  blk=""; nocrit=0
  while IFS= read -r lt; do
    [ "$lt" = "$topic" ] && continue                       # self-mention is not a blocker
    case "$dw" in *"$lt"*) ;; *) continue;; esac
    # ⛔ SUBSTRING IS NOT A MATCH: `icon-n2-generator-activation-frames` is a prefix of `...-items-3-4`.  Require the char after the hit to not extend the topic name.
    printf '%s' "$dw" | grep -qE "(^|[^A-Za-z0-9_-])${lt//./\\.}([^A-Za-z0-9_-]|\$)" || continue
    st="$(printf '%s\n' "$rows" | awk -F'\t' -v t="$lt" '$2==t{print $4; exit}')"
    blk="$blk    names live topic: $lt  [state: $st]\n"
  done <<< "$live_topics"
  # ⛔⭐ SECOND, INDEPENDENT, STRICTLY CHEAPER DETECTOR (hq_P, found while negative-testing the first): a DONE-WHEN that is a hard-coded refusal --
  # `echo "...not mintable until X..." >&2; false` -- is UNSATISFIABLE BY CONSTRUCTION.  It needs no topic vocabulary to detect and it is a stronger
  # signal than naming a live topic: the row is not merely blocked, it has DECLARED ITSELF UNCLOSABLE and is still advertising FREE to the picker.
  # ⭐ Both rows the vocabulary check found turned out to be this shape too, which is what surfaced it.  Kept as its own class so the two are never conflated.
  # ⛔⭐ THIRD DETECTOR, AND IT IS THE ONE THAT CATCHES hq_B's ACTUAL WITNESS -- ADDED ONLY BECAUSE THE POSITIVE CONTROL FAILED.
  # The vocabulary check above misses `icon-bench-correct-suspend-residue` entirely: its DONE-WHEN opens "after N-2 lands", which is HUMAN SHORTHAND, not
  # the topic name `icon-n2-generator-activation-frames`.  ⭐ An audit built for a witness that does not fire on that witness is worse than none -- it reports
  # a clean board over the exact defect it was minted for.  Found by running the control, not by reading the code.
  # ⭐ Deliberately a NARROW prose shape, not a parser (hq_B scoped a grep): "DONE-WHEN: after|once|when ... lands|landed|is DONE|completes".
  # MEASURED before adopting: matches the witness, and hits ZERO of the 159 live FREE rows -- so it is adding signal, not noise.
  printf '%s' "$dw" | grep -qiE 'DONE-WHEN: *(after|once|when) .{0,60}(lands|landed|is DONE|completes)' \
    && blk="$blk    DONE-WHEN opens with a prose temporal dependency (\"after X lands\") -- names a blocker the picker cannot resolve\n"
  case "$dw" in *"; false"*|*"; false") nocrit=1;; esac
  if [ -n "$blk" ]; then n_blk=$((n_blk+1)); out_blk="$out_blk  ⛔ rank $rank  $topic  (owner $owner)\n$blk"; fi
  if [ "$nocrit" = 1 ]; then n_nc=$((n_nc+1)); out_nc="$out_nc  ⚠️ rank $rank  $topic  (owner $owner)\n"; fi
done <<< "$rows"
if [ "$QUIET" = 0 ] || [ "$n_blk" -gt 0 ]; then
  echo "queue DONE-WHEN vs state-column audit -- $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "  scanned $n_free FREE row(s) against $(printf '%s\n' "$live_topics" | wc -l) live topic(s) from $QUEUE"
fi
# ⛔⭐ TWO CLASSES, TWO COUNTERS, DELIBERATELY NOT MERGED -- they have different causes, different owners and different cures, and merging them would
# report a 10x bigger "livelock" than exists.  Class A is hq_B's measured pump: the seat can do NOTHING, because the work belongs to another row.
# Class B is a row that is perfectly workable -- its FIRST step is to write its own criterion -- but that CANNOT BE CLOSED by `done` until someone does.
# ⭐ A is an active loss (nine sessions in 3h47m).  B is a latent one: it only pumps if seats keep declining to mint the criterion.  Never quote them as one number.
if [ "$n_blk" -gt 0 ]; then
  printf '⛔ CLASS A -- BLOCKED BUT ADVERTISING FREE: %d row(s). The picker cannot see this and will serve them; a seat that takes one can do nothing.\n' "$n_blk"
  printf "$out_blk"
  echo "  -> park each (PARKED-AWAITING:<blocker>, which self-clears) or rewrite the DONE-WHEN so it no longer depends on that topic. Do not raise an allowance."
fi
if [ "$n_nc" -gt 0 ]; then
  printf '⚠️ CLASS B -- NO COMPUTABLE DONE-WHEN (hard-coded refusal): %d row(s). Workable, but UNCLOSABLE until the criterion is written, so each one is a latent pump.\n' "$n_nc"
  [ "$QUIET" = 0 ] && printf "$out_nc"
  echo "  -> not a blocker: the row's own first step IS to write a command that can exit non-zero. Listed so the count is visible, not so the rows get parked."
fi
[ "$n_blk" -gt 0 ] && exit 1
[ "$QUIET" = 0 ] && [ "$n_nc" -eq 0 ] && echo "✅ no FREE row names a live topic in its DONE-WHEN, and none carries a placeholder criterion"
exit 0

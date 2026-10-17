#!/bin/bash
# ../harness/scripts/util_raku_roast_ablation_ranker.sh -- RANK A CURE BY ABLATION, NEVER BY FREQUENCY (hq_raku 2026-09-16,
# baton raku-every-roast-file-run-graded-against-rakudo-or-named-ungradable, TAKE NEXT item 1).
#
# ⛔⭐ THE INSTRUMENT THIS ROW LACKED, AND WHY THE ROW STALLED WITHOUT IT. raku_roast_scoreboard.sh --inventory
# prints ROAST_TOP_BLOCKING_CONSTRUCTS: a frequency histogram of the source line each file's parse died on.
# That list is A QUEUE, NOT A BOTTLENECK -- it ranks what each file hits FIRST, which is not what is BLOCKING
# it, and curing the head of the list merely advances those files to their next error. THE MEASUREMENT that
# settled it (hq_T 2026-09-14): the top entry headed 59 files; deleting that line from all 59 left 57 still
# parse-failing on ~40 different next constructs and moved EXACTLY ZERO into a graded bucket. The cure was
# fully defensible from the histogram and would have bought nothing.
# ⭐ SO THE ONLY HONEST UNLOCK METRIC IS ABLATION: remove the construct, re-run, and count FILES THAT MOVED.
# Frequency is where the queue is LONG; value is where the queue is SHORT BEHIND IT, and those are different
# lists. This script computes the second one. Frequency is used ONLY to nominate candidates -- never to rank
# them -- because you must start the ablation somewhere and the histogram is a free ordering of where files are.
#
# ⛔ IT WRITES NOTHING: no SCORE row, no RAKU-COVERAGE.md, no board. ONE RUNNER ONE BOARD is untouched
# (CEO-744) -- this publishes nothing and grades no published population, so it is admitted to any seat on
# the CEO-547 rule that a board is what it GRADES AND PUBLISHES.
# ⛔ IT REFUSES rc=2 RATHER THAN PRINTING THE SUCCESS SHAPE over a population it could not measure, and it
# PRINTS ITS DENOMINATOR on every line (CLAUDE.md § Testing).
#
# Usage: bash ../harness/scripts/util_raku_roast_ablation_ranker.sh [--limit N] [--candidates K] [--section S03]
#   --limit N       census only the first N shipped .t files (bound the cost; default all)
#   --candidates K  ablate the K most frequent first-error constructs (default 8)
#   --section S     only files whose path starts with this prefix
#   --census-out F  ALSO write the per-file census (rel/bucket/line/construct) to F, tab separated.
#                   ⛔ THIS IS NOT PUBLISHING: F is a path the OPERATOR names, never a SCORE row, a
#                   leaderboard cell or RAKU-COVERAGE.md, and nothing reads it unless a human points at it.
#                   ⭐ IT EXISTS BECAUSE THE CENSUS WAS BEING THROWN AWAY: every follow-up question about
#                   the buckets ("which 3 files time out", "which 14 hit the emitter") cost a fresh ~9-minute
#                   full pass, so the cheap questions were priced like the expensive one and went unasked.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/../../SCRIP" || exit 2
ROOT=$(pwd)
SCRIP="$ROOT/scrip"
. "$HERE/lib_raku_roast_bucket.sh" || { echo "⛔ REFUSE(2): lib_raku_roast_bucket.sh unavailable" >&2; exit 2; }
command -v roast_bucket >/dev/null 2>&1 || { echo "⛔ REFUSE(2): lib_raku_roast_bucket.sh missing roast_bucket -- the ranker must use the SAME bucket rule as the census it ranks" >&2; exit 2; }
# ⛔ A STALE BINARY MAKES EVERY ABLATION NUMBER FICTION, and unlike a board this instrument has no tree stamp
# to betray it (FINDING-2026-08-30-hq_C: a board grades whatever scrip exists and labels it with git HEAD).
if ! . "$HERE/lib_gate.sh" 2>/dev/null || ! command -v gate_require_fresh >/dev/null 2>&1; then
  echo "⛔ REFUSE(2): lib_gate.sh unavailable or missing gate_require_fresh -- cannot verify binary freshness" >&2; exit 2
fi
gate_require_fresh "$ROOT" src "$SCRIP" "$ROOT/out/libscrip_rt.so"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip binary (run: make)" >&2; exit 2; }
roast_resolve_population "$ROOT" || exit 2

LIMIT=0; CANDS=8; SECTION=""; CENSUS_OUT=""; DEPTH=0; SAMPLE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --limit) LIMIT="$2"; shift 2 ;;
    --candidates) CANDS="$2"; shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    --census-out) CENSUS_OUT="$2"; shift 2 ;;
    --depth) DEPTH="$2"; shift 2 ;;
    --sample) SAMPLE="$2"; shift 2 ;;
    *) echo "⛔ REFUSE(2): unknown argument '$1' -- this instrument names what it does not understand rather than treating it as a filename" >&2; exit 2 ;;
  esac
done
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
CSV="$TMP/census.tsv"; : > "$CSV"

# \u26d4 CALLERS INVOKE THIS AS `run_one <f> 2>/dev/null`: a witness that dies on SIGSEGV/SIGABRT makes
# bash report "Segmentation fault" to the RANKER's own stderr as it reaps the child, interleaving compiler
# crashes into the instrument's report. The crash is still CAPTURED in "$se" and classified either way (a
# rc>=124 is UNGRADABLE-TIMEOUT, a signal death lands in the TAP classifier), so the notice carries no
# information the buckets do not already hold. \u26d4 Redirecting INSIDE the command cannot suppress it --
# the shell prints it at reap time, in the caller.
run_one() {  # $1=file to run -> sets B_BUCKET B_LINE B_KEY
  local f="$1" so="$TMP/o" se="$TMP/e" rc err1
  cp "$f" "$TMP/case.raku"
  # ⛔ THE SUBSHELL IS LOAD-BEARING: a witness that dies on SIGABRT makes bash print "Aborted" to the
  # RANKER's own stderr, interleaving compiler crashes into the instrument's report. Its stderr is captured
  # in "$se" and classified either way, so silencing the job-control notice loses no information.
  timeout -k 5 10 "$SCRIP" --run "$TMP/case.raku" > "$so" 2> "$se" < /dev/null; rc=$?
  B_BUCKET=$(roast_bucket "$so" "$se" "$rc")
  err1=$(head -1 "$se" 2>/dev/null)
  B_LINE=$(roast_err_line "$err1")
  B_KEY="."
  [ -n "$B_LINE" ] && B_KEY=$(sed -n "${B_LINE}p" "$f" 2>/dev/null | sed 's/^[ \t]*//' | cut -c1-90 | roast_fold_construct)
}

echo "RANKER PASS 1 -- census (the same bucket rule raku_roast_scoreboard.sh --inventory uses, sourced not copied)" >&2
n=0
while IFS= read -r -d '' src; do
  rel="${src#$ROAST/}"
  [ -n "$SECTION" ] && case "$rel" in "$SECTION"*) : ;; *) continue ;; esac
  n=$((n+1)); [ "$LIMIT" -gt 0 ] && [ "$n" -gt "$LIMIT" ] && { n=$((n-1)); break; }
  run_one "$src" 2>/dev/null
  printf '%s\t%s\t%s\t%s\n' "$rel" "$B_BUCKET" "${B_LINE:-.}" "${B_KEY:-.}" >> "$CSV"
  [ $((n % 200)) -eq 0 ] && printf '  ...%d censused\n' "$n" >&2
done < <(find -L "$ROAST" -name '*.t' -print0 | sort -z)
[ "$n" -gt 0 ] || { echo "⛔ REFUSE(2): censused ZERO files -- a ranker with no population is not a ranker" >&2; exit 2; }

if [ -n "$CENSUS_OUT" ]; then
  if cp "$CSV" "$CENSUS_OUT" 2>/dev/null; then
    echo "ROAST_CENSUS_WRITTEN $CENSUS_OUT ($n rows: rel/bucket/err_line/construct) -- an operator-named scratch file, NOT a published cell" >&2
  else
    echo "⛔ REFUSE(2): --census-out named $CENSUS_OUT and it could not be written -- an instrument asked for a file it cannot produce must say so, not finish quietly without it" >&2; exit 2
  fi
fi
parse_n=$(awk -F'\t' '$2=="UNGRADED-PARSE"' "$CSV" | wc -l)
graded_n=$(awk -F'\t' '$2 ~ /^GRADED-/' "$CSV" | wc -l)
[ "$parse_n" -gt 0 ] || { echo "⛔ REFUSE(2): no UNGRADED-PARSE files in a census of $n -- nothing to ablate, and a ranker that prints an empty ranking reads like a solved problem" >&2; exit 2; }

# ⛔⭐⭐ --depth: PARSER DEBT PER FILE, THE MEASUREMENT SINGLE-SHOT ABLATION STRUCTURALLY CANNOT MAKE.
# THE GAP THAT FORCED IT (hq_raku 2026-09-16): `subtest` HEADS 29 files and APPEARS IN 297. Single-shot
# ablation only ever sees a construct that is a file's FIRST error, so it UNDERSTATES a pervasive construct
# exactly as badly as the frequency histogram OVERSTATES a shallow one -- the two instruments fail in
# opposite directions and neither can see the other's blind spot. Depth asks the question both miss: how
# many DISTINCT constructs deep is a file before it would grade at all.
# ⛔ WHAT THIS DOES NOT MEASURE, and it must be read with the caveat attached: repeatedly deleting the
# dying line MUTILATES the program. A file that reaches a graded bucket after nine deletions is not a file
# that would PASS if those nine constructs worked -- it is a file whose remains parsed. Depth is a LOWER
# BOUND ON DISTINCT BLOCKING CONSTRUCTS and nothing more. It is honest about size and silent about value.
if [ "$DEPTH" -gt 0 ]; then
  cands="$TMP/depthset"; awk -F'\t' '$2=="UNGRADED-PARSE" && $3!="."{print $1}' "$CSV" > "$cands"
  tot=$(wc -l < "$cands")
  if [ "$SAMPLE" -gt 0 ] && [ "$tot" -gt "$SAMPLE" ]; then
    awk 'BEGIN{srand(20260916)} {print rand()"\t"$0}' "$cands" | sort -n | head -"$SAMPLE" | cut -f2- > "$TMP/ds2"; mv "$TMP/ds2" "$cands"
  fi
  dn=$(wc -l < "$cands")
  [ "$dn" -gt 0 ] || { echo "⛔ REFUSE(2): depth pass has zero parse-dark files to walk" >&2; exit 2; }
  echo "RANKER DEPTH PASS -- walking $dn of $tot parse-dark file(s), cap $DEPTH deletion(s) each" >&2
  DH="$TMP/depth"; : > "$DH"; di=0
  while IFS= read -r rel; do
    di=$((di+1))
    cp "$ROAST/$rel" "$TMP/walk.t" 2>/dev/null || continue
    d=0; final=UNGRADED-PARSE
    while [ "$d" -lt "$DEPTH" ]; do
      run_one "$TMP/walk.t" 2>/dev/null
      final="$B_BUCKET"
      [ "$final" = UNGRADED-PARSE ] || break
      [ -n "$B_LINE" ] || break
      sed "${B_LINE}d" "$TMP/walk.t" > "$TMP/walk2.t" 2>/dev/null || break
      mv "$TMP/walk2.t" "$TMP/walk.t"; d=$((d+1))
    done
    printf '%s\t%s\t%s\n' "$d" "$final" "$rel" >> "$DH"
    [ $((di % 25)) -eq 0 ] && printf '  ...%d/%d walked\n' "$di" "$dn" >&2
  done < "$cands"
  echo "ROAST_DEPTH_MACHINE load=$(cut -d' ' -f1-3 /proc/loadavg) cores=$(nproc)"
  echo "ROAST_DEPTH walked=$dn of $tot parse_dark cap=$DEPTH$( [ "$SAMPLE" -gt 0 ] && printf ' (RANDOM SAMPLE, seed 20260916 -- a sample, and its denominator is printed)')"
  echo "  ⛔ DEPTH IS A LOWER BOUND ON DISTINCT BLOCKING CONSTRUCTS, NOT AN UNLOCK: the walk DELETES lines,"
  echo "     so a file that grades after N deletions is a file whose REMAINS parsed, never a file that would pass."
  reached=$(awk -F'\t' '$2 ~ /^GRADED-/' "$DH" | wc -l)
  capped=$(awk -F'\t' -v c="$DEPTH" '$1==c && $2=="UNGRADED-PARSE"' "$DH" | wc -l)
  echo "  reached_a_graded_bucket=$reached · still_parse_failing_at_cap=$capped · left_parse_but_not_graded=$((dn - reached - capped))"
  echo "ROAST_DEPTH_HISTOGRAM (deletions needed before the file stopped parse-failing):"
  awk -F'\t' '{c[$1]++} END{for(k=0;k<=99;k++) if(c[k]) printf "    %2d deletion(s): %4d file(s)\n", k, c[k]}' "$DH"
  med=$(cut -f1 "$DH" | sort -n | awk '{a[NR]=$1} END{print (NR%2)?a[(NR+1)/2]:int((a[NR/2]+a[NR/2+1])/2)}')
  echo "ROAST_DEPTH_MEDIAN median_deletions=$med over $dn file(s) (cap $DEPTH; a file AT the cap is censored, so the true median is >= this)"
  echo "ROAST_DEPTH_DONE ⛔ NOTHING WRITTEN."
  exit 0
fi
# Frequency NOMINATES the candidates; ablation RANKS them. These are different jobs and the output says so.
awk -F'\t' '$2=="UNGRADED-PARSE" && $4!="."{print $4}' "$CSV" | sort | uniq -c | sort -rn | head -"$CANDS" > "$TMP/cands"
cand_n=$(wc -l < "$TMP/cands")
[ "$cand_n" -gt 0 ] || { echo "⛔ REFUSE(2): no candidate constructs with a recoverable error line" >&2; exit 2; }

echo "RANKER PASS 2 -- ablating $cand_n candidate construct(s)" >&2
RANK="$TMP/rank"; : > "$RANK"
ci=0
while IFS= read -r line; do
  ci=$((ci+1))
  key=$(printf '%s' "$line" | sed 's/^ *[0-9]* //')
  headed=0; moved=0; past=0; advanced=0; same=0; earlier=0
  while IFS=$'\t' read -r rel bucket eline ekey; do
    [ "$bucket" = UNGRADED-PARSE ] || continue
    [ "$ekey" = "$key" ] || continue
    [ "$eline" = "." ] && continue
    headed=$((headed+1))
    # THE ABLATION OPERATOR IS DELETION OF THE DYING LINE -- the same operator hq_T's 59-file measurement used.
    sed "${eline}d" "$ROAST/$rel" > "$TMP/ablated.t" 2>/dev/null || continue
    run_one "$TMP/ablated.t" 2>/dev/null
    case "$B_BUCKET" in
      GRADED-*) moved=$((moved+1)) ;;
      UNGRADED-PARSE)
        if [ "$B_KEY" = "$key" ]; then same=$((same+1)); else advanced=$((advanced+1)); fi
        if [ -n "$B_LINE" ] && [ "$B_LINE" -lt "$eline" ] 2>/dev/null; then earlier=$((earlier+1)); fi ;;
      *) past=$((past+1)) ;;
    esac
  done < "$CSV"
  printf '%d\t%d\t%d\t%d\t%d\t%d\t%s\n' "$moved" "$past" "$advanced" "$same" "$headed" "$earlier" "$key" >> "$RANK"
  printf '  ...candidate %d/%d headed=%d moved=%d\n' "$ci" "$cand_n" "$headed" "$moved" >&2
done < "$TMP/cands"

# ⛔⭐ THE LOAD IS STAMPED BECAUSE ONE OF THE BUCKETS IS A CLOCK. UNGRADABLE-TIMEOUT is `timeout 10`
# firing, and a 10-second bound on a box other seats are building on does not measure the same thing it
# measures on a quiet one -- a file that needs 8s is UNGRADABLE under load and GRADED without it. Measured
# live while adding this: load 11.5 on 16 cores, from the coo's and the ceo's builds, on a box this
# instrument shares. ⭐ Every other bucket is deterministic; this is the one that can move without the
# compiler moving, so the run says what it ran under instead of leaving the next reader to assume a quiet box.
echo "ROAST_ABLATION_MACHINE load=$(cut -d' ' -f1-3 /proc/loadavg) cores=$(nproc) per_file_timeout=10s -- UNGRADABLE-TIMEOUT is LOAD-SENSITIVE; the other buckets are not"
echo "ROAST_ABLATION_RANK census=$n parse_dark=$parse_n graded=$graded_n candidates=$cand_n roast=$ROAST"
echo "  ⭐ RANKED BY moved_to_graded -- the ONLY column that is an unlock. headed= is the frequency histogram's"
echo "     number and is shown only so the two can be compared; a large headed= with moved=0 is the exact shape"
echo "     that makes a frequency list look like a work plan when it is not."
echo "  columns: moved=became GRADED · past_parse=left the parse bucket but not graded · advanced=still parse, NEW construct · same=ablation did not take"
sort -rn "$RANK" | awk -F'\t' '{printf "    moved=%-4s past_parse=%-4s advanced=%-4s same=%-4s headed=%-4s  %s\n", $1, $2, $3, $4, $5, $7}'
tot_moved=$(awk -F'\t' '{s+=$1} END{print s+0}' "$RANK")
tot_head=$(awk -F'\t' '{s+=$5} END{print s+0}' "$RANK")
tot_earlier=$(awk -F'\t' '{s+=$6} END{print s+0}' "$RANK")
echo "ROAST_ABLATION_TOTAL candidates=$cand_n files_headed=$tot_head files_moved_to_graded=$tot_moved"
[ "$tot_earlier" -gt 0 ] && echo "  ⚠️ $tot_earlier ablation(s) made the parse die EARLIER than the deleted line -- deletion damaged structure there, so those files' 'did not move' is UNPROVEN, not evidence the construct is cheap."
if [ "$tot_moved" = 0 ]; then
  echo "⛔ ZERO FILES MOVED across $tot_head headed by the $cand_n most frequent constructs. Read this as the baton reads it:"
  echo "   roast is a BROAD FLAT PARSER GAP with no block-unlock in the head of the histogram. Disbelieve any plan"
  echo "   promising a large roast jump from a handful of cures unless an ablation like this one backs it."
fi
echo "ROAST_ABLATION_DONE ⛔ NOTHING WRITTEN: no SCORE row, no RAKU-COVERAGE.md, no board."
exit 0

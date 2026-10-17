#!/bin/bash
# ../harness/scripts/util_raku_parse_census.sh -- PARSE COVERAGE, MEASURED DIRECTLY, NEVER DERIVED (hq_raku 2026-09-16,
# cto's ask RE parse-coverage-taken-as-68-of-1464-and-the-census-must-be-a-script-on-origin).
#
# ⛔⭐⭐ WHY THIS SCRIPT EXISTS AND WHY IT IS A SCRIPT AND NOT A NUMBER IN A MESSAGE. Parse coverage was being
# DERIVED: take the roast inventory's buckets, subtract UNGRADED-PARSE from the shipped population, and call
# the remainder "files that parse". That is not a measurement and it read 143 when the truth was 66. THE
# REASON IS GENERAL AND IS THE CTO'S OWN RULING: a bucket named for a stage names WHAT IT COULD RECOGNISE,
# not what the program REACHED. UNGRADED-EMITTER, UNGRADED-CRASH and UNGRADED-NO-TAP are named for where the
# file died AFTER the parser had already been satisfied -- but UNGRADED-OTHER and UNGRADABLE-TIMEOUT are not,
# and a file can die before the parser for reasons that never print "parse error". So a number SUBTRACTED
# from buckets is never a measurement of the stage those buckets are not about.
# ⭐ THE CURE IS THE INSTRUMENT, NOT THE CORRECTION: a figure produced by hand can be produced wrongly by hand
# again next week, and the next reader cannot tell the two apart because both arrive as a number in a sentence.
# This walks the tree, asks the PARSER the parser's own question (--dump-ast, rc=0), prints the numerator over
# a PRINTED DENOMINATOR and NAMES EVERY FILE IT COUNTED -- so the next figure is reproducible and auditable
# by re-running one line, and a disagreement is a diff of two file lists rather than two opinions.
#
# ⛔ IT WRITES NOTHING: no SCORE row, no RAKU-COVERAGE.md, no board, no progress append. ONE RUNNER ONE BOARD
# (CEO-775) is untouched -- a board is what it GRADES AND PUBLISHES (CEO-547), and this publishes nothing --
# so it is admitted to any seat and carries no one_runner_guard.
# ⛔ IT REFUSES rc=2 rather than printing the success shape over a population it could not measure, and it
# asserts its own identity (parsed + parse_fail + other == total) rather than assuming it.
#
# Usage: bash ../harness/scripts/util_raku_parse_census.sh [--summary] [--limit N] [--section S03] [--out FILE]
#   --summary   print the headline line only -- no file list (for a caller embedding the row in a board)
#   --limit N   census only the first N files (smoke the instrument; the headline says PARTIAL)
#   --section S only files whose roast-relative path starts with this prefix
#   --out FILE  ALSO write the per-file census (rel/verdict/err_line/construct) to FILE, tab separated.
#               ⛔ NOT PUBLISHING: FILE is a path the OPERATOR names, never a SCORE cell.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/../../SCRIP" || exit 2
ROOT=$(pwd)
SCRIP="$ROOT/scrip"
# ⛔ THE POPULATION AND THE CONSTRUCT KEY ARE SOURCED, NEVER COPIED (lib_ladder.sh / lib_port_trace.sh
# precedent). This census is read BESIDE the roast board, so it must walk the SAME population that board
# walks -- a private copy of the resolver would be free to grade a different tree and agree with nobody.
. "$HERE/lib_raku_roast_bucket.sh" || { echo "⛔ REFUSE(2): lib_raku_roast_bucket.sh unavailable" >&2; exit 2; }
command -v roast_resolve_population >/dev/null 2>&1 || { echo "⛔ REFUSE(2): lib_raku_roast_bucket.sh missing roast_resolve_population -- this census must walk the same population the roast board walks, not one of its own choosing" >&2; exit 2; }
# ⛔ A STALE BINARY MAKES EVERY COVERAGE NUMBER FICTION and nothing in the output would betray it: the line
# carries git HEAD, and git HEAD describes the SOURCE, not the binary that was actually asked the question.
if ! . "$HERE/lib_gate.sh" 2>/dev/null || ! command -v gate_require_fresh >/dev/null 2>&1; then
  echo "⛔ REFUSE(2): lib_gate.sh unavailable or missing gate_require_fresh -- cannot verify binary freshness" >&2; exit 2
fi
gate_require_fresh "$ROOT" src "$SCRIP" "$ROOT/out/libscrip_rt.so"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip binary at $SCRIP (run: make)" >&2; exit 2; }
roast_resolve_population "$ROOT" || exit 2

SUMMARY=0; LIMIT=0; SECTION=""; OUT_TSV=""
while [ $# -gt 0 ]; do
  case "$1" in
    --summary) SUMMARY=1; shift ;;
    --limit) LIMIT="${2:-}"; shift 2 ;;
    --section) SECTION="${2:-}"; shift 2 ;;
    --out) OUT_TSV="${2:-}"; shift 2 ;;
    *) echo "⛔ REFUSE(2): unknown argument '$1' -- this instrument names what it does not understand rather than treating it as a filename (CLAUDE.md § the driver's fall-through)" >&2; exit 2 ;;
  esac
done
case "$LIMIT" in ''|*[!0-9]*) echo "⛔ REFUSE(2): --limit wants a non-negative integer, got '$LIMIT'" >&2; exit 2 ;; esac

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
CSV="$TMP/parse_census.tsv"; : > "$CSV"
t0=$(date +%s)
n=0
# ⛔ THE FILE IS STAGED TO A CONTENT-IDENTICAL .raku TEMP AND ITS BYTES ARE NEVER TOUCHED. ".t" is not in
# SCRIP's closed first-dispatch extension list, and an unrecognised extension falls through to being treated
# as a filename the driver cannot open -- which would print rc=1 for every file in the tree and read as
# "nothing parses" (CLAUDE.md § there is no unknown-flag diagnostic).
while IFS= read -r -d '' src; do
  rel="${src#$ROAST/}"
  [ -n "$SECTION" ] && case "$rel" in "$SECTION"*) : ;; *) continue ;; esac
  n=$((n+1)); [ "$LIMIT" -gt 0 ] && [ "$n" -gt "$LIMIT" ] && { n=$((n-1)); break; }
  cp "$src" "$TMP/case.raku"
  timeout -k 5 10 "$SCRIP" --dump-ast "$TMP/case.raku" > "$TMP/o" 2> "$TMP/e" < /dev/null; rc=$?
  err1=$(head -1 "$TMP/e" 2>/dev/null)
  # ⛔⭐ THREE VERDICTS, NOT TWO, AND THE THIRD IS THE WHOLE REASON SUBTRACTION FAILED. PARSED is rc=0 and
  # nothing else. PARSE-FAIL is the parser SAYING SO. Everything else -- a signal death, a timeout, an
  # rc=1 with no parse-error text -- is OTHER: it did not parse, and it did not fail to parse for a reason
  # the parser named. Folding OTHER into either neighbour is exactly the derivation this script replaces.
  if [ "$rc" -eq 0 ]; then
    v=PARSED
  elif roast_parser_refused "$err1"; then
    v=PARSE-FAIL
  else
    v=OTHER
  fi
  ln=$(roast_err_line "$err1"); key="."
  [ -n "$ln" ] && key=$(sed -n "${ln}p" "$src" 2>/dev/null | sed 's/^[ \t]*//' | cut -c1-90 | roast_fold_construct)
  printf '%s\t%s\t%s\t%s\n' "$rel" "$v" "${ln:-.}" "${key:-.}" >> "$CSV"
  [ $((n % 200)) -eq 0 ] && printf '  ...%d censused (%ds)\n' "$n" "$(( $(date +%s) - t0 ))" >&2
done < <(find -L "$ROAST" -name '*.t' -print0 | sort -z)
[ "$n" -gt 0 ] || { echo "⛔ REFUSE(2) [raku parse census]: censused ZERO files under $ROAST -- a coverage fraction over an empty population is not a measurement, and 0/0 prints like a clean sheet" >&2; exit 2; }

parsed=$(awk -F'\t' '$2=="PARSED"' "$CSV" | wc -l)
pfail=$(awk -F'\t'  '$2=="PARSE-FAIL"' "$CSV" | wc -l)
other=$(awk -F'\t'  '$2=="OTHER"' "$CSV" | wc -l)
# ⛔ THE IDENTITY IS ASSERTED, NOT ASSUMED (the roast inventory's own rule): a census whose parts do not sum
# to its whole is not a census, and the failure mode it guards against is a verdict silently added upstream
# and counted by nobody -- which is how a bucket census starts lying while every line still looks plausible.
[ $((parsed + pfail + other)) -eq "$n" ] || { echo "⛔ REFUSE(2) [raku parse census]: the verdicts do not close -- total=$n but parsed=$parsed + parse_fail=$pfail + other=$other" >&2; exit 2; }
if [ -n "$OUT_TSV" ]; then
  cp "$CSV" "$OUT_TSV" 2>/dev/null \
    && echo "RAKU_PARSE_CENSUS_WRITTEN $OUT_TSV ($n rows: rel/verdict/err_line/construct) -- an operator-named scratch file, NOT a published cell" >&2 \
    || { echo "⛔ REFUSE(2): --out named $OUT_TSV and it could not be written -- an instrument asked for a file it cannot produce must say so, not finish quietly without it" >&2; exit 2; }
fi
ROAST_COMMIT="unversioned-tree"
[ -d "$ROAST/.git" ] && ROAST_COMMIT="$(cd "$ROAST" && git rev-parse --short=9 HEAD 2>/dev/null || echo unversioned-tree)"
PCT=$(awk -v a="$parsed" -v b="$n" 'BEGIN{printf "%.1f", a*100.0/b}')
# ⛔⭐ ONE CANONICAL HEADLINE, ON ONE LINE, IN THIS ORDER -- because a caller embedding this row and a gate
# grading it both grep for exactly this shape. The numerator NEVER appears without the denominator beside it.
printf 'RAKU_PARSE_COVERAGE PARSED %d/%d (%s%%) parse_fail=%d other=%d measure=--dump-ast_rc0 population=every_.t_under_the_vendored_roast_tree scrip=%s roast=%s%s elapsed=%ds\n' \
  "$parsed" "$n" "$PCT" "$pfail" "$other" \
  "$(cd "$ROOT" && git rev-parse --short=9 HEAD 2>/dev/null || echo unversioned)" "$ROAST_COMMIT" \
  "$( [ -n "$SECTION" ] && printf ' section=%s' "$SECTION" )" "$(( $(date +%s) - t0 ))"
[ "$LIMIT" -gt 0 ] && printf 'RAKU_PARSE_PARTIAL: --limit %d was in force, so this is a SMOKE OF THE INSTRUMENT and NOT a coverage figure.\n' "$LIMIT"
if [ "$SUMMARY" != 1 ]; then
  # ⛔ THE LIST IS NOT DECORATION AND IS NOT TRUNCATED. The cto's ask names it because a fraction cannot be
  # checked and a list can: two measurements that disagree are reconciled by diffing these names, and a file
  # that silently leaves the numerator between two runs is a REGRESSION nobody would see in "68" vs "67".
  echo "RAKU_PARSE_COVERAGE_FILES (every file counted in the numerator above, roast-relative):"
  awk -F'\t' '$2=="PARSED"{print "    " $1}' "$CSV"
  if [ "$other" -gt 0 ]; then
    echo "RAKU_PARSE_COVERAGE_OTHER (did not parse, and the parser did not say why -- crash, timeout or a silent rc):"
    awk -F'\t' '$2=="OTHER"{print "    " $1}' "$CSV"
  fi
fi
echo "⛔ NOTHING WRITTEN: no SCORE row, no RAKU-COVERAGE.md, no progress append."
exit 0

#!/usr/bin/env bash
# util_raku_roast_error_histogram.sh — the CLUSTERING instrument for raku-roast-100-percent-compile.
#
# WHY THIS EXISTS: raku_roast_scoreboard.sh answers "how many files fail", which is the row's
# DONE-WHEN but a poor progress signal. Measured 2026-08-30 (hq_C): curing the single largest
# error class (twigils, 210 -> 13 files) moved PARSE-FAIL by only 2, because a roast file is
# hundreds of lines exercising dozens of constructs -- fixing its FIRST error just exposes its
# SECOND. File-level PARSE-FAIL is an ALL-gaps-closed metric; per-construct progress is invisible
# in it until the very end. This script measures the thing that actually moves per rung.
#
# Emits, for every in-tier parse/lex failure: the file, the failing line number, and the SOURCE
# TEXT at that line -- so failures cluster by construct rather than by bison's uninformative
# "syntax error" (measured: 897 of 923 failures carry that one string; it discriminates nothing).
#
# Usage: bash ../harness/scripts/util_raku_roast_error_histogram.sh [outdir]        # default: a temp dir
#        bash ../harness/scripts/util_raku_roast_error_histogram.sh out && \
#          cut -f3 out/lines.tsv | sort | uniq -c | sort -rn | head -20  # the next cluster
#
# Compare two runs to see progress that PARSE-FAIL cannot show:
#        join -t$'\t' -j1 <(sort a/lines.tsv) <(sort b/lines.tsv)
# Refuses (rc=2) rather than reporting an empty/green histogram it could not populate.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
ROOT=$(pwd)
SCRIP="$ROOT/scrip"
# ⛔ THE POPULATION IS RESOLVED, NOT HARDCODED -- SCRIP/refs/ was deleted org-wide 2026-09-16 and this
# refused rc=2 on every renamed root (hq_raku). Same resolver as the scoreboard and the ablation ranker, so
# the three roast instruments cannot disagree about where roast lives.
. "$(dirname "$0")/lib_raku_roast_bucket.sh" 2>/dev/null || true
if command -v roast_resolve_population >/dev/null 2>&1; then roast_resolve_population "$ROOT" || exit 2; else
  MANIFEST="$ROOT/refs/rakudo-main/t/spectest.data.6.c"; ROAST="$ROOT/refs/roast"; fi
OUT="${1:-$(mktemp -d)}"
[ -x "$SCRIP" ]   || { echo "REFUSE rc=2: no scrip binary (run: make scrip)" >&2; exit 2; }
[ -f "$MANIFEST" ]|| { echo "REFUSE rc=2: no manifest at $MANIFEST (wire refs/rakudo-main)" >&2; exit 2; }
[ -d "$ROAST" ]   || { echo "REFUSE rc=2: no roast at $ROAST (wire refs/roast)" >&2; exit 2; }
mkdir -p "$OUT" || exit 2
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
: > "$OUT/lines.tsv"
n_intier=0; n_fail=0
while read -r rel _rest; do
  case "$rel" in ''|'#'*) continue ;; esac
  # tier boundary MUST match raku_roast_scoreboard.sh's is_excluded/is_tier_c
  case "$rel" in S01-*|S15-*|S26-*|S22-*|S17-*|S24-*) continue ;; esac
  src="$ROAST/$rel"; [ -f "$src" ] || continue
  n_intier=$((n_intier+1))
  cp "$src" "$TMP/case.raku"
  timeout -k 5 5 "$SCRIP" --run "$TMP/case.raku" > "$TMP/o" 2> "$TMP/e" < /dev/null
  grep -qa "parse error\|lex error" "$TMP/e" || continue
  n_fail=$((n_fail+1))
  err=$(grep -am1 "parse error\|lex error" "$TMP/e")
  ln=$(printf '%s' "$err" | grep -oE 'line [0-9]+' | grep -oE '[0-9]+')
  txt=""
  [ -n "$ln" ] && txt=$(sed -n "${ln}p" "$src" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  printf '%s\t%s\t%s\n' "$rel" "${ln:-0}" "$txt" >> "$OUT/lines.tsv"
done < "$MANIFEST"
[ "$n_intier" -gt 0 ] || { echo "REFUSE rc=2: manifest yielded zero in-tier files -- instrument graded nothing" >&2; exit 2; }
echo "in-tier scanned : $n_intier"
echo "parse/lex fails : $n_fail"
echo "written         : $OUT/lines.tsv  (file <TAB> line <TAB> source text)"
echo
echo "TOP CONSTRUCT CLUSTERS (exact failing source line):"
cut -f3 "$OUT/lines.tsv" | sort | uniq -c | sort -rn | head -15

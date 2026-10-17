#!/usr/bin/env bash
# s65b BUG-HUNT CENSUS (Lon in-chat: "let's figure out how we are going to keep an accounting of the classes of
# problems as we go along... SCRIP knows at compile time when it has NO FIXED offset available... it should report
# that as one class and keep track of a list.  SCRIP knows also at compile time when it has NO WHACK power for
# unbounded growth.  This too should have a list.  Then the other list is the list of failures and their
# classifications... the BB probes are real good and the demos are good for comprehensive.").
# THREE LEDGERS, one TSV row per program:  RESULT<TAB>NOFIX#<TAB>NOWHACK#<TAB>NOWHACK-OPS<TAB>PROGRAM
#   Ledger 1 NOFIX   = [CLS:NOFIX] count   (emit_rec_pin || op_stmt_dyn -- the s52/s53 dyn-offset predicate, resurrected as a report)
#   Ledger 2 NOWHACK = [CLS:NOWHACK] count (frame_need_of==1 minus FENCE1 -- unbounded growth with no frame to whack it)
#   Ledger 3 RESULT  = classify_one verdict, reused from test_rsp_descent_sweep.sh via SWEEP_LIST (ONE AUTHORITY)
# Default set: corpus/library/probe_reference/bb (188) + SCRIP demo/ + test/demo + corpus demos.  Override with CENSUS_LIST=<file of paths>.
# Diag lines per program persist in $CENSUS_DIAGDIR (default /tmp/bug_hunt_diag) keyed by path-md5 -- the site-level lists.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
cd "$(dirname "$0")/../../SCRIP"
ROOT=$PWD
OUT=${1:-/tmp/bug_hunt_census.tsv}
DIAGDIR=${CENSUS_DIAGDIR:-/tmp/bug_hunt_diag}; mkdir -p "$DIAGDIR"
LISTF=/tmp/bug_hunt_list.$$
# library/probe_reference/bb's loose .sno files converted to suite format 2026-08-28 (probe-consolidate-bb, LON-20260828
# total conversion) -- the find below now contributes 0 from library/probe_reference/bb by construction. EXPECTED, not a
# regression; pass CENSUS_LIST to include tests/snobol4/probe/bb*.sno entries (materialize via
# corpus_suite_harness.py extract first -- suite files are not standalone-runnable .sno programs).
if [ -n "${CENSUS_LIST:-}" ]; then cp "$CENSUS_LIST" "$LISTF"
else { find $S4E/corpus/library/probe_reference/bb -name '*.sno' 2>/dev/null; find "$ROOT/demo" "$ROOT/../corpus/tests/scrip_test/demo" -name '*.sno' 2>/dev/null; find $S4E/corpus -path '*demo*' -name '*.sno' 2>/dev/null; } | sort -u > "$LISTF"; fi
CLS=/tmp/bug_hunt_cls.$$
SWEEP_LIST="$LISTF" SWEEP_JOBS="${SWEEP_JOBS:-4}" bash "$ROOT/../harness/scripts/test_rsp_descent_sweep.sh" "$CLS" >/dev/null 2>&1
: > "$OUT"
while IFS= read -r f; do
  tag=$(printf '%s' "$f" | md5sum | cut -c1-10)
  D="$DIAGDIR/$tag.diag"
  { echo "# $f"; SCRIP_CLASS_DIAG=1 SNO_LIB=$S4E/corpus timeout -k 5 30 "$ROOT/scrip" --compile "$f" </dev/null >/dev/null 2>&1 | true; } > /dev/null
  SCRIP_CLASS_DIAG=1 SNO_LIB=$S4E/corpus timeout -k 5 30 "$ROOT/scrip" --compile "$f" </dev/null >/dev/null 2>"$D"
  nf=$(grep -c '^\[CLS:NOFIX\]' "$D")
  nw=$(grep -c '^\[CLS:NOWHACK\]' "$D")
  ops=$(grep '^\[CLS:NOWHACK\]' "$D" | sed 's/.*op=\([A-Za-z0-9_]*\).*/\1/' | sort | uniq -c | awk '{printf "%s:%s,",$2,$1}' | sed 's/,$//')
  cls=$(grep -F " $f" "$CLS" | head -1 | awk '{print $1}'); [ -z "$cls" ] && cls=NOCLASS
  printf '%s\t%s\t%s\t%s\t%s\n' "$cls" "$nf" "$nw" "${ops:--}" "$f" >> "$OUT"
done < "$LISTF"
echo "== LEDGER 3: RESULT histogram =="
awk -F'\t' '{print $1}' "$OUT" | sort | uniq -c | sort -rn
echo "== LEDGER 1: NOFIX>0 programs: $(awk -F'\t' '$2>0' "$OUT" | wc -l)   total sites: $(awk -F'\t' '{s+=$2} END{print s+0}' "$OUT")"
echo "== LEDGER 2: NOWHACK>0 programs: $(awk -F'\t' '$3>0' "$OUT" | wc -l)   total sites: $(awk -F'\t' '{s+=$3} END{print s+0}' "$OUT")"
echo "== RED with EMPTY compile-time ledgers (invisible class) =="
awk -F'\t' '$1!="PASS" && $1!="ORACLE_FAIL" && $2==0 && $3==0 {print $1" "$5}' "$OUT"
echo "== RED with NOWHACK>0 (predicted-by-ledger failures) =="
awk -F'\t' '$1!="PASS" && $1!="ORACLE_FAIL" && $3>0 {print $1" nw="$3" "$5}' "$OUT"
echo "detail: $OUT   per-program site lists: $DIAGDIR/<md5>.diag"
rm -f "$LISTF" "$CLS"

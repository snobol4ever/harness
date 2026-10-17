#!/bin/bash
# test_gate_corpus_coverage_classified.sh -- THE COMPUTABLE DONE-WHEN for row audit-corpus-what-is-ungated.
#
# THE CRITERION, VERBATIM FROM THE ROW: "every primary-corpus program is GATED, UNGATED-with-a-minted-row, or
# DELIBERATELY-EXCLUDED-with-a-documented-reason."  For 12 passes that sentence was PROSE and the row's DONE-WHEN
# was a refusal stub (`false`) -- trap #1, a DONE-WHEN that can never say YES.  This is that sentence as a command.
#
# ⭐ WHAT IT PROVES: TOTALITY -- every subtree of the live corpus carries a classification, and every classification
# still resolves.  A new corpus subtree (corpus/demos/scrip/ went unnoticed for 10 passes), a renamed one (the s272 re-grid
# stranded STEP 5's paths), a harness deleted out from under an entry, or a row marked DONE while its subtree is still
# ungated -- each turns this gate RED and NAMES the offender.
# ⛔ WHAT IT DOES NOT PROVE: that a named harness genuinely sweeps its subtree.  A harness can exist and be vacuous
# (measured: prolog-parser-corpus-vacuous-gate-422-files, 422 files, unconditional "RESULT: PASS").  Vacuity is that
# row's question.  Conflating the two would make this gate the very thing it exists to catch.
#
# REFUSES rc=2 when it cannot measure -- never skip-as-success (CLAUDE.md; hq_C s272 §4 criterion 1).
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CORPUS="$S4E/corpus"
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPTS/corpus_coverage_manifest.tsv"
PO="${POSTOFFICE:-/home/resources/postoffice}"

[ -d "$CORPUS" ]      || { echo "⛔ REFUSES rc=2: corpus not found at $CORPUS"; exit 2; }
[ -f "$MANIFEST" ]    || { echo "⛔ REFUSES rc=2: manifest not found at $MANIFEST"; exit 2; }
[ -d "$PO/tasks" ]    || { echo "⛔ REFUSES rc=2: postoffice tasks not found at $PO/tasks (set POSTOFFICE=)"; exit 2; }

WORK=$(mktemp -d) || { echo "⛔ REFUSES rc=2: cannot mktemp"; exit 2; }
trap 'rm -rf "$WORK"' EXIT

grep -v '^[[:space:]]*#' "$MANIFEST" | grep -v '^[[:space:]]*$' > "$WORK/m.tsv"
awk -F'\t' '$1=="EXCLUDE"{print $2}' "$WORK/m.tsv" | sort -u > "$WORK/excl.txt"
awk -F'\t' '$1=="SUBTREE"{print $2}' "$WORK/m.tsv" | sort -u > "$WORK/declared.txt"
[ -s "$WORK/declared.txt" ] || { echo "⛔ REFUSES rc=2: manifest declares no SUBTREE entries -- unparseable or truncated"; exit 2; }

# Live enumeration: the SAME extension set as util_corpus_coverage_denominator.sh (the §1 authority).
find "$CORPUS" -type f \( -name '*.sno' -o -name '*.icn' -o -name '*.pl' -o -name '*.sc' \
    -o -name '*.reb' -o -name '*.raku' -o -name '*.pas' \) 2>/dev/null \
    | sed "s|^$CORPUS/||" | sort > "$WORK/all.txt"
TOTAL=$(wc -l < "$WORK/all.txt")
[ "$TOTAL" -gt 0 ] || { echo "⛔ REFUSES rc=2: zero program files under $CORPUS -- corpus missing or extensions changed"; exit 2; }

cp "$WORK/all.txt" "$WORK/rest.txt"
EXCLUDED_N=0
while read -r p; do
    [ -n "$p" ] || continue
    n=$(grep -c "^$p/" "$WORK/rest.txt")
    EXCLUDED_N=$((EXCLUDED_N + n))
    grep -v "^$p/" "$WORK/rest.txt" > "$WORK/rest.new" || true
    mv "$WORK/rest.new" "$WORK/rest.txt"
done < "$WORK/excl.txt"

# Group the remainder at depth 2 -- the level harnesses actually operate at.
while read -r f; do
    d=$(dirname "$f")
    echo "$d" | awk -F/ '{if(NF>=2) print $1"/"$2; else print $1}'
done < "$WORK/rest.txt" | sort | uniq -c | sed 's/^ *//' > "$WORK/live_counts.txt"
awk '{print $2}' "$WORK/live_counts.txt" | sort -u > "$WORK/live.txt"

DENOM=$(wc -l < "$WORK/rest.txt")
echo "corpus coverage classification -- recomputed live, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "root: $CORPUS"
echo "total program files: $TOTAL   excluded: $EXCLUDED_N   DENOMINATOR: $DENOM"
echo

FAIL=0
# (1) TOTALITY: every live subtree is classified.
UNCLASSIFIED=$(comm -23 "$WORK/live.txt" "$WORK/declared.txt")
if [ -n "$UNCLASSIFIED" ]; then
    echo "⛔ UNCLASSIFIED SUBTREE(S) -- live corpus content in no bucket at all:"
    while read -r s; do [ -n "$s" ] && printf '     %-32s %s file(s)\n' "$s" "$(awk -v k="$s" '$2==k{print $1}' "$WORK/live_counts.txt")"; done <<< "$UNCLASSIFIED"
    echo "     -> classify each in $MANIFEST (GATED harness / ROWD open row / EXCLUDE with a reason)."
    FAIL=1
fi
# (2) STALE: a declared subtree that no longer exists (reorg drift -- this is what stranded STEP 5).
STALE=$(comm -13 "$WORK/live.txt" "$WORK/declared.txt")
if [ -n "$STALE" ]; then
    echo "⛔ STALE MANIFEST ENTRY(S) -- declared but absent from the live tree:"
    while read -r s; do [ -n "$s" ] && echo "     $s"; done <<< "$STALE"
    FAIL=1
fi
# (3) REFERENTIAL INTEGRITY.
while IFS=$'\t' read -r kind path bucket evidence; do
    [ "$kind" = "SUBTREE" ] || continue
    case "$bucket" in
      GATED)
        if [ ! -f "$SCRIPTS/$evidence" ]; then
            echo "⛔ BROKEN GATE: $path claims $evidence -- that script does not exist"; FAIL=1
        fi ;;
      ROWD)
        tf="$PO/tasks/$evidence.task.md"
        if [ ! -f "$tf" ]; then
            echo "⛔ BROKEN ROW: $path claims row '$evidence' -- no such task file"; FAIL=1
        elif ! grep -qP "\t\Q$evidence\E\t" "$PO/QUEUE.tsv"; then
            # ⭐ A ROWD claim is satisfied by the row being OPEN, so an UNDISPATCHABLE row satisfies it FOREVER --
            # green in exactly the wrong direction, while a COMPLETED row red-gates the whole fleet. A row with a
            # task file but no QUEUE.tsv row can never be picked by `next`, so its promise can never be kept.
            # Measured witness: prolog-parser-corpus-vacuous-gate-422-files was the sole cover for tests/prolog
            # (261 files) with ZERO queue rows; its work had in fact landed at b362f2a3 and nobody could close it.
            echo "⛔ UNDISPATCHABLE ROW: $path claims row '$evidence', which has a task file but NO row in QUEUE.tsv."
            echo "     -> no seat can pick it via 'next', so this coverage claim can never be discharged."
            echo "     -> either restore the queue row, or classify the subtree GATED and name the harness."
            FAIL=1
        elif head -1 "$tf" | grep -q 'state: DONE'; then
            echo "⛔ ROW CLOSED, COVERAGE NOT LANDED: $path is only covered by '$evidence', which is state: DONE."
            echo "     -> either the subtree is now GATED (say so, name the harness) or the row reopened prematurely."
            FAIL=1
        fi ;;
      *) echo "⛔ BAD BUCKET '$bucket' for $path (expected GATED or ROWD)"; FAIL=1 ;;
    esac
done < "$WORK/m.tsv"
# (4) Every EXCLUDE carries a documented reason.
while IFS=$'\t' read -r kind path bucket evidence; do
    [ "$kind" = "EXCLUDE" ] || continue
    if [ -z "${evidence// /}" ]; then echo "⛔ UNDOCUMENTED EXCLUSION: $path has no reason"; FAIL=1; fi
done < "$WORK/m.tsv"

G=$(awk -F'\t' '$1=="SUBTREE"&&$3=="GATED"{n++}END{print n+0}' "$WORK/m.tsv")
R=$(awk -F'\t' '$1=="SUBTREE"&&$3=="ROWD"{n++}END{print n+0}' "$WORK/m.tsv")
X=$(wc -l < "$WORK/excl.txt")
echo
echo "buckets: GATED=$G subtree(s) · ROWD=$R · EXCLUDE=$X prefix(es) · live subtrees=$(wc -l < "$WORK/live.txt")"
if [ "$FAIL" -eq 0 ]; then
    echo "✅ GATE OK -- every live corpus subtree is classified and every classification resolves."
    exit 0
fi
echo "⛔ GATE FAILED -- the corpus is not fully classified; see above."
exit 1

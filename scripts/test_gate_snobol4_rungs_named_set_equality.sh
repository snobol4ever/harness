#!/usr/bin/env bash
# test_gate_snobol4_rungs_named_set_equality.sh -- NAMED-SET EQUALITY instrument for the
# SNOBOL4 floor cutover (row snobol4-floor-cutover-to-the-one-flat-suite-board-equality-first).
#
# THE QUESTION THIS ANSWERS: since the per-family boards retired in favor of grading
# tests/snobol4/ALL.{sno,ref,csv} alone, did any program that used to be gradable become
# silently un-gradable -- present in neither the rungs nor a loud exclusion? A count match
# is not this proof (this project lost a day once to four honest totals from different
# populations); this checks every deleted file BY NAME.
#
# METHOD: for every commit that deleted a *.sno+*.ref pair from tests/snobol4/, probe/, or
# crosscheck/ during the consolidation, the pair is accounted for iff ONE of:
#   (a) some origin in ALL.csv ends with "__<basename>"            -- leaf program, absorbed directly
#   (b) the file's own path-derived family name has ANY entries    -- the file WAS an intermediate
#       in ALL.csv's family column                                    suite itself, absorbed wholesale
#   (c) the basename appears in ALL.excluded.txt                   -- loudly excluded, not lost
# Accounted for by none of the three is a genuine gap: exit 1 and name it.
#
# ⛔ COMMIT DISCOVERY IS THE UNION OF TWO SIGNALS, NOT A SINGLE DATE CUTOFF. `git log --since`
# filters by COMMIT date, which can diverge from the visible author date after a rebase --
# measured directly: three genuine pilot-conversion commits, author-dated inside the
# consolidation window, were silently excluded by a plain --since filter for exactly this
# reason. Union of (committed on/after START_DATE) and (message matches MSG_GREP) catches
# both; verified by spot-check that commits matching neither are unrelated pre-consolidation
# history (e.g. a March "crosscheck recategorization" refactor).
#
# Usage: bash ../harness/scripts/test_gate_snobol4_rungs_named_set_equality.sh [START_DATE]
#   START_DATE defaults to 2026-08-24 (the ONE-FLAT-SUITE ruling date). Exit 0 = every deleted
#   graded pair accounted for. Exit 1 = a genuine gap was found, named. Exit 2 = could not
#   measure (rungs/exclusion files missing).
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$S4E/corpus" || exit 2
START="${1:-2026-08-24}"
CSV=tests/snobol4/ALL.csv
EXC=tests/snobol4/ALL.excluded.txt
[ -f "$CSV" ] || { echo "⛔ REFUSE: no $CSV"; exit 2; }
[ -f "$EXC" ] || { echo "⛔ REFUSE: no $EXC"; exit 2; }

ORIGINS=$(mktemp); FAMILIES=$(mktemp); EXCLUDED=$(mktemp); GAPFILE=$(mktemp)
trap 'rm -f "$ORIGINS" "$FAMILIES" "$EXCLUDED" "$GAPFILE"' EXIT
awk -F, 'NR>1{print $3}' "$CSV" > "$ORIGINS"
awk -F, 'NR>1{print $4}' "$CSV" | sort -u > "$FAMILIES"
# ⛔ SKIP COMMENT LINES: ALL.excluded.txt has always been able to carry them (the builder's merge preserves a
# header verbatim) and now ALWAYS ends with a `# builder-digest:` line (CEO-545). A bare `cut -f1` turns each
# one into a phantom excluded NAME. Harmless by luck here -- no real basename looks like a comment -- but a
# set-equality gate whose set is polluted by its own file format is one rename away from a false green.
grep -v '^#' "$EXC" | cut -f1 > "$EXCLUDED"

date_based=$(git log --format=%H --diff-filter=D --all --since="$START" -- 'tests/snobol4/*' 'probe/*' 'crosscheck/*')
msg_based=$(git log --format=%H --diff-filter=D --all -- 'tests/snobol4/*' 'probe/*' 'crosscheck/*' | \
    while read -r h; do git show -s --format=%s "$h" | grep -qiE "convert|absorb|suite|consolidat" && echo "$h"; done)
commits=$(printf '%s\n%s\n' "$date_based" "$msg_based" | sort -u | grep -v '^$')
ncommits=$(echo "$commits" | grep -c .)
echo "scanning $ncommits deletion commits (committed>=$START UNION message-relevant)..." >&2

derive_family() {
    local p="$1" d b norm
    d=$(dirname "$p"); b=$(basename "$p" .sno)
    norm="${d}/${b}"; norm="${norm#tests/snobol4/}"; norm="${norm//\//_}"
    echo "$norm"
}

# ⛔ EXACT SUFFIX, NOT SUBSTRING. This check was `grep -qF "__$base"` -- a CONTAINS test, while the
# method comment above it (and the whole proof) claims "ends with". The two disagree on exactly the
# case that matters: a deleted leaf whose name is a PREFIX of a surviving sibling's name is reported
# accounted-for by a match against the SIBLING. Measured, hq_C 2026-08-30: 48 of 1370 (a)-matches held
# only under the loose reading; 47 were genuine intermediate suites that (b) catches anyway, and 1 --
# probe/m1/m1_include_sort_loop, matched against the surviving twin ...sort_loop_inline -- was a real,
# uncited retirement this gate was papering over. Fixed-string suffix compare, so a basename carrying
# regex metacharacters cannot silently widen the test the way an unescaped grep -E would.
origin_suffix_match() {
    awk -v s="$1" 'length($0) >= length(s) && substr($0, length($0)-length(s)+1) == s { f=1; exit } END { exit !f }' "$2"
}

total=0; accounted_a=0; accounted_b=0; accounted_c=0; gap=0
for c in $commits; do
    deleted_sno=$(git show --diff-filter=D --name-only --pretty=format: "$c" -- 'tests/snobol4/*.sno' 'probe/*.sno' 'crosscheck/*.sno' 2>/dev/null | grep -v '^$')
    [ -z "$deleted_sno" ] && continue
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        base=$(basename "$f" .sno)
        ref="${f%.sno}.ref"
        git show --diff-filter=D --name-only --pretty=format: "$c" -- "$ref" 2>/dev/null | grep -q "^${ref}$" || continue
        total=$((total+1))
        fam=$(derive_family "$f")
        if origin_suffix_match "__${base}" "$ORIGINS"; then accounted_a=$((accounted_a+1))
        elif grep -qxF "$fam" "$FAMILIES"; then accounted_b=$((accounted_b+1))
        elif grep -qxF "$base" "$EXCLUDED" || grep -q "probe_loose_.*${base}$" "$EXCLUDED"; then accounted_c=$((accounted_c+1))
        else gap=$((gap+1)); echo -e "$c\t$f\t(derived family: $fam)" >> "$GAPFILE"
        fi
    done <<< "$deleted_sno"
done

echo "graded pairs (.sno+.ref both deleted in same commit) since $START: $total"
echo "accounted (a) direct origin-suffix match: $accounted_a"
echo "accounted (b) family-name match (was an intermediate suite file): $accounted_b"
echo "accounted (c) loudly excluded: $accounted_c"
echo "GAP (none of the above): $gap"
if [ "$gap" -gt 0 ]; then
    echo "⛔ NAMED-SET EQUALITY BROKEN -- the following deleted, once-graded pairs are accounted for nowhere:"
    cat "$GAPFILE"
    exit 1
fi
echo "✅ NAMED-SET EQUALITY HOLDS: every deleted graded pair since $START is accounted for."
exit 0

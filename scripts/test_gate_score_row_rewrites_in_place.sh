#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
export S4E_DB_CHECK_OVERRIDE="gate fixture: this gate plants no progress rows (util_score_row.py db_crosscheck, hq_raku 2026-09-16)"
# test_gate_score_row_rewrites_in_place.sh — the invariant gate for THE ONE LEADERBOARD's write path
# (row `score-md-rows-are-rewritten-by-the-runner-that-measured-them`, hq_T 2026-09-03).
#
# WHAT IT PROTECTS. RULES.md's ONE-LEADERBOARD FACT RULE names one property twice, because it is the
# one that decides whether SCORE.md is worth reading: "a row is rewritten IN PLACE, never appended
# beside a stale one". An append-instead-of-rewrite bug does not look like a bug. It produces a file
# that is LONGER and FULLER and contains every number anyone ever measured, and a reader picking the
# first matching row gets whichever measurement happened to land first — the oldest one. That is a
# leaderboard that gets more wrong the more it is used, and it would pass any test that only asked
# "did the new number appear".  So this gate asserts the new number appeared AND the old one did not
# survive AND the row count did not move.
#
# ⛔ AND EVERY REFUSAL PATH, because the second half of the rule is that this helper must never invent
# a cell. The refusals are the product here as much as the writes are: unknown language, unknown
# column, a cell with no digit in it, an unsigned row, and a '|' that would silently reshape the
# markdown table. Each must exit 2. A helper that guesses is worse than no helper, because the row it
# guesses carries a tree stamp that makes it look measured.
#
# ⭐⭐ THE PROPERTY PAID OFF UNDER REAL CONTENTION ON DAY ONE, and this is hq_C's report of it
# (2026-09-03), kept here because it is evidence rather than argument. They ran a write for snobol4
# and icon; between the write and the push, another session rewrote BOTH rows, and the rebase gave a
# genuine content conflict on SCORE.md. Their words: "because it rewrites ONE cell in place with
# provenance instead of regenerating the file, the conflict was two lines wide and readable, and I
# could tell in one glance which half of each row was newer. An append-style board would have left me
# two plausible rows and no way to choose." They kept the other session's snobol4 row (its entries
# column was genuinely newer) and their own icon row (378 on a descendant supersedes 377 on an
# ancestor) -- a merge, never a force. ⛔ So rewrite-in-place is not merely tidier than appending: it
# is what makes a concurrent conflict DECIDABLE by a human in one glance. That is the property this
# gate exists to keep, and the reason it is worth an arm rather than a comment.
#
# ⛔ IT GRADES A SCRATCH COPY, NEVER THE REAL BOARD. The helper's own `selftest` subcommand copies
# SCORE.md to a tempdir and writes there; this gate asserts that too (the real .github working tree
# must be no dirtier after the run than before), because a gate that edits the artifact it grades is
# how a green board and a corrupted file coexist.
#
# Usage: bash ../harness/scripts/test_gate_score_row_rewrites_in_place.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"

HELPER="$HERE/util_score_row.py"
gate_require "$HELPER" "the one leaderboard helper util_score_row.py"
gate_require "$ROOT/../.github/SCORE.md" "the ONE LEADERBOARD .github/SCORE.md"

# ⛔ The dirtiness baseline is taken BEFORE the selftest, not assumed clean: this gate runs in real
# sessions mid-landing, so "was dirty and stayed exactly as dirty" is the honest invariant, never
# "is clean". Comparing to a hardcoded clean would fail every seat that ran it while working.
GH="$ROOT/../.github"
. "$(dirname "${BASH_SOURCE[0]}")/lib_suites_tsv.sh" || { echo "REFUSED(2): cannot load lib_suites_tsv.sh"; exit 2; }
before="$(git -C "$GH" status --porcelain -- SCORE.md 2>/dev/null)"

violations=0
examined=0

# ARM 1 — the helper's own selftest: rewrite-in-place over two writes, and all five refusal paths.
out="$(python3 "$HELPER" selftest 2>&1)"; rc=$?
examined=$((examined + 1))
echo "$out" | sed 's/^/    /'
if [ "$rc" -ne 0 ]; then
    echo "GATE FAIL: util_score_row.py selftest exited $rc (expected 0) — see its own SELFTEST lines above"
    violations=$((violations + 1))
fi
for want in "rewrite-in-place holds" "not appended beside it" "unknown language correctly REFUSED" \
            "unknown column correctly REFUSED" "no digit correctly REFUSED" \
            "pipe injection correctly REFUSED" \
            "absent measurer, known root correctly DERIVED" \
            "placeholder measurer, known root correctly DERIVED" \
            "absent measurer, numbered seat root correctly DERIVED" \
            "placeholder measurer on an UNKNOWN root correctly REFUSED" \
            "ANCESTOR of the cell's stamped tree correctly REFUSED" \
            "the ancestor refusal discriminates rather than blocks"; do
    examined=$((examined + 1))
    case "$out" in
        *"$want"*) ;;
        *) echo "GATE FAIL: the selftest never proved: $want"; violations=$((violations + 1)) ;;
    esac
done

# ARM 2 — the selftest must not have touched the real board.
examined=$((examined + 1))
after="$(git -C "$GH" status --porcelain -- SCORE.md 2>/dev/null)"
if [ "$before" != "$after" ]; then
    echo "GATE FAIL: the selftest changed the REAL .github/SCORE.md (porcelain moved from '$before' to '$after')"
    echo "    A gate that edits the artifact it grades is how a green board and a corrupted file coexist."
    violations=$((violations + 1))
fi

# ARM 3 — the bash call shape exists in the shared authority, so runners have one line and not a
# second implementation. Sourcing lib_gate.sh already happened above; the function must be defined.
examined=$((examined + 1))
if ! declare -F gate_score_row >/dev/null 2>&1; then
    echo "GATE FAIL: lib_gate.sh defines no gate_score_row — bash runners have no one-line call, which is"
    echo "    how the FACT RULE degrades back into 'remember to edit the file by hand'."
    violations=$((violations + 1))
fi

# ARM 4 — `check` must run and produce a per-row staleness verdict. rc=1 (rows ARE stale) is a real
# answer and passes this gate; rc=2 (cannot measure) does not. ⛔ Capture first, then test: `$?` after
# a pipeline reports the pager, not the command (CLAUDE.md, measured live).
examined=$((examined + 1))
chk="$(python3 "$HELPER" check --no-fetch 2>&1)"; crc=$?
if [ "$crc" -ge 2 ]; then
    echo "GATE FAIL: util_score_row.py check could not measure staleness (rc=$crc)"
    echo "$chk" | sed 's/^/    /'
    violations=$((violations + 1))
elif ! printf '%s' "$chk" | grep -q 'SCORE.md staleness'; then
    # ⛔⭐ COULD-NOT-MEASURE IS NOT MEASURED-RED, AND THIS ARM USED TO COLLAPSE THEM (hq_T 2026-09-06, on the
    # coo's reading: FAIL(1) here once at load 22, then PASS(0) twice within five minutes, with and without
    # their change stashed -- a load-sensitive arm, not a regression). `check` shells out to git per row; under
    # contention it can return WITHOUT its header and without verdicts, and this arm then convicted the WRITE
    # PATH -- which it had not tested at all -- of an invariant break. That is the exact collapse lib_gate.sh's
    # three exit codes exist to prevent, inside the gate that polices the leaderboard's honesty.
    # ⚠️⭐ AND THE DIAGNOSTIC BELOW USED PLAIN QUOTES BECAUSE BACKTICKS IN A DOUBLE-QUOTED echo RUN AS A COMMAND
    # -- measured on this very line: the first cut printed "this arm never reached it.  runs one git query",
    # having executed `check` and eaten the word out of the sentence that exists to name it. Same defect this
    # repo has now recorded four times, and it bit inside the fix for a DIFFERENT could-not-measure defect.
    # ⭐ THE DISCRIMINATOR IS the check header, not the verdict lines: a run that printed the header and no
    # verdicts really did fail to grade any row (a defect), while a run that printed no header never got started
    # (an environment). Splitting on the header tests the two different claims separately instead of guessing.
    echo "⛔ GATE REFUSES (rc=2): util_score_row.py check returned no staleness report at all (rc=$crc)."
    echo "   NOT a verdict on the write path -- this arm never reached it. 'check' runs one git query per row"
    echo "   and returns degraded under load; re-run when the box is quieter. Captured output follows:"
    echo "$chk" | sed 's/^/    /'
    exit 2
elif ! printf '%s' "$chk" | grep -q 'commits behind origin/main\|UNPINNED\|UNKNOWN'; then
    echo "GATE FAIL: check printed its staleness report but graded no row in it"
    echo "$chk" | sed 's/^/    /'
    violations=$((violations + 1))
fi

# ARM 5 — the OTHER writer of this file must MERGE, not splice. util_apply_score_grid.py regenerates whole
# rows, so it can destroy in one run everything every `write` above recorded. ⛔ It is gated HERE, beside
# the row-writer, on purpose: the two scripts write one file and a guarantee proved on only one of them is
# not a guarantee about the file. Its own selftest pins that a NARROW grid leaves the unmeasured columns
# byte-identical, and that the September-10 grid -- which is NOT the table it edits -- is never touched.
examined=$((examined + 1))
APPLIER="$(dirname "$HELPER")/util_apply_score_grid.py"
if [ ! -f "$APPLIER" ]; then
    echo "GATE FAIL: util_apply_score_grid.py is absent — the grid-merge path is ungated"
    violations=$((violations + 1))
else
    asel="$(python3 "$APPLIER" --selftest 2>&1)"; arc=$?
    if [ "$arc" -ne 0 ]; then
        echo "GATE FAIL: util_apply_score_grid.py --selftest rc=$arc"
        echo "$asel" | sed 's/^/    /'
        violations=$((violations + 1))
    else
        echo "$asel" | sed 's/^/    /'
    fi
fi

# ARM 6 — ⛔⭐⭐ A GATE OVER THIS FILE MUST NOT GO GREEN WHEN A ROW BECOMES UNREADABLE. This is hq_B's
# incident of 2026-09-05, replayed as a permanent arm: they pasted a minimized Icon witness carrying the
# language's two-pipe concatenation operator into a SCORE.md cell, the row widened, and
# test_gate_score_tables_agree.sh went from GATE RED on a real conflict to GATE PASS(0). Nothing was
# fixed. `agree` compares mirrored cell PAIRS, a row it cannot parse yields no pairs, and a population
# that cannot be READ scores exactly like a population with no conflicts.
# ⭐ THE RULE, which is why this is an arm and not a comment: A GREEN THAT APPEARS WHILE YOU ARE EDITING
# THE DATA IS A SUSPECT, NOT A REWARD. Graded on a SCRATCH COPY (never the real board), and it asserts
# the verdict MOVES OFF PASS -- RED or REFUSE both satisfy it, because either one keeps looking.
examined=$((examined + 1))
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/score_agree_blindspot.XXXXXX")"
mkdir -p "$SCRATCH/.github"
cp "$GH/SCORE.md" "$SCRATCH/.github/SCORE.md"
python3 - "$SCRATCH/.github/SCORE.md" <<'EOF'
import sys
p = sys.argv[1]
L = open(p, encoding="utf-8").read().split("\n")
for i, l in enumerate(L):
    c = [x for x in l.strip().strip("|").split("|")]
    # the first data row of the 7-column September-10 grid, widened exactly as a pasted `||` widens it
    if l.startswith("| ") and len(c) == 7 and not l.startswith("| Language") and not set(l) <= set("| -:"):
        L[i] = "|" + "|".join(c[:5] + ['write("a"||"b")'] + c[5:]) + "|"
        break
else:
    sys.exit("ARM 6 SETUP: no 7-column grid row to widen")
open(p, "w", encoding="utf-8").write("\n".join(L))
EOF
if [ $? -ne 0 ]; then
    echo "GATE FAIL: ARM 6 could not build its witness (no 7-column grid row found)"
    violations=$((violations + 1))
else
    aout="$(S4E_HOME="$SCRATCH" python3 "$HELPER" agree 2>&1)"; arc=$?
    if [ "$arc" -eq 0 ]; then
        echo "GATE FAIL: agree printed a PASS over a SCORE.md whose grid row it could not parse --"
        echo "           a population that cannot be read scored as a population with no conflicts"
        echo "$aout" | tail -2 | sed 's/^/    /'
        violations=$((violations + 1))
    elif ! printf '%s' "$aout" | grep -q 'MALFORMED\|ZERO mirrored'; then
        echo "GATE FAIL: agree moved off PASS (rc=$arc) but never named the unreadable row"
        echo "$aout" | tail -2 | sed 's/^/    /'
        violations=$((violations + 1))
    fi
fi

# ARM 7 — THE POPULATION FLOOR ITSELF, which is the independent bar. Both tables can be well-formed and
# still share no comparable cell; then `0 conflicts` is arithmetic over nothing. A gate that graded zero
# pairs REFUSES rc=2 and never prints the success shape (RULES.md § a test that cannot measure refuses).
# Measured pre-cure on this same witness: `GATE PASS(0) ... 0 mirrored cell pair(s), 0 same-denominator
# conflicts` at rc=0 -- the gate printed the number zero and called it a pass.
examined=$((examined + 1))
python3 - "$SCRATCH/.github/SCORE.md" <<'EOF'
import sys
p = sys.argv[1]
L = open(p, encoding="utf-8").read().split("\n")
for i, l in enumerate(L):
    c = [x for x in l.strip().strip("|").split("|")]
    if l.startswith("| ") and len(c) == 7 and not l.startswith("| Language") and not set(l) <= set("| -:"):
        L[i] = "|" + "|".join(c + [" x "]) + "|"
open(p, "w", encoding="utf-8").write("\n".join(L))
EOF
for sub in agree columns; do
    zout="$(S4E_HOME="$SCRATCH" python3 "$HELPER" "$sub" 2>&1)"; zrc=$?
    if [ "$zrc" -ne 2 ]; then
        echo "GATE FAIL: $sub graded a grid with ZERO readable rows and did not REFUSE (rc=$zrc, wanted 2)"
        echo "$zout" | tail -2 | sed 's/^/    /'
        violations=$((violations + 1))
    fi
done
rm -rf "$SCRATCH"

# ARM 9 — ⛔⭐⭐ `check` MUST GRADE THE TREE THE CELL CLAIMS, NOT ONLY THE ONE IN THE Tree COLUMN.
# The defect this replays (hq_T 2026-09-05, found off seat13's make-test refusal report): `check` read
# cells[PROV_COL] and nothing else, on the premise that every measurement arrives through `write`, which
# stamps there. True for writes through the helper, silently false for the hand-edit -- and the board is
# full of hand-edits. Live witness at the time: snobol4's Rungs board cell read "LANE RE-MEASURE
# 2026-09-05 (hq_P) ... on SCRIP `f3f4870d7`" while its `board:` clause still read hq_B 2026-09-04 on
# `7d7ff2dc5`, so the number every human reader was looking at had never once been graded.
# ⭐ THE ARM IS TWO-SIDED ON PURPOSE. A detector is only worth its line count if it also stays QUIET on the
# agreeing case -- a one-sided arm passes just as well against a helper that shouts ADRIFT at every row.
examined=$((examined + 1))
S9="$(mktemp -d "${TMPDIR:-/tmp}/score_adrift.XXXXXX")"
mkdir -p "$S9/.github"
cp "$GH/SCORE.md" "$S9/.github/SCORE.md"
# `check` resolves its repos under S4E_HOME and only ever READS them (rev-list), so symlinks are enough.
git -C "$ROOT" worktree add --detach "$S9/SCRIP" HEAD >/dev/null 2>&1 && git -C "$ROOT/../corpus" worktree add --detach "$S9/corpus" HEAD >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot stage SCRIP and corpus as worktrees"; exit 2; }
NEW9="$(git -C "$ROOT" rev-parse --short=9 origin/main 2>/dev/null)"
OLD9="$(git -C "$ROOT" rev-parse --short=9 origin/main~60 2>/dev/null)"
if [ -z "$NEW9" ] || [ -z "$OLD9" ]; then
    echo "GATE FAIL: ARM 9 could not mint two trees to disagree with (origin/main unresolvable)"
    violations=$((violations + 1))
else
    # Pass the two trees through the ENVIRONMENT and quote the heredoc: an unquoted <<PY hands bash the whole
    # Python source, and every backtick in it runs as a command (CLAUDE.md, measured three times in one day).
    W9="$S9/.github/SCORE.md" NEW9="$NEW9" OLD9="$OLD9" python3 - <<'EOF'
import os, sys
p, NEW, OLD = os.environ["W9"], os.environ["NEW9"], os.environ["OLD9"]
L = open(p, encoding="utf-8").read().split("\n")
h = next((i for i, l in enumerate(L) if l.startswith("| Language |") and "Tree" in l), None)
if h is None:
    sys.exit("ARM 9 SETUP: no display table found")
picked = []
for i in range(h + 2, len(L)):
    if not L[i].startswith("| "):
        break
    c = L[i].strip().strip("|").split("|")
    if len(c) != 6 or set(L[i]) <= set("| -:"):
        continue
    lang = c[0].strip()
    if len(picked) == 0:
        # WITNESS: the cell claims a tree strictly NEWER than the clause that stamps it -- the hand-edit shape.
        c[3] = " gate-witness board reading on SCRIP `%s` corpus `deadbeef` " % NEW
        c[5] = " board: SCRIP `%s` · corpus `deadbeef` · RT_OPT=-O0 · 2026-01-01 00:00 CDT · gate-witness " % OLD
        picked.append(("adrift", lang))
    elif len(picked) == 1:
        # CONTROL: cell and clause name the SAME tree, so this row must stay silent.
        c[3] = " gate-control board reading on SCRIP `%s` corpus `deadbeef` " % OLD
        c[5] = " board: SCRIP `%s` · corpus `deadbeef` · RT_OPT=-O0 · 2026-01-01 00:00 CDT · gate-witness " % OLD
        picked.append(("control", lang))
        L[i] = "|" + "|".join(c) + "|"
        break
    L[i] = "|" + "|".join(c) + "|"
if len(picked) != 2:
    sys.exit("ARM 9 SETUP: needed two readable display rows, found %d" % len(picked))
open(p, "w", encoding="utf-8").write("\n".join(L))
open(os.environ["W9"] + ".langs", "w").write("%s %s\n" % (picked[0][1], picked[1][1]))
EOF
    if [ $? -ne 0 ]; then
        echo "GATE FAIL: ARM 9 could not build its witness"
        violations=$((violations + 1))
    else
        aw="$(awk '{print $1}' "$S9/.github/SCORE.md.langs")"
        ac="$(awk '{print $2}' "$S9/.github/SCORE.md.langs")"
        cout="$(S4E_HOME="$S9" python3 "$HELPER" check --no-fetch 2>&1)"; crc9=$?
        if [ "$crc9" -ge 2 ]; then
            echo "GATE FAIL: check REFUSED (rc=$crc9) over the ARM 9 witness"
            violations=$((violations + 1))
        fi
        # (a) the graded tree is the CELL's, not the clause's
        if ! printf '%s' "$cout" | grep -q "cell claims $NEW9"; then
            echo "GATE FAIL: check never graded the tree the cell claims ($NEW9) -- it is reading only the Tree column,"
            echo "           which is the whole defect this arm exists for"
            printf '%s' "$cout" | grep "^  $aw " | sed 's/^/    /'
            violations=$((violations + 1))
        fi
        # (b) and it must NAME the disagreement rather than quietly grading the newer tree
        if ! printf '%s' "$cout" | grep "^  $aw " | grep -q 'ADRIFT'; then
            echo "GATE FAIL: cell/clause disagreement on '$aw' was graded but never reported as ADRIFT"
            printf '%s' "$cout" | grep "^  $aw " | sed 's/^/    /'
            violations=$((violations + 1))
        fi
        # (c) THE QUIET SIDE: the agreeing row must not be flagged
        if printf '%s' "$cout" | grep "^  $ac  *board" | grep -q 'ADRIFT'; then
            echo "GATE FAIL: '$ac' cell and clause name the SAME tree, and check called it ADRIFT anyway --"
            echo "           a detector that fires on the agreeing case reports nothing"
            printf '%s' "$cout" | grep "^  $ac  *board" | sed 's/^/    /'
            violations=$((violations + 1))
        fi
    fi
fi
git -C "$ROOT" worktree remove --force "$S9/SCRIP" >/dev/null 2>&1; git -C "$ROOT/../corpus" worktree remove --force "$S9/corpus" >/dev/null 2>&1; rm -rf "$S9"

# ARM 8 — and the arms above must have graded the SCRATCH copy, never the board. Re-asserted here because
# ARM 6/7 are the first arms in this gate that point the helper at a different tree via S4E_HOME.
examined=$((examined + 1))
after6="$(git -C "$GH" status --porcelain -- SCORE.md 2>/dev/null)"
if [ "$after6" != "$before" ]; then
    echo "GATE FAIL: the blind-spot arms changed the REAL .github/SCORE.md"
    violations=$((violations + 1))
fi

# ARM 10 — ⛔⭐⭐ `--dry-run` PREVIEWS BOTH HALVES OR IT IS NOT A PREVIEW OF THIS COMMAND. `write` updates
# the display cell AND its mirrored grid cell, or says out loud that it could not (prose at risk, or a board
# line with no N/M fraction). The early return used to sit ABOVE that whole block, so the one way to ask
# "what will this write do?" showed the display rewrite and nothing about the grid -- not the update, and
# not the REFUSALS, which are the half a caller cannot recover from afterwards. Graded on a SCRATCH copy.
# Two assertions, and the second is what keeps the first honest: the preview must NAME the grid, and it must
# leave the file byte-identical -- a preview that previews by writing is the defect it exists to prevent.
examined=$((examined + 1))
S10="$(mktemp -d "${TMPDIR:-/tmp}/score_dryrun.XXXXXX")"
mkdir -p "$S10/.github/scripts"; cp "$GH/SCORE.md" "$S10/.github/SCORE.md"
# ⭐ THE SCRATCH TREE NEEDS THE SUITE TABLE TOO (hq_T 2026-09-06, ceo CEO-363): a V/M write now mirrors into
# .github/SUITES.tsv or refuses naming the row, so a scratch tree carrying only SCORE.md is not a scratch
# copy of what this command touches -- it is half of one, and the preview would refuse for a reason that is
# about the fixture rather than about the write.
[ -f "$SUITES_TSV_REAL" ] && cp "$SUITES_TSV_REAL" "$S10/.github/SUITES.tsv"
[ -f "$GH/scripts/util_suite_banner.py" ] && cp "$GH/scripts/util_suite_banner.py" "$S10/.github/scripts/util_suite_banner.py"
d10_before="$(md5sum < "$S10/.github/SCORE.md")"
d10out="$(S4E_HOME="$S10" python3 "$HELPER" write --lang icon --column vendor --suite Arizona \
    --text 'Arizona: m3 46/124 · m4 46/124 (`test_icon_arizona_suite.sh`)' --measurer hq_T --dry-run \
    --criterion-changed '2026-09-16:fixture -- this preview arm moves the Arizona denominator, so it carries the stamp CEO-785 requires' 2>&1)"; d10rc=$?
d10_after="$(md5sum < "$S10/.github/SCORE.md")"
if [ "$d10rc" -ne 0 ]; then
    echo "GATE FAIL: write --dry-run exited $d10rc over a scratch board (want 0)"
    printf '%s\n' "$d10out" | tail -3 | sed 's/^/    /'
    violations=$((violations + 1))
elif [ "$d10_before" != "$d10_after" ]; then
    echo "GATE FAIL: write --dry-run MODIFIED the board it was only asked to preview"
    violations=$((violations + 1))
elif ! printf '%s' "$d10out" | grep -q 'grid V'; then
    echo "GATE FAIL: write --dry-run previewed the display half and said NOTHING about the mirrored grid V cell --"
    echo "    the grid write (or its refusal) is invisible until the write is already done."
    printf '%s\n' "$d10out" | tail -3 | sed 's/^/    /'
    violations=$((violations + 1))
fi
rm -rf "$S10"

# ⛔⭐⭐ ARM 21-24 — THE CARRIAGE (CEO-316, off Lon 2026-09-06: "grade EVERY SINGLE package program from
# Icon and Prolog"). A V cell's shipped population used to come from PACKAGE_SHIPPED, three integers typed
# into util_score_row.py by a reader of somebody else's board. ⛔ A TRANSCRIBED DENOMINATOR CANNOT GO STALE
# LOUDLY -- it goes stale silently and every percent over it stays plausible. Measured on the live board
# while wiring this: the icon V cell says arizona has "35 never graded"; the runner's own line says
# ungraded=0 ungradable=34. Neither is 35, the cell was right when written, and nothing told it when it
# stopped being. The cell now carries the runner's own PACKAGE_INVENTORY line and this reader prefers it.
examined=$((examined + 1))
carr_out="$(python3 - <<'PYEOF' 2>&1
import importlib.util
spec = importlib.util.spec_from_file_location("u", "../harness/scripts/util_score_row.py")
u = importlib.util.module_from_spec(spec); spec.loader.exec_module(u)
cell = ("**arizona m3 46/90** graded · PACKAGE_INVENTORY package=arizona shipped=124 graded=90 ungraded=0 "
        "ungradable=34 by=test_icon_arizona_suite.sh")
inv, bad = u.inventory_clauses(cell)
print("PARSE", inv.get("arizona", {}).get("shipped"), inv.get("arizona", {}).get("runner"), len(bad))
# a clause whose buckets do not sum is DROPPED AND REPORTED -- never silently used, never silently ignored.
inv2, bad2 = u.inventory_clauses("PACKAGE_INVENTORY package=ipl shipped=851 graded=64 ungraded=211 ungradable=390")
print("NOSUM", len(inv2), len(bad2), "DOES NOT SUM" in (bad2[0] if bad2 else ""))
# the runner's own populations become legal denominators without a code edit: 90 is not in PROGRESS_COUNTED.
got, work = u.counted_fractions("icon", cell)
print("DEN90", got.get(90))
# and a package with no clause is NAMED, every run -- an unnamed gap is indistinguishable from a closed one.
_g, w2 = u.counted_fractions("icon", "**arizona m3 46/124** graded")
print("NAMED", any("NO PACKAGE_INVENTORY clause" in x for x in w2))
PYEOF
)"
for want in 'PARSE 124 test_icon_arizona_suite.sh 0' 'NOSUM 0 1 True' 'DEN90 46' 'NAMED True'; do
    examined=$((examined + 1))
    printf '%s' "$carr_out" | grep -qxF "$want" || {
        echo "GATE FAIL: leaderboard carriage arm '$want' not satisfied. Got:"; printf '      %s\n' "$carr_out"
        violations=$((violations + 1)); }
done

# ⛔⭐ THE PROGRESS LINE IS DELETED AND THIS ARM HOLDS IT DELETED (Lon 2026-09-13, in-chat, verbatim:
# "Do you see that banner with the bogus numbers for sno, sc, icn that says PROGRESS 09-13. All bogus.
# Delete that. Do not show that ever again.").  What stood here asserted the OPPOSITE -- that
# `util_score_row.py progress` prints a '^PROGRESS mm-dd |' score line -- and it was a correct arm for as
# long as the line was wanted.  It is inverted rather than removed, because the useful half survives the
# reversal: the subcommand must still RUN and exit 0, since several instruments invoke it and a missing
# subcommand would turn them red for asking; it must simply print NOTHING.  An arm that asserts a deletion
# is the only thing that stops a deletion being undone by the next seat who reads the old comment.
examined=$((examined + 1))
_prog_out="$(S4E_HOME="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}" python3 "$HERE/util_score_row.py" progress 2>&1)"; _prog_rc=$?
if [ "$_prog_rc" -ne 0 ]; then
    echo "GATE FAIL: \`util_score_row.py progress\` exits rc=$_prog_rc -- it must stay a working no-op, because instruments still invoke it and a missing subcommand turns them red for asking"
    printf '%s\n' "$_prog_out" | tail -4 | sed 's/^/      /'
    violations=$((violations + 1))
elif [ -n "$_prog_out" ]; then
    echo "GATE FAIL: \`util_score_row.py progress\` PRINTED SOMETHING -- Lon deleted the progress line on 2026-09-13 and it must never be shown again; it prints nothing and exits 0"
    printf '%s\n' "$_prog_out" | head -4 | sed 's/^/      /'
    violations=$((violations + 1))
fi

GATE_EXAMINED="$examined arms"
gate_verdict "$violations" "leaderboard write-path invariants broken"

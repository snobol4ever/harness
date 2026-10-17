#!/usr/bin/env bash
# DONE-WHEN for row icon-master-identity-gate-refuses-rc2-in-the-blocking-set-so-it-asserts-nothing (hq_V, CEO-586 -> CEO-547).
# ⛔ IT ASSERTS WHAT THE REFUSAL SAYS, NOT MERELY ITS CODE (CEO-547 part 2, RULES.md batch 23 / CEO-594). The refusal
# said "a rung suite suite run is a board and this seat is not the coo" -- which is CEO-523 working exactly as written.
# So the defect was never the guard and never the comparison: it was a BOARD SITTING IN THE BLOCKING SET. This grades
# both halves of the cure -- the gate is out of `make test` and in the coo's pass, AND the comparison still measures
# and can still say no. ⛔ NO POPULATION LITERAL: every count is read from what the gate prints.
set -u
R="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
G=test_gate_icon_rungs_per_entry_identity.sh
cd "$R/SCRIP" || { echo "DONE-WHEN rc=2: no SCRIP tree at $R/SCRIP"; exit 2; }
[ -f "../harness/scripts/$G" ] || { echo "DONE-WHEN rc=2: the gate is absent at ../harness/scripts/$G"; exit 2; }
fail() { echo "DONE-WHEN RED: $1"; exit 1; }
unproven() { echo "DONE-WHEN rc=2: $1"; exit 2; }
recipe() { python3 - "$1" <<'PY'
import re,sys,io
t=sys.argv[1]; out=[]; on=False
for l in open("Makefile",encoding="utf-8"):
    if re.match(r'^%s:' % re.escape(t), l): on=True; continue
    if on:
        if l.startswith("\t"): out.append(l)
        elif l.strip() and not l.startswith("#"): break
sys.stdout.write("".join(out))
PY
}
recipe test    | grep -q "$G" && fail "arm 1 -- the gate is STILL in the blocking set; it runs the corpus Icon rungs, which ONE RUNNER, ONE BOARD (CEO-523) refuses to every seat but the coo, so wired it can only ever exit rc=2"
recipe test-boards | grep -q "$G" || fail "arm 2 -- the gate is not in the coo's pass (make test-boards): CEO-547 moved it there, it must not simply vanish"
row="$(grep -P "^\Q$G\E\t" ../harness/scripts/gate_wiring.tsv)" || fail "arm 3 -- the gate is absent from gate_wiring.tsv, the one population"
cls="$(cut -f2 <<<"$row")"; why="$(cut -f3 <<<"$row")"; by="$(cut -f4 <<<"$row")"
[ "$cls" = RULING ] || fail "arm 4 -- gate_wiring.tsv still classes it $cls, not RULING"
[ -n "${why//[- ]/}" ] || fail "arm 5 -- the RULING carries no reason; an exemption list that accepts a blank reason is the silent backlog with a tidier name"
[ -n "${by//[- ]/}" ]  || fail "arm 6 -- the RULING carries no declarer; an exemption nobody signed is not a ruling"
# ⭐ THE HALF THAT PROVES THE MOVE DID NOT WEAKEN ANYTHING. The gate is fed THE ONE RUNNER'S OWN RECORDED BOARD of this
# tree (the coo's rows in the live progress table, selected by this tree's scrip commit) through the gate's own
# documented ICON_IDENTITY_MEASURED_FROM control arm -- so no board is re-run, no override is set, and the comparison
# under test is the same code the coo's pass executes.
DB="${S4E_PROGRESS_DB:-/home/resources/progress/results.tsv}"
[ -s "$DB" ] || unproven "the progress table $DB is absent or empty -- cannot reach a recorded board"
SC="$(git rev-parse --short=9 HEAD 2>/dev/null)" || unproven "cannot read this tree's scrip commit"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
# ⛔ THESE ARMS PROVE THE COMPARISON STILL MEASURES AND CAN STILL SAY NO -- they do NOT claim this tree is clean.
# That claim belongs to the coo's pass, which is where the gate now lives. So they prefer THIS tree's recorded board
# and FALL BACK to the one runner's newest board of any tree, SAYING WHICH -- because a DONE-WHEN gradable only in
# the window between a landing and the coo's next board is a DONE-WHEN that gets waved through.
head -1 "$DB" >"$T/m.tsv"
awk -F'\t' -v sc="$SC" '$6=="icon-rungs" && $2==sc && $4=="coo"' "$DB" >>"$T/m.tsv"
n=$(( $(wc -l <"$T/m.tsv") - 1 )); ON="of this tree"
if [ "$n" -eq 0 ]; then
    ALT="$(awk -F'\t' '$6=="icon-rungs" && $4=="coo"{t=$2} END{print t}' "$DB")"
    [ -n "$ALT" ] || unproven "the one runner has recorded no icon-rungs board at all -- there is nothing to grade, which is not a pass"
    head -1 "$DB" >"$T/m.tsv"
    awk -F'\t' -v sc="$ALT" '$6=="icon-rungs" && $2==sc && $4=="coo"' "$DB" >>"$T/m.tsv"
    n=$(( $(wc -l <"$T/m.tsv") - 1 )); SC="$ALT"; ON="NOT of this tree -- the one runner's newest board"
    echo "⚠ no coo icon-rungs board recorded for this tree; arms 7-12 grade the one runner's newest board (scrip $ALT) instead. They assert the COMPARISON measures, never that this tree is clean."
fi
[ "$n" -gt 0 ] || unproven "the recorded board for scrip $SC carries no rows -- there is nothing to grade, which is not a pass"
out="$(ICON_IDENTITY_MEASURED_FROM="$T/m.tsv" bash "../harness/scripts/$G" 2>&1)"; rc=$?
# ⛔ A STALE BINARY REFUSES EVERY DONE-WHEN rc=2 (CLAUDE.md), NEVER RED. Measured the hard way: `git stash pop`
# restored the Makefile with a fresh mtime, the gate's own freshness preflight refused, and arm 9 called that a
# REGRESSION -- an instrument reporting "your cure did not land" when the truth is "rebuild first".
grep -q 'is older than tracked source' <<<"$out" && unproven "this tree's binary is stale (the gate's own freshness preflight refused) -- run make, then re-grade"
grep -q 'ONE RUNNER, ONE BOARD' <<<"$out" && fail "arm 7 -- the gate still tried to run a board and collected the ONE-RUNNER refusal"
grep -q 'no SUITE_BOARD line'   <<<"$out" && fail "arm 8 -- the gate still reports 'measured nothing'"
[ "$rc" = 0 ] || [ "$rc" = 1 ] || fail "arm 9 -- expected a verdict (rc 0 clean or 1 red) from the recorded board, got rc=$rc"
grep -qE '^IDENTITY_RESULT examined=[0-9]+ ' <<<"$out" || fail "arm 10 -- no IDENTITY_RESULT line: the comparison never ran"
ex="$(grep -oE '^IDENTITY_RESULT examined=[0-9]+' <<<"$out" | head -1 | cut -d= -f2)"
[ "${ex:-0}" -gt 0 ] || fail "arm 11 -- examined=$ex: a pin that grades nothing cannot certify anything"
ICON_IDENTITY_MEASURED_FROM="$T/m.tsv" FAIL_ONCE=1 bash "../harness/scripts/$G" >/dev/null 2>&1; frc=$?
[ "$frc" = 1 ] || fail "arm 12 -- FAIL_ONCE did not make the gate say no (rc=$frc); an identity gate that cannot fail on an injected red is the floor defect wearing a new name"
echo "DONE-WHEN GREEN: the gate is out of the blocking set and in the coo's pass, RULING-declared with a reason and a declarer; fed the one runner's recorded board ($ON, $n rows, scrip $SC) it graded examined=$ex pinned pairs at rc=$rc, and FAIL_ONCE still reds it."
exit 0

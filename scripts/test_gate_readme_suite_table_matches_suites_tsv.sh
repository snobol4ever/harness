#!/usr/bin/env bash
# test_gate_readme_suite_table_matches_suites_tsv.sh -- THE README'S SUITE TABLE IS THE RENDER OF .github/SUITES.tsv, NEVER A HAND COPY.
#
# ⛔ THE DEFECT (row instruments-the-readme-suite-table-is-written-from-the-suite-table-and-a-gate-holds-it-current, the ceo on Lon's
# word 2026-09-23 16:2x, verbatim: "We want the test suite numbers and the benchmark numbers in the README."; CEO-1216; the coo). The
# README's suite table said it read the leaderboard "on 2026-09-07" sixteen days later -- Gimpel 104/127 there against 127/132 in the
# record, Budne 72/120 against 71/71, IPL 75/89 against 194/194 -- and two suites the record carries were not in it at all. A hand-kept
# copy of a table that moves about fifty times a day has no writer, so it is wrong within hours and nobody can say which cell.
#
# THE MECHANISM (.github/scripts/util_suite_banner.py): --readme renders the block between two marker lines from SUITES.tsv and stamps the
# .github commit it read (the PIN); --readme-check holds it.
#   --pinned  the block is EXACTLY the render of SUITES.tsv at its pin: a hand edit or a corrupted cell reds, and the reading never moves
#             with the other repo -- the BLOCKING arm.
#   (default) --pinned, and every row matches SUITES.tsv as it stands NOW: the currency the other repo moves about fifty times a day, so
#             it can lag between a lane's row write and the next render -- the REPORTED arm, and the row's DONE-WHEN.
# ARMS: 1 the pinned check reads green on the real README; 2 (default mode) the current check too; 3 FAIL-ONCE BUILT IN: a scratch copy of
# the README with ONE cell changed reds the pinned check and names the row; 4 the render names Raku IN DEVELOPMENT (CEO-1219) and no other
# language carries a label; 5 a copy whose markers are gone reds (the table is not generated at all).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=readme_suite_table_matches_suites_tsv
GATE_STRICT=1
PINNED=0; for a in "$@"; do [ "$a" = --pinned ] && PINNED=1; done
gate_parse_args "$@"
GH="$(cd "$ROOT/.." && pwd)/.github"
. "$(dirname "${BASH_SOURCE[0]}")/lib_suites_tsv.sh" || { echo "REFUSED(2): cannot load lib_suites_tsv.sh"; exit 2; }
B="$GH/scripts/util_suite_banner.py"
gate_require "$B" "the renderer .github/scripts/util_suite_banner.py" || exit 2
gate_require "$SUITES_TSV_REAL" "the machine record $SUITES_TSV_REAL" || exit 2
gate_require "$ROOT/README.md" "SCRIP/README.md" || exit 2
SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"
mkdir -p "$SCRATCH" || { echo "REFUSING(2) [$GATE_NAME]: cannot create $SCRATCH"; exit 2; }
WORK=$(mktemp -d "$SCRATCH/gate_readme_table_XXXXXX") || exit 2
trap '[ -n "${WORK:-}" ] && rm -rf "$WORK"' EXIT INT TERM
fails=0; examined=0; unproven=0

# ARM 1 -- the real README is exactly its pin's render.
examined=$((examined+1))
out=$(python3 "$B" --readme-check "$ROOT/README.md" --pinned 2>&1); rc=$?
case "$rc" in
  0) : ;;
  2) unproven=$((unproven+1)); echo "  UNPROVEN arm1: $(printf '%s\n' "$out" | head -1)" ;;
  *) fails=$((fails+1)); echo "  FAIL arm1: the README block is not the render of SUITES.tsv at its own pin:"; printf '%s\n' "$out" | head -8 | sed 's/^/        /' ;;
esac

# ARM 2 -- currency (default mode only): every row matches SUITES.tsv as it stands now.
if [ "$PINNED" = 0 ]; then
  examined=$((examined+1))
  out=$(python3 "$B" --readme-check "$ROOT/README.md" 2>&1); rc=$?
  case "$rc" in
    0) : ;;
    2) unproven=$((unproven+1)); echo "  UNPROVEN arm2: $(printf '%s\n' "$out" | head -1)" ;;
    *) fails=$((fails+1)); echo "  FAIL arm2: README rows lag SUITES.tsv as it stands now:"; printf '%s\n' "$out" | grep -v 'PINNED OK' | head -8 | sed 's/^/        /' ;;
  esac
fi

# ARM 3 -- FAIL-ONCE BUILT IN: one corrupted cell in a scratch copy reds the pinned check and names the row.
examined=$((examined+1))
cp "$ROOT/README.md" "$WORK/README.md"
row="$(grep -m1 -E '^\| SNOBOL4 \| Gimpel \| \*\*[0-9]+/[0-9]+\*\* \|' "$WORK/README.md")"
if [ -z "$row" ]; then
  fails=$((fails+1)); echo "  FAIL arm3: no Gimpel row in the README block to corrupt -- the table is not the one SUITES.tsv renders"
else
  bad="$(printf '%s' "$row" | sed -E 's/\*\*([0-9]+)\/([0-9]+)\*\*/**999\/\2**/')"
  python3 - "$WORK/README.md" "$row" "$bad" <<'PY'
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding='utf-8').read(); open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
  out=$(python3 "$B" --readme-check "$WORK/README.md" --pinned 2>&1); rc=$?
  if [ "$rc" != 1 ] || ! printf '%s\n' "$out" | grep -q '999/'; then
    fails=$((fails+1)); echo "  FAIL arm3: a corrupted Gimpel cell (999/...) read rc=$rc and was not named -- the check cannot see a wrong number"
  fi
fi

# ARM 4 -- Raku is labelled IN DEVELOPMENT (CEO-1219) and no other language carries a label.
examined=$((examined+1))
blk="$(sed -n '/^<!-- SUITE-TABLE:BEGIN/,/^<!-- SUITE-TABLE:END -->/p' "$ROOT/README.md")"
rk=$(printf '%s\n' "$blk" | grep -c '^| Raku — IN DEVELOPMENT |'); other=$(printf '%s\n' "$blk" | grep -E '^\| [A-Za-z0-9]+ — ' | grep -vc '^| Raku — ')
if [ "$rk" -lt 1 ] || [ "$other" != 0 ]; then
  fails=$((fails+1)); echo "  FAIL arm4: Raku rows labelled IN DEVELOPMENT=$rk (want >=1), other labelled rows=$other (want 0)"
fi

# ARM 5 -- a README with no generated block reds (the table is not generated at all).
examined=$((examined+1))
grep -v -e '^<!-- SUITE-TABLE:BEGIN' -e '^<!-- SUITE-TABLE:END -->' "$ROOT/README.md" > "$WORK/README.nomarkers.md"
out=$(python3 "$B" --readme-check "$WORK/README.nomarkers.md" --pinned 2>&1); rc=$?
[ "$rc" = 1 ] || { fails=$((fails+1)); echo "  FAIL arm5: a README with no generated block read rc=$rc, want 1"; }

GATE_EXAMINED=$examined
if [ "$fails" -eq 0 ] && [ "$unproven" -gt 0 ]; then
  echo "GATE UNPROVEN(2) [$GATE_NAME]: $unproven arm(s) could not measure, 0 failed -- NOT a pass (examined $examined)"; gate_stamp; exit 2
fi
gate_verdict "$fails" "arm(s) failed (the README suite table must be the render of SUITES.tsv$([ "$PINNED" = 1 ] && echo ' at its pin'))"

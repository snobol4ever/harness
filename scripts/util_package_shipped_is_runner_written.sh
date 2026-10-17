#!/usr/bin/env bash
# util_package_shipped_is_runner_written.sh — PER LANE: does every package in this language's V cell take
# its SHIPPED population from its own runner's PACKAGE_INVENTORY clause, or from a number somebody typed?
#
# Row package-shipped-per-lane-printed-by-the-runner-not-transcribed (hq_T). This is that row's DONE-WHEN,
# as an instrument rather than a shell one-liner in a baton, for the reason the row itself is about: a
# criterion that lives as prose in one file is a criterion nobody can re-run.
#
# ⛔⭐ WHY IT DOES NOT GREP FOR THE STRING `PACKAGE_SHIPPED`, which is what the minted DONE-WHEN did
# (`grep -c PACKAGE_SHIPPED .github/SCORE.md >= 1`): that criterion is satisfied by TYPING THE NAME OF THE
# TRANSCRIBED DICT ONTO THE LEADERBOARD, and it can never be satisfied by curing the defect, because the
# cure removes every reason for that token to appear anywhere near the board. ⭐ A criterion whose only
# passing state is the defect's own name is worse than no criterion: it reads as rigour and rewards the
# wrong edit. So this asks the READER instead -- util_score_row.py's own work lines, which name every
# package that fell back to the dict and every package whose clause it could not find.
#
# Usage: bash ../harness/scripts/util_package_shipped_is_runner_written.sh [lang ...]   (default: every lane in the table)
# rc=0 every named lane is runner-written · rc=1 at least one is not · rc=2 CANNOT MEASURE (no row, no board)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
BOARD="$ROOT/../.github/SCORE.md"
[ -f "$BOARD" ] || { echo "REFUSE(2): no SCORE.md at $BOARD -- cannot measure"; exit 2; }
LANGS="$*"
# ⛔ THE SCRIPTS DIR GOES IN BY ENVIRONMENT, NEVER BY INTERPOLATION -- the heredoc delimiter stays QUOTED
# (`<<'PY'`), so no backtick or $ in the Python below can reach bash. Unquoting a heredoc to pass ONE value
# hands the shell the whole program (measured 2026-09-03, hq_T: `sbl -bf` printed its usage banner from
# inside a Python source file).
SCORE_MD="$BOARD" WANT="$LANGS" SCRIP_SCRIPTS="$HERE" python3 - <<'PY'
import io, os, subprocess, sys
sys.path.insert(0, os.environ['SCRIP_SCRIPTS'])
import util_score_row as U
s = io.open(os.environ['SCORE_MD'], encoding='utf-8').read()
want = os.environ.get('WANT', '').split() or sorted(U.PROGRESS_COUNTED)
cells, red, graded_lanes = {}, [], 0
for ln in s.split('\n'):
    if ln.startswith('| ') and ln.count('|') >= 8:
        lang = ln.split('|')[1].strip()
        if lang in U.PROGRESS_COUNTED and lang not in cells:
            cells[lang] = ln.split('|')[4]
missing_row = [l for l in want if l not in cells]
if missing_row:
    print('REFUSE(2): no row in SCORE.md for %s -- cannot measure' % ', '.join(missing_row))
    sys.exit(2)
for lang in want:
    got, work = U.counted_fractions(lang, cells[lang])
    bad = [w for w in work if 'PACKAGE_SHIPPED' in w or 'carry NO PACKAGE_INVENTORY clause' in w]
    graded_lanes += 1
    pkgs = [n for n, _rx, _d in U.PROGRESS_COUNTED[lang]]
    if bad:
        red.append(lang)
        # ⛔ THE COUNT IS DERIVED FROM THE NAMES THE READER PRINTED, never typed beside them: a first draft
        # of this line printed a literal 0 as "N package(s) of M", which is the transcription defect this
        # whole row is about, committed inside the row's own criterion.
        named = sorted({n for n in pkgs if any(n in w for w in bad)})
        print('RED  %-8s %d of %d package(s) do not take shipped from their own runner (%s):'
              % (lang, len(named), len(pkgs), ', '.join(named) or 'unnamed'))
        for w in bad:
            print('       ' + w[:240])
        # ⛔⭐ AND THE CAUSE IS MEASURED, NOT ENUMERATED. The work line above can observe only an ABSENCE --
        # util_score_row.py reads the cell and nothing else -- so it has to LIST the causes, and a list
        # written from memory has been wrong twice: it named one cause on 2026-09-10 (wrong for both
        # packages it reported that day), was cured to two, and on 2026-09-11 both named causes were wrong
        # for FOUR of the seven it reports -- snobol4's gimpel/aisnobol/dotnet/testpgms are wired AND their
        # sidecars validate, so their cells are prose only because no suite pass has rewritten them.
        # ⭐ THIS reader is allowed to look, so it looks: one directory, one grep, one call to the shared
        # body, per package, and the answer is a FACT instead of a menu. A wrong cause is a WORK LIST --
        # this row's own baton sent its next reader to retrofit four runners that were already correct.
        for _n, _rx, _d in U.PROGRESS_COUNTED[lang]:
            if not any(_n in w for w in bad):
                continue
            _r = subprocess.run(['bash', os.path.join(os.environ['SCRIP_SCRIPTS'], 'util_package_inventory_cause.sh'),
                                 lang, _n, _rx], capture_output=True, text=True)
            # ⛔ A REFUSAL IS PRINTED, NEVER SWALLOWED: rc=2 means this reader could not determine the cause
            # (an ambiguous regex, no derivable extension), which is a different answer from every cause and
            # must not read as one. It does not change the lane's verdict -- the cell is still transcribed.
            for _ln in (_r.stdout or _r.stderr or 'CAUSE=? %s: the cause reader produced no output' % _n).strip().split('\n'):
                print('         ' + _ln.strip()[:300])
    else:
        print('OK   %-8s all %d package(s) take shipped from a runner-written PACKAGE_INVENTORY clause'
              % (lang, len(pkgs)))
print('lanes examined=%d  red=%d  (%s)' % (graded_lanes, len(red), ', '.join(red) or 'none'))
sys.exit(1 if red else 0)
PY

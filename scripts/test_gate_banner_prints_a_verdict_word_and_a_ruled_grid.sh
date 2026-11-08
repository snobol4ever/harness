#!/bin/bash
# ⛔⭐ THE GATE THAT DID NOT EXIST WHEN IT WAS NEEDED (cfo 2026-09-13, on Lon's word "Hey where is the banner
# showing SUCCESS and FAILURE?"). The printed banner was deleted at c902a4b73 and for the hours that followed
# EVERY SEAT'S Stop hook fired an EMPTY STRING -- measured, rc=0 and zero bytes. Nothing caught it: the verdict
# was still COMPUTED correctly and written to BOARD.md, so every file-reading instrument stayed green while the
# one display Lon reads every turn was blank. Lon found it before the fleet did.
# ⛔ THE LESSON THIS GATE ENCODES: a display that is only asserted through the FILE IT ALSO WRITES cannot be
# shown to have printed. Assert the PRINT, on stdout, or a silent banner is indistinguishable from a working one.
# ⭐ IT ASSERTS SHAPE, NEVER CONTENT: the verdict must be one of the four closed words, the compact header must
# carry its column names, and a data row must appear. It must NOT assert a suite number, a suite count, or a column VALUE -- those move every day and a gate
# that pins them would red on honest movement, which is the failure class that deleted the display in the first
# place (a gate whose subject is the display, pinned to a constant, going stale and being "fixed" by deletion).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# ⛔⭐ THE SUBJECT IS THE TREE THIS SCRIPT LIVES IN, AND IT IS THE SCRIPT NEXT DOOR (cured 2026-09-13 by hq_B
# on hq_C's flag; test_gate_no_worktree_blind_subject.sh's own advice line). This read `$ROOT/harness/scripts/
# s4e_msg.sh` -- up to the sibling root and back DOWN into the literal name `SCRIP`, which is the name of the
# MAIN checkout and of nothing else, so a preflight run in a worktree graded the main tree's banner instead of
# the one being pushed. ⭐ THE TELL THAT IT WAS ALWAYS WRONG RATHER THAN MERELY FRAGILE: the subject is a file
# in THIS SCRIPT'S OWN DIRECTORY, so the round trip could never reach anything the bare `$HERE` did not
# already name -- two hops and a hardcoded string to arrive one directory below where we started.
M="$HERE/s4e_msg.sh"
[ -f "$M" ] || { echo "⛔ REFUSE(2): no $M"; exit 2; }
# S4E_BANNER_NO_BOARD keeps this gate from clobbering the live BOARD.md row of whoever runs it.
out="$(S4E_BANNER_GRID=1 S4E_BANNER_NO_BOARD=1 timeout -k 5 100 bash "$M" banner 2>&1)"; brc=$?
[ -n "$out" ] || { echo "⛔ RED: banner printed ZERO BYTES (rc=$brc) -- this is the exact 2026-09-13 blackout"; exit 1; }
# THE SHAPE (2026-11-07, the coo's cut on the banner's own layout): the default banner is the double-sided grid that
# .github/scripts/banner_compact.py prints, which draws no ruled rows (the ruled border was the single-sided grid's
# shape, replaced 2026-11-04). The shape is: the verdict word on a line of its own; the compact header with its
# column NAMES (Lang Suite Pass/Tot Excl M3 M4 Δ Pct Min); and at least one data row under it. Names, never values,
# and no count is pinned: the rows are whatever the suite table holds.
shape() {
  printf '%s\n' "$1" | grep -qE '^(SUCCESS|IN-PROGRESS|DRAIN|STOP)$' || { echo "no verdict word on a line of its own; expected one of SUCCESS / IN-PROGRESS / DRAIN / STOP"; return 1; }
  printf '%s\n' "$1" | grep -qE '^Lang +Suite +Pass/Tot +Excl +M3 +M4 +Δ +Pct +Min .*│' || { echo "no compact header row with the columns Lang Suite Pass/Tot Excl M3 M4 Δ Pct Min (banner_compact.py)"; return 1; }
  printf '%s\n' "$1" | grep -qE '^[a-z]+ +[A-Za-z0-9@_.-]+ +[0-9]+/[0-9]+ .*│' || { echo "no compact data row under the header"; return 1; }
  if printf '%s\n' "$1" | grep -qE 'SUITE GRID (MISSING|REFUSED)'; then echo "the grid renderer refused"; return 1; fi
  return 0
}
rc=0
r="$(shape "$out")" || { echo "⛔ RED: $r"; rc=1; }
# FAIL-ONCE (CEO-1680): the live banner with one thing taken out must read RED on the shape, or the arm could not fail.
p_noverdict="$(printf '%s\n' "$out" | grep -vE '^(SUCCESS|IN-PROGRESS|DRAIN|STOP)$')"
p_nocol="$(printf '%s\n' "$out" | sed 's/ Excl / Xcl  /')"
if r="$(shape "$p_noverdict")"; then echo "⛔ RED: the plant without the verdict word reads GREEN -- the verdict arm cannot fail"; rc=1
else echo "  fail-once: a banner without the verdict word reads RED ($r)"; fi
if r="$(shape "$p_nocol")"; then echo "⛔ RED: the plant with the Excl column renamed reads GREEN -- the header arm cannot fail"; rc=1
else echo "  fail-once: a banner whose header lost Excl reads RED ($r)"; fi
[ "$rc" = 0 ] && echo "GATE OK: banner prints a verdict word from the closed set, the compact header with its column names and a data row; a plant without the verdict word and a plant with a renamed column both read RED (names asserted, no value or count pinned)"
exit $rc

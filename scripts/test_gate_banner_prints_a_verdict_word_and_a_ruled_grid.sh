#!/bin/bash
# ⛔⭐ THE GATE THAT DID NOT EXIST WHEN IT WAS NEEDED (cfo 2026-09-13, on Lon's word "Hey where is the banner
# showing SUCCESS and FAILURE?"). The printed banner was deleted at c902a4b73 and for the hours that followed
# EVERY SEAT'S Stop hook fired an EMPTY STRING -- measured, rc=0 and zero bytes. Nothing caught it: the verdict
# was still COMPUTED correctly and written to BOARD.md, so every file-reading instrument stayed green while the
# one display Lon reads every turn was blank. Lon found it before the fleet did.
# ⛔ THE LESSON THIS GATE ENCODES: a display that is only asserted through the FILE IT ALSO WRITES cannot be
# shown to have printed. Assert the PRINT, on stdout, or a silent banner is indistinguishable from a working one.
# ⭐ IT ASSERTS SHAPE, NEVER CONTENT: the verdict must be one of the four closed words and a ruled row must
# appear. It must NOT assert a suite number, a suite count, or a column set -- those move every day and a gate
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
out="$(S4E_BANNER_NO_BOARD=1 timeout -k 5 100 bash "$M" banner 2>&1)"; brc=$?
[ -n "$out" ] || { echo "⛔ RED: banner printed ZERO BYTES (rc=$brc) -- this is the exact 2026-09-13 blackout"; exit 1; }
rc=0
if printf '%s\n' "$out" | grep -qE '^(SUCCESS|IN-PROGRESS|DRAIN|STOP)$'; then :
else echo "⛔ RED: no verdict word on a line of its own; expected one of SUCCESS / IN-PROGRESS / DRAIN / STOP"; rc=1; fi
if printf '%s\n' "$out" | grep -q '─'; then :
else echo "⛔ RED: no ruled grid row -- the suite grid did not render"; rc=1; fi
if printf '%s\n' "$out" | grep -qE 'SUITE GRID (MISSING|REFUSED)'; then
  printf '%s\n' "$out" | grep -E 'SUITE GRID (MISSING|REFUSED)'; echo "⛔ RED: the grid renderer refused"; rc=1; fi
[ "$rc" = 0 ] && echo "GATE OK: banner prints a verdict word from the closed set and a ruled suite grid (shape asserted, no number pinned)"
exit $rc

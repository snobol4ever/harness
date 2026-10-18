#!/usr/bin/env bash
# test_gate_progress_flips_a_program_that_stops_being_graded_went_dark.sh -- a PASS that becomes DEFERRED or UNGRADABLE is a program
# that WENT DARK, printed on its own line and named. It is never "lost" (it is not red) and never "reclassified, not a loss" (the
# measurement is gone). PASS -> OUTSIDE stays the one reclassification (ceo CEO-806).
#
# THE MEASUREMENT THAT PUT THIS HERE (coo 2026-09-25, ceo CEO-1270): X64T's math_diff, math_div, math_prod and math_sum were m4 PASS
# on 55f6339b9 (09-24) and m4 DEFERRED on 04549eb5c (09-25), when the statement switch took their asm from 101.5 MB to 169.6 MB, past
# the runner's 128 MB budget. util_progress_flips.py read "lost since the base: package 0" and "reclassified (PASS -> OUTSIDE/UNGRADABLE/
# UNGRADED/DEFERRED, not a loss): package 4" -- four correct programs the runner stopped grading, reported as nothing lost. CEO-806
# ruled only PASS -> OUTSIDE a reclassification; the wider set had no ruling behind it.
#
# ARMS on a planted table read through --db (HERMETIC: never the live database):
#   D  PASS -> DEFERRED      went dark, named with its mode and outcome; not lost; not reclassified
#   U  PASS -> UNGRADABLE    went dark, the same three
#   O  PASS -> OUTSIDE       reclassified; not lost; not dark
#   F  PASS -> FAIL          lost; not dark
#   G  PASS -> UNGRADED      no line at all: UNGRADED is NOT_A_READING, so the last real reading (PASS) stands
#   count                    the NET line reads went DARK: rungs 2
# ⭐ FAIL-ONCE IS BUILT IN, EVERY RUN: the same arms grade the reader at the parent of the commit that introduced "went DARK" (found
# with `git log -S` in .github's own history). It must red on exactly the arms the cure changed -- D_dark, D_not_reclassified,
# U_dark, U_not_reclassified and count_2 -- and stay green on the rest by construction (O F G, and D/U not lost, which the old reader
# also read correctly).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=progress_flips_a_program_that_stops_being_graded_went_dark
GATE_STRICT=1
gate_parse_args "$@"
GH="$(cd "$ROOT/.." && pwd)/.github"
F="$GH/scripts/util_progress_flips.py"
gate_require "$F" "util_progress_flips.py" || exit 2
SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"
mkdir -p "$SCRATCH" || { echo "REFUSING(2) [$GATE_NAME]: cannot create $SCRATCH"; exit 2; }
WORK=$(mktemp -d "$SCRATCH/gate_flips_dark_XXXXXX") || exit 2
trap '[ -n "${WORK:-}" ] && rm -rf "$WORK"' EXIT INT TERM

cc=$(git -C "$GH" log --format=%h -1 -S'went DARK' -- ../harness/scripts/util_progress_flips.py)
if [ -z "$cc" ]; then echo "GATE UNPROVEN(2) [$GATE_NAME]: the rule's commit is not in $GH's history -- pull .github"; gate_stamp; exit 2; fi
git -C "$GH" show "$cc^:../harness/scripts/util_progress_flips.py" > "$WORK/old.py" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot read the old reader at $cc^"; gate_stamp; exit 2; }
# The seven rung suites were renamed after this cure (Lon 2026-09-29: sno-master -> sno-rungs, snobol4-master -> snobol4-rungs,
# class master -> rungs): the old reader gets the same names, so the fail-once compares algorithms, never spellings (the
# normalisation test_gate_progress_readers_stream_and_answer_the_same.sh applies to its own two historical readers).
perl -pi -e 's/\b(sno|icn|pl|pas|raku|snc|reb|snobol4|icon|prolog|pascal|snocone|rebus)-master\b/$1-rungs/g; s/(["\x27])master\1/$1rungs$1/g; s/board_icon_master/board_icon_rungs/g' "$WORK/old.py"
echo "  old reader: util_progress_flips.py at $cc^ (.github history)"

H=$(date -u -d '10 hours ago' +%FT%T); W1=$(date -u -d '2 hours ago' +%FT%T)
{ printf 'ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\tfingerprint\tconfig\n'
  for x in "D $H PASS" "D $W1 DEFERRED" "U $H PASS" "U $W1 UNGRADABLE" "O $H PASS" "O $W1 OUTSIDE" "F $H PASS" "F $W1 FAIL" "G $H PASS" "G $W1 UNGRADED"; do
    set -- $x
    printf '%s\tabc1234\tdef5678\tfx\trungs\tfx\tsnobol4\t%s\tm4\t%s\t0\t\t\t\n' "$2" "$1" "$3"
  done; } > "$WORK/r.tsv"

grade() {   # grade <reader> <label> -- one "ARM <name> ok|RED" line per arm
  local out rc
  out=$(python3 "$1" --db "$WORK/r.tsv" --since 5h --mode m4 --names 2>&1); rc=$?
  printf '%s\n' "$out" > "$WORK/$2.out"
  if [ "$rc" != 0 ] || ! grep -q '^NET distinct programs' <<<"$out"; then echo "ARM run UNMEASURED rc=$rc"; return; fi
  a() { if eval "$2"; then echo "ARM $1 ok"; else echo "ARM $1 RED"; fi; }
  has() { grep -qE "$1" <<<"$out"; }
  a D_dark              'has "^ +went dark fx:D -> m4 DEFERRED"'
  a D_not_lost          '! has "^ +lost fx:D "'
  a D_not_reclassified  '! has "^ +reclassified fx:D "'
  a U_dark              'has "^ +went dark fx:U -> m4 UNGRADABLE"'
  a U_not_lost          '! has "^ +lost fx:U "'
  a U_not_reclassified  '! has "^ +reclassified fx:U "'
  a O_reclassified      'has "^ +reclassified fx:O -> OUTSIDE" && ! has "^ +went dark fx:O " && ! has "^ +lost fx:O "'
  a F_lost              'has "^ +lost fx:F " && ! has "^ +went dark fx:F "'
  a G_no_line           '! has "fx:G( |$)"'
  a count_2             'has "went DARK \(PASS -> DEFERRED/UNGRADABLE[^)]*\): rungs 2,"'
}
new=$(grade "$F" new); old=$(grade "$WORK/old.py" old)
fails=0
echo "  the reader under test ($F):"
printf '%s\n' "$new" | sed 's/^/    /'
bad=$(printf '%s\n' "$new" | grep -c ' RED$\| UNMEASURED')
[ "$bad" = 0 ] || { fails=$((fails+1)); echo "  FAIL: $bad arm(s) red on the reader under test -- its output:"; sed 's/^/      /' "$WORK/new.out"; }
want="D_dark D_not_reclassified U_dark U_not_reclassified count_2"
got=$(printf '%s\n' "$old" | awk '$3=="RED"{print $2}' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')
echo "  the old reader, the built-in fail-once: red on [$got]; must be exactly [$want] (D_not_lost U_not_lost O_reclassified F_lost G_no_line are green on it by construction)"
if grep -q 'UNMEASURED' <<<"$old"; then fails=$((fails+1)); echo "  FAIL: the old reader could not be run -- the fail-once is unproven"; sed 's/^/      /' "$WORK/old.out" | tail -5
elif [ "$got" != "$want" ]; then fails=$((fails+1)); echo "  FAIL: the arms the old reader reds are not the arms the cure changed -- the assertions no longer see the defect they were written for"; fi
examined=2
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: 10 arms green on the reader under test, and the old reader reds exactly the 5 the cure changed (examined $examined readers)"; gate_stamp; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $fails check(s) failed (examined $examined readers)"; gate_stamp; exit 1

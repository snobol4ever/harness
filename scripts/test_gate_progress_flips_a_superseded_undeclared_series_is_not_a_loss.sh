#!/usr/bin/env bash
# test_gate_progress_flips_a_superseded_undeclared_series_is_not_a_loss.sh -- THE NET MEASURE READS A PROGRAM ACROSS ITS RUNNER'S SWITCH
# FROM AN UNDECLARED CONFIGURATION TO A DECLARED ONE, AND NEVER HIDES A DECLARED DIVERGENCE WHILE DOING IT.
#
# ⛔ THE DEFECT (the ceo's measurement 2026-09-23 17:0x CDT; row instruments-progress-flips-counts-a-program-lost-when-its-runner-began-
# declaring-a-config-and-the-undeclared-series-stopped, the coo). .github/scripts/util_progress_flips.py keys its NET series on (suite,
# program, mode, config) -- rightly, CEO-1047/1050: a shipped PASS must never hide an arena FAIL. But when a runner began DECLARING its
# configuration, the program's undeclared series stopped, and its last reading stayed its verdict forever: over 09-20..09-23 the tool
# listed 37 rungs programs LOST and every one of the 37 PASSED on its latest published clean reading. The gain count had the mirror
# fault: a series that went red-to-green before the switch read as a gain the program no longer has, and a program red before the
# switch and green after it read as no gain at all.
# THE CURE (one rule): an undeclared series is SUPERSEDED when a declared series of the same (suite, program, mode) has a clean reading
# after its last one; it stops being a position, and every declared series born inside the window after its base INHERITS that base.
# ONLY the series that CONTINUES the undeclared one inherits (CONTINUES_UNDECLARED, `shipped`): the first cut handed the base to every
# declared series born in the window and, on the frozen 4.18M-row snapshot, rungs LOST went 37 -> 83 -- sixty stress and arena series
# read as losses against an undeclared PASS they never continued. Across configurations a change is a differential, not a flip.
# A declared series is never superseded: one that stopped (a retired arm) stays LOST and says STOPPED beside the program's latest reading.
#
# THE FIXTURE (hermetic: a planted table through --db, a 5 h window; H before it, W1 and W2 inside it):
#   P   undeclared PASS@H FAIL@W1, shipped PASS@W2     -> NOT lost (the ceo's 37)            M1  undeclared FAIL@H, shipped PASS@W2 -> GAINED
#   P2  undeclared PASS@H FAIL@W1, shipped FAIL@W2     -> lost, across the switch            M2  undeclared FAIL@H PASS@W1, shipped FAIL@W2
#   R   undeclared PASS@H FAIL@W1, never switched      -> lost                                    -> NOT gained (the old rule's false gain)
#   S   shipped PASS@H FAIL@W1                         -> lost (declared series untouched)   A   undeclared PASS@H, shipped PASS@W2 and
#   T   SCRIP_HEAP_KB=64 PASS@H FAIL@W1, shipped PASS@W2 -> lost AND STOPPED (an arena FAIL       arena_mb=1 FAIL@W2 -> neither lost nor
#       beside a shipped PASS: the cure may not hide it)                                          gained (a differential; its own base)
# ⭐ FAIL-ONCE IS BUILT IN, AND EVERY RUN: the same arms grade the OLD reader, taken from .github's own history (the parent of the commit
# that introduced the rule, found with `git log -S`), and it must red EXACTLY on the arms the cure changes -- P (it listed P lost),
# T-STOPPED, the superseded count, and M1's gain (it named no gain at all). The other arms are green on the old reader BY CONSTRUCTION
# and are named so nobody reads their green as coverage: P2 R S T lost (the old reader listed them too), M2 not gained (it named no
# gains), and A neither lost nor gained (it never compared across configurations). A gate whose assertions cannot see the defect is a
# gate that reads "there was never a bug here".
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=progress_flips_a_superseded_undeclared_series_is_not_a_loss
GATE_STRICT=1
gate_parse_args "$@"
GH="$(cd "$ROOT/.." && pwd)/.github"
F="$GH/scripts/util_progress_flips.py"
gate_require "$F" "util_progress_flips.py" || exit 2
SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"
mkdir -p "$SCRATCH" || { echo "REFUSING(2) [$GATE_NAME]: cannot create $SCRATCH"; exit 2; }
WORK=$(mktemp -d "$SCRATCH/gate_flips_superseded_XXXXXX") || exit 2
trap '[ -n "${WORK:-}" ] && rm -rf "$WORK"' EXIT INT TERM

cc=$(git -C "$GH" log --format=%h -1 -S'superseded undeclared series' -- ../harness/scripts/util_progress_flips.py)
if [ -z "$cc" ]; then echo "GATE UNPROVEN(2) [$GATE_NAME]: the rule's commit is not in $GH's history -- pull .github"; gate_stamp; exit 2; fi
git -C "$GH" show "$cc^:../harness/scripts/util_progress_flips.py" > "$WORK/old.py" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot read the old reader at $cc^"; gate_stamp; exit 2; }
# The seven rung suites were renamed after this cure (Lon 2026-09-29: sno-master -> sno-rungs, snobol4-master -> snobol4-rungs,
# class master -> rungs): the old reader gets the same names, so the fail-once compares algorithms, never spellings (the
# normalisation test_gate_progress_readers_stream_and_answer_the_same.sh applies to its own two historical readers).
perl -pi -e 's/\b(sno|icn|pl|pas|raku|snc|reb|snobol4|icon|prolog|pascal|snocone|rebus)-master\b/$1-rungs/g; s/(["\x27])master\1/$1rungs$1/g; s/board_icon_master/board_icon_rungs/g' "$WORK/old.py"
echo "  old reader: util_progress_flips.py at $cc^ (.github history)"

H=$(date -u -d '10 hours ago' +%FT%T); W1=$(date -u -d '3 hours ago' +%FT%T); W2=$(date -u -d '1 hour ago' +%FT%T)
{ printf 'ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\tfingerprint\tconfig\n'
  for x in "P $H PASS -" "P $W1 FAIL -" "P $W2 PASS shipped" "P2 $H PASS -" "P2 $W1 FAIL -" "P2 $W2 FAIL shipped" "R $H PASS -" "R $W1 FAIL -" \
           "S $H PASS shipped" "S $W1 FAIL shipped" "T $H PASS SCRIP_HEAP_KB=64" "T $W1 FAIL SCRIP_HEAP_KB=64" "T $W2 PASS shipped" \
           "M1 $H FAIL -" "M1 $W2 PASS shipped" "M2 $H FAIL -" "M2 $W1 PASS -" "M2 $W2 FAIL shipped" \
           "A $H PASS -" "A $W2 PASS shipped" "A $W2 FAIL arena_mb=1"; do
    set -- $x; c=$4; [ "$c" = - ] && c=
    printf '%s\tabc1234\tdef5678\tfx\trungs\tfx\tsnobol4\t%s\tm3\t%s\t0\t\t\t%s\n' "$2" "$1" "$3" "$c"
  done; } > "$WORK/r.tsv"

# grade <reader> <label> -- prints one "ARM <name> ok|RED" line per arm, and the reader's own output under it when asked
grade() {
  local out rc
  out=$(python3 "$1" --db "$WORK/r.tsv" --since 5h --names 2>&1); rc=$?
  printf '%s\n' "$out" > "$WORK/$2.out"
  if [ "$rc" != 0 ] || ! grep -q '^NET distinct programs' <<<"$out"; then echo "ARM run UNMEASURED rc=$rc"; return; fi
  a() { if eval "$2"; then echo "ARM $1 ok"; else echo "ARM $1 RED"; fi; }
  has() { grep -qE "$1" <<<"$out"; }
  a P_not_lost      '! has "^ +lost fx:P "'
  a P2_lost         'has "^ +lost fx:P2 "'
  a R_lost          'has "^ +lost fx:R "'
  a S_lost          'has "^ +lost fx:S "'
  a T_lost          'has "^ +lost fx:T "'
  a T_stopped       'has "^ +lost fx:T .*STOPPED.*latest reading is PASS @shipped"'
  a A_differential  '! has "^ +lost fx:A " && ! has "^ +gained fx:A( |$)"'
  a M1_gained       'has "^ +gained fx:M1 "'
  a M2_not_gained   '! has "^ +gained fx:M2( |$)"'
  a superseded_5    'has "superseded undeclared series .*: 5$"'
}
new=$(grade "$F" new); old=$(grade "$WORK/old.py" old)
fails=0
echo "  the reader under test ($F):"
printf '%s\n' "$new" | sed 's/^/    /'
bad=$(printf '%s\n' "$new" | grep -c ' RED$\| UNMEASURED')
[ "$bad" = 0 ] || { fails=$((fails+1)); echo "  FAIL: $bad arm(s) red on the reader under test -- its output:"; sed 's/^/      /' "$WORK/new.out"; }
# the built-in fail-once: the old reader must red on exactly these arms, and no other
want="M1_gained P_not_lost T_stopped superseded_5"
got=$(printf '%s\n' "$old" | awk '$3=="RED"{print $2}' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')
echo "  the old reader, the built-in fail-once: red on [$got]; must be exactly [$want] (P2_lost R_lost S_lost T_lost M2_not_gained A_differential are green on it by construction)"
if grep -q 'UNMEASURED' <<<"$old"; then fails=$((fails+1)); echo "  FAIL: the old reader could not be run -- the fail-once is unproven"; sed 's/^/      /' "$WORK/old.out" | tail -5
elif [ "$got" != "$want" ]; then fails=$((fails+1)); echo "  FAIL: the arms the old reader reds are not the arms the cure changed -- the assertions no longer see the defect they were written for"; fi
examined=2
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: 10 arms green on the reader under test, and the old reader reds exactly the 4 the cure changed (examined $examined readers)"; gate_stamp; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $fails check(s) failed (examined $examined readers)"; gate_stamp; exit 1

#!/usr/bin/env bash
# test_gate_no_runner_types_a_size_or_sets_the_window.sh -- NO RUNNER TYPES A SIZE OR SETS THE WINDOW (Lon 2026-09-28 15:4x CDT; ceo CEO-1353;
# RULES.md hard-cap rule clause 8 (g)(4); the coo's row instruments-every-runner-passes-each-units-declared-heap-and-stack-in-both-modes-...).
# Half (a) of that row's DONE-WHEN, a static census: util_size_setters_census.py names every code line of a script outside test_gate_* that
# sets SCRIP_HEAP_KB/SCRIP_HEAP_MB (the collector's initial WINDOW, never a declared heap) or types a size (a literal -d/-s/-i switch, a
# literal SCRIP size, ulimit -s, an oracle's own size), except a file in THE ONE ALLOWLIST (scripts/fixtures/arena_env_setters_allowlist.txt,
# path<TAB>reason). THE ARMS:
#   1  THE REAL TREE: outside the allowlist 0 and stale rows 0 (red until every runner reads its units' declarations -- the population is
#      printed by file:line, the work list the HQs cure under CEO-801 and the coo reviews);
#   2  the census is selective: a scratch scripts/ with one planted window setter, one typed -s256m, a Python argv "-d512m" and a docstring
#      and a report line that only MENTION sizes names exactly the three setters;
#   3  an allowlisted planted setter is not named, and an allowlist row naming a file that sets nothing reads STALE;
#   4  a malformed allowlist row (no reason) refuses rc 2.
# EXIT 0 all arms hold; 1 an arm failed (arm 1 carries the population); 2 could not measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=no_runner_types_a_size_or_sets_the_window
gate_parse_args "$@"
C="$HERE/util_size_setters_census.py"
gate_require "$C" "util_size_setters_census.py" || exit 2
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT INT TERM
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }

echo "--- ARM 1: the real tree ---"
o1="$(python3 "$C" --root "$HERE/.." 2>&1)"; r1=$?
[ "$r1" = 2 ] && { echo "GATE UNPROVEN(2) [$GATE_NAME]: $(tail -1 <<<"$o1")"; gate_stamp; exit 2; }
sum1="$(grep '^SIZE_SETTERS_CENSUS' <<<"$o1")"
ck "1 no script outside the allowlist sets the window or types a size, and no allowlist row is stale -- $(sed 's/ allowlist=.*//' <<<"$sum1")" '[ "$r1" = 0 ]'
[ "$r1" = 0 ] || { grep -E '^(SIZE_SETTER|STALE_ALLOWLIST_ROW)' <<<"$o1" | head -80 | sed 's/^/      /'; n80=$(grep -cE '^(SIZE_SETTER|STALE)' <<<"$o1"); [ "$n80" -gt 80 ] && echo "      ... and $((n80-80)) more"; }

echo "--- ARM 2: the census names setters and ignores mentions ---"
mkdir -p "$W/s/scripts/fixtures"; : > "$W/s/scripts/fixtures/arena_env_setters_allowlist.txt"
printf '#!/bin/bash\nSCRIP_HEAP_KB=65536 ./scrip p.sno\n' > "$W/s/scripts/r_window.sh"
printf '#!/bin/bash\n"$SCRIP" --run -s256m p.sno\n' > "$W/s/scripts/r_typed.sh"
printf '"""a docstring that mentions SCRIP_HEAP_MB=1 and -d512m"""\nimport subprocess\nsubprocess.run([SBL, "-d512m", "p.sno"])\nprint("ARENA SCRIP_HEAP_KB=%%s" %% 1)\n' > "$W/s/scripts/r_argv.py"
printf '#!/bin/bash\n# SCRIP_HEAP_KB=64 in a comment\necho "ran at SCRIP_HEAP_KB=64 and -s256m"\n"$SCRIP" --run -d"$kb"k p.sno\n' > "$W/s/scripts/r_clean.sh"
o2="$(python3 "$C" --root "$W/s" 2>&1)"; r2=$?
ck "2a the window setter, the typed switch and the Python argv element are named (rc $r2)" '[ "$r2" = 1 ] && grep -q "r_window.sh:2 WINDOW" <<<"$o2" && grep -q "r_typed.sh:2 TYPED" <<<"$o2" && grep -q "r_argv.py:3 TYPED" <<<"$o2"'
ck "2b the docstring, the report print, the comment, the echo and a declaration read into -d\$kb are not" '! grep -qE "r_argv.py:(1|4) |r_clean.sh" <<<"$o2"'

echo "--- ARM 3: the allowlist excuses by reason and a row that excuses nothing is stale ---"
printf 'scripts/r_window.sh\tgate fixture: an instrument whose window is its measurement\nscripts/r_clean.sh\tgate fixture: a row that excuses nothing\n' > "$W/s/scripts/fixtures/arena_env_setters_allowlist.txt"
o3="$(python3 "$C" --root "$W/s" 2>&1)"; r3=$?
ck "3a the allowlisted window setter is no longer named" '! grep -q "^SIZE_SETTER scripts/r_window.sh" <<<"$o3"'
ck "3b the row naming a file that sets nothing reads STALE" 'grep -q "^STALE_ALLOWLIST_ROW scripts/r_clean.sh" <<<"$o3"'

echo "--- ARM 4: a row without a reason refuses ---"
printf 'scripts/r_typed.sh\n' > "$W/s/scripts/fixtures/arena_env_setters_allowlist.txt"
python3 "$C" --root "$W/s" >/dev/null 2>&1; r4=$?
ck "4 rc 2 on an allowlist row with no reason" '[ "$r4" = 2 ]'

echo "------------------------------------------------------------"
echo "population: $n check(s): the real scripts/ ($(sed -n 's/.*scripts=\([0-9]*\).*/\1/p' <<<"$sum1") scripts outside test_gate_*) against the one allowlist, a 4-script scratch tree, two allowlist shapes"
if [ "$fails" -eq 0 ]; then echo "GATE PASS [$GATE_NAME]: $n of $n checks hold"; gate_stamp; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $fails of $n check(s) failed"; gate_stamp; exit 1

#!/usr/bin/env bash
# test_gate_make_leaves_out_a_dep_file_whose_source_is_gone.sh -- AN INCREMENTAL MAKE SURVIVES A MOVED SOURCE (ceo CEO-1352; the coo's row
# build-an-incremental-make-survives-a-moved-source-a-dep-file-whose-source-is-gone-is-left-out-by-rule-not-by-name).
# MEASURED by the ceo 2026-09-28 15:2x CDT: the first incremental make after 481a8cd96 moved prolog_atom.c died "No rule to make target
# .../src/parsers/prolog/prolog_atom.c" in every objdir that compiled it before the move; the Makefile's -include cured ONE instance by
# name (re.c). THE CURE: ../harness/scripts/live_dep_files.awk keeps a .d only while its object's first prerequisite exists.
#   1  the filter keeps a two-line .d (gcc -MMD's shape) and a one-line .d whose sources exist, and leaves out the .d naming a gone source;
#   2  END TO END: a fixture Makefile whose -include is the real Makefile's -include line (read from it, not restated) builds an object
#      whose source MOVED -- make -n prints the recipe from the pattern rule and never says "No rule to make target";
#   3  FAIL-ONCE: the same fixture with every .d included (no filter) dies "No rule to make target" -- the defect this gate exists to see;
#   4  the Makefile carries no by-name filter (grep -L on a source path) and names the awk.
# Hermetic (mktemp, no build, no corpus), under a second. EXIT 0 all hold; 1 an arm failed; 2 could not measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=make_leaves_out_a_dep_file_whose_source_is_gone
gate_parse_args "$@"
AWK_F="$HERE/live_dep_files.awk"; MK="$ROOT/Makefile"
gate_require "$AWK_F" "../harness/scripts/live_dep_files.awk" || exit 2
gate_require "$MK" "Makefile" || exit 2
command -v make >/dev/null || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no make on PATH"; exit 2; }
INC="$(grep -E '^-include \$\(shell find \$\(OBJ\) \$\(RT_OBJDIR\) -name "\*\.d"' "$MK" | head -1)"
[ -n "$INC" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the Makefile's dep-file -include line was not found -- it moved; re-anchor this gate"; exit 2; }
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT INT TERM
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }

# the fixture: prolog_atom.c's move in miniature -- src/old/moved.c is gone, src/new/moved.c is where the pattern rule finds it
mkdir -p "$W/src/new" "$W/src/keep" "$W/obj" "$W/rt"
printf 'int moved;\n' > "$W/src/new/moved.c"; printf 'int kept;\n' > "$W/src/keep/kept.c"; printf '/* h */\n' > "$W/src/keep/kept.h"
printf '%s/obj/moved.o: \\\n %s/src/old/moved.c \\\n %s/src/keep/kept.h\n%s/src/keep/kept.h:\n' "$W" "$W" "$W" "$W" > "$W/obj/moved.d"
printf '%s/obj/kept.o: \\\n %s/src/keep/kept.c \\\n %s/src/keep/kept.h\n%s/src/keep/kept.h:\n' "$W" "$W" "$W" "$W" > "$W/obj/kept.d"
printf '%s/rt/one.o: %s/src/keep/kept.c %s/src/keep/kept.h\n' "$W" "$W" "$W" > "$W/rt/one.d"

echo "--- ARM 1: the filter keeps the live .d files and leaves out the one naming a gone source ---"
out1="$(find "$W/obj" "$W/rt" -name '*.d' | sort | xargs -r awk -f "$AWK_F" 2>&1)"
ck "1a kept.d (two-line form, source present) is kept" 'grep -qx "$W/obj/kept.d" <<<"$out1"'
ck "1b one.d (one-line form, source present) is kept" 'grep -qx "$W/rt/one.d" <<<"$out1"'
ck "1c moved.d (its source src/old/moved.c is gone) is left out" '! grep -q "moved.d" <<<"$out1"'

# the fixture Makefile: the real -include line, verbatim, with the real variable names bound to the fixture's dirs
cat > "$W/Makefile" <<EOF
ROOT := $ROOT
OBJ := $W/obj
RT_OBJDIR := $W/rt
all: $W/obj/moved.o $W/obj/kept.o
$W/obj/%.o: $W/src/new/%.c ; @echo "cc \$<"
$W/obj/%.o: $W/src/keep/%.c ; @echo "cc \$<"
$INC
EOF
echo "--- ARM 2: end to end, make -n over the moved source with the real -include line ---"
out2="$(make -n -f "$W/Makefile" -C "$W" 2>&1)"; r2=$?
ck "2a make -n exits 0 and never says No rule to make target (rc $r2)" '[ "$r2" = 0 ] && ! grep -q "No rule to make target" <<<"$out2"'
ck "2b the moved object is built from its new place by the pattern rule" 'grep -q "cc $W/src/new/moved.c" <<<"$out2"'

echo "--- ARM 3: FAIL-ONCE -- every .d included, no filter: the defect comes back ---"
sed "s#^-include .*#-include \$(shell find \$(OBJ) \$(RT_OBJDIR) -name \"*.d\")#" "$W/Makefile" > "$W/Makefile.nofilter"
out3="$(make -n -f "$W/Makefile.nofilter" -C "$W" 2>&1)"; r3=$?
ck "3 without the filter make dies No rule to make target on src/old/moved.c (rc $r3)" '[ "$r3" != 0 ] && grep -q "No rule to make target.*src/old/moved.c" <<<"$out3"'

echo "--- ARM 4: the Makefile carries no by-name filter and names the awk ---"
ck "4a the -include line reads live_dep_files.awk" 'grep -q "live_dep_files.awk" <<<"$INC"'
ck "4b no grep -L by source path remains on the -include line" '! grep -q "grep -L" <<<"$INC"'

echo "------------------------------------------------------------"
echo "population: $n check(s) over a 3-file fixture objdir (one moved source, two live), the Makefile's own -include line, one planted unfiltered include"
if [ "$fails" -eq 0 ]; then echo "GATE PASS [$GATE_NAME]: $n of $n checks hold"; gate_stamp; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $fails of $n check(s) failed"; gate_stamp; exit 1

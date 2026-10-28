#!/usr/bin/env bash
# test_gate_bootstrap_parsers_define_no_functions.sh -- THE FUNCTION FLOOR OF THE SEVEN SELF-HOSTED PARSERS: a bootstrap/parser_<lang>.sc defines NO
# functions (RULES.md FACT RULE -- THE TREE IS THE PRUNED PARSE TREE: the tree is built from Shift, Reduce and the Counter stack primitives ONLY, in
# source order, no tree-building or scanning helper the grammar calls). The rule does not hold today (the floors below are the measured counts), so this
# gate is the INSTRUMENT of the cto's ruling of 2026-10-28 (to hq_snocone, copy to the ceo; ruling (a) with (b) as the direction): one floor per file at
# the count measured that day, RED when a count rises, RED when it falls with the floor still standing (a fall lowers the floor IN THE SAME LANDING that
# re-cuts a function as a pattern, so the ratchet keeps it), finish 0 per file. A function the grammar needs is a pattern that has not been written
# yet, never an exception. hq_snocone owns the floors.
#
# THE POPULATION is every function the file declares in statement position (`function NAME(` or `procedure NAME(` at a line start or after ; { }),
# whole-line /* */ and // comments set aside, plus every DEFINE( call (the other road to a function; floor 0 everywhere). A COUNT FLOOR CANNOT SEE A
# SWAP (one function leaves, another arrives, the count holds): the names are printed on every line so a reviewer reads them, and a landing that
# swaps names names the swap in its commit.
# ARMS (blocking): 1 the seven files exist and are read (refuse rc 2 below seven); 2 each file reads EXACTLY its floor; 3 each file's DEFINE count reads
# EXACTLY its floor; 4 FAIL-ONCE BUILT IN: a scratch copy of parser_snocone.sc with three planted functions (a line-start function, a procedure, one
# after a semicolon), two comment lines naming a function and one DEFINE call reads +3 functions and +1 DEFINE -- the comments set aside -- and the
# verdict arm names the file RED above its floor and RED below it.
# `--finish` reads every floor as 0: green only when no bootstrap parser defines a function (the DONE-WHEN of the row that carries the direction); without it the gate is the ratchet.
# rc 0 green · rc 1 red · rc 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOT="$HERE/../../SCRIP/bootstrap"
GATE_NAME=test_gate_bootstrap_parsers_define_no_functions
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
FLOORS="snobol4:22 snocone:1 rebus:1 icon:14 prolog:4 raku:1 pascal:49"
FINISH=0
for a in "$@"; do [ "$a" = --finish ] && FINISH=1; done
[ "$FINISH" = 1 ] && FLOORS="snobol4:0 snocone:0 rebus:0 icon:0 prolog:0 raku:0 pascal:0"
DEFINE_FLOOR=0
strip_comments() { awk 'in_c { if (index($0, "*/")) in_c = 0; next } /^[ \t]*\/\*/ { if (!index($0, "*/")) in_c = 1; next } /^[ \t]*\/\// { next } { print }' "$1"; }
fn_pat='(^|[;{}])[[:space:]]*(function|procedure)[[:space:]]+[A-Za-z_][A-Za-z_0-9]*[[:space:]]*\('
count_fns() { strip_comments "$1" | grep -cE "$fn_pat"; }
names_fns() { strip_comments "$1" | grep -oE "$fn_pat" | sed -E 's/^[;{} \t]*(function|procedure)[ \t]+//; s/[ \t]*\($//' | tr '\n' ' '; }
count_defs() { strip_comments "$1" | grep -cE '\bDEFINE[[:space:]]*\('; }
verdict_of() { if [ "$1" -gt "$2" ]; then echo "ROSE"; elif [ "$1" -lt "$2" ]; then echo "FELL"; else echo "ok"; fi; }
fail=0; files=0
for fl in $FLOORS; do
    lang="${fl%%:*}"; floor="${fl##*:}"; f="$BOOT/parser_$lang.sc"
    [ -f "$f" ] || { echo "  missing $f"; continue; }
    files=$((files + 1))
    n="$(count_fns "$f")"; d="$(count_defs "$f")"
    v="$(verdict_of "$n" "$floor")"; dv="$(verdict_of "$d" "$DEFINE_FLOOR")"
    printf '  %-4s %-8s functions %3s (floor %s)   DEFINE %s (floor %s)   %s\n' "$v" "$lang" "$n" "$floor" "$d" "$DEFINE_FLOOR" "$(names_fns "$f" | cut -c1-120)"
    case "$v" in
        ROSE) [ "$FINISH" = 1 ] && echo "         RED: $lang still defines $n function(s); the finish line is 0 (a pattern for each one the grammar needs)" || echo "         RED: $lang rose above its floor -- a function was added; write the grammar as a pattern (or, if it is truly the one Lon-granted function, the cto rules it)"; fail=1 ;;
        FELL) echo "         RED: $lang fell below its floor -- lower the floor to $n in this gate IN THE SAME LANDING that re-cut the function, so the ratchet keeps it"; fail=1 ;;
    esac
    [ "$dv" = ok ] || { echo "         RED: $lang calls DEFINE( $d time(s), floor $DEFINE_FLOOR"; fail=1; }
done
gate_floor "$files" 7 "bootstrap parsers"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
base="$BOOT/parser_snocone.sc"
cp "$base" "$T/planted.sc"
{
    echo "function PlantA(x) { return x; }"
    echo "  procedure PlantB(x) { return x; }"
    echo "plant_y = 1; function PlantC(z) { return z; }"
    echo "/* function PlantD(x) { return x; } */"
    echo "// function PlantE(x) { return x; }"
    echo "DEFINE('PlantF(x)');"
} >> "$T/planted.sc"
n0="$(count_fns "$base")"; n1="$(count_fns "$T/planted.sc")"; d0="$(count_defs "$base")"; d1="$(count_defs "$T/planted.sc")"
if [ "$((n1 - n0))" = 3 ] && [ "$((d1 - d0))" = 1 ]; then echo "  ok   fail-once: planted three functions (+$((n1 - n0))) and one DEFINE (+$((d1 - d0))), two comment lines set aside"
else echo "  RED  fail-once: planted three functions and one DEFINE read +$((n1 - n0)) and +$((d1 - d0)), not +3 and +1"; fail=1; fi
if [ "$(verdict_of "$n1" "$n0")" = ROSE ] && [ "$(verdict_of "$((n0 - 1))" "$n0")" = FELL ] && [ "$(verdict_of "$n0" "$n0")" = ok ]; then echo "  ok   fail-once: the verdict reads a rise ROSE, a fall FELL and the floor ok"
else echo "  RED  fail-once: the verdict arm does not tell a rise, a fall and the floor apart"; fail=1; fi
[ "$fail" = 0 ] && echo "ok: seven bootstrap parsers read their floors; nothing rose, nothing fell unlowered"
gate_verdict "$fail" "bootstrap parser function counts off their floors"

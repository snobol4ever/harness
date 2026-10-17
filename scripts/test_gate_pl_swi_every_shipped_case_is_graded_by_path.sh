#!/usr/bin/env bash
# test_gate_pl_swi_every_shipped_case_is_graded_by_path.sh -- THE SWI PACKAGE IS GRADED WHOLE (cto, 2026-09-12).
# Lon 2026-09-12, in-chat to cto, verbatim: "Get all SWI tests graded."  Row
# prolog-swi-tests-all-2879-cases-graded-per-case-against-swipl-by-path.
# ARMS (hermetic unless named):
#   (1) every .pl under corpus/packages/prolog/swi_tests that declares a begin_tests( unit has a .ref BESIDE IT (by path)
#   (2) every .ref carries one line per unit the source declares (a PASS/FAIL/BLOCKED case line names the unit, or an
#       EMPTY/UNGRADABLE unit line does) -- no unit the source declares is silent in its ref
#   (3) every .pl that declares no unit is named in UNGRADABLE.tsv with a closed class; nothing in UNGRADABLE.tsv
#       declares a unit (a graded file is never also ruled ungradable)
#   (4) no top-level duplicate of a subdirectory test file survives (the by-basename population is dead)
#   (5) the per-case matcher's identity holds on one file through the runner's own shim: graded + ungraded == declared
#       (needs the build; compiles nothing in mode 4 -- the board grades both modes, this is the identity check)
set -u
GATE_NAME=test_gate_pl_swi_every_shipped_case_is_graded_by_path
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SWIT="${S4E_CORPUS:-$ROOT/corpus}/packages/prolog/swi_tests"
PLUNIT="${S4E_CORPUS:-$ROOT/corpus}/tests/prolog/plunit.pl"
SCRIP="$HERE/../../SCRIP/scrip"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -d "$SWIT" ] || refuse "no vendored package at $SWIT"
red=0; total=0
arm() { total=$((total+1)); if [ "$1" -eq 0 ]; then echo "  ok  $2"; else echo "  RED $2"; red=$((red+1)); fi; }
missing=""; nplunit=0
while IFS= read -r f; do nplunit=$((nplunit+1)); [ -f "${f%.pl}.ref" ] || missing="$missing ${f#"$SWIT"/}"; done < <(grep -rl --include='*.pl' 'begin_tests(' "$SWIT" | sort)
[ -z "$missing" ]; arm $? "every plunit file has a ref beside it ($nplunit files)${missing:+ -- MISSING:$missing}"
silent=""
while IFS= read -r f; do ref="${f%.pl}.ref"; [ -f "$ref" ] || continue
    while IFS= read -r u; do grep -qE "^(PASS|FAIL|BLOCKED) $u:|^(EMPTY|UNGRADABLE) $u( |$)" "$ref" || silent="$silent ${f#"$SWIT"/}:$u"; done < <(grep -oP '^\s*:-\s*begin_tests\(\K[a-zA-Z0-9_]+' "$f")
done < <(grep -rl --include='*.pl' 'begin_tests(' "$SWIT" | sort)
[ -z "$silent" ]; arm $? "every declared unit is named in its ref${silent:+ -- SILENT:$silent}"
tsv="$SWIT/UNGRADABLE.tsv"; unnamed=""; wrongly=""
# ⛔ A NON-PLUNIT FILE IS NAMED IN ONE OF THE THREE SIDECARS (ceo CEO-1272, coo 2026-09-25): the retired class CONTAINER_OR_LIBRARY
# split by measurement -- a vendor module with clauses is a LIBRARY owed its driver (UNGRADED.tsv NEEDS_DRIVER), a data file is a
# CONTAINER (CONTAINERS.tsv), and an oracle ruling stays in UNGRADABLE.tsv. Named in none is still UNNAMED; a plunit file in any is still wrong.
while IFS= read -r f; do rel="${f#"$SWIT"/}"; if grep -q 'begin_tests(' "$f"; then cat "$tsv" "$SWIT/UNGRADED.tsv" "$SWIT/CONTAINERS.tsv" 2>/dev/null | grep -qP "^\Q$rel\E\t" && wrongly="$wrongly $rel"; else cat "$tsv" "$SWIT/UNGRADED.tsv" "$SWIT/CONTAINERS.tsv" 2>/dev/null | grep -qP "^\Q$rel\E\t" || unnamed="$unnamed $rel"; fi; done < <(find "$SWIT" -name '*.pl' | sort)
[ -z "$unnamed" ] && [ -z "$wrongly" ]; arm $? "non-plunit files are named in UNGRADABLE, UNGRADED or CONTAINERS and plunit files are not${unnamed:+ -- UNNAMED:$unnamed}${wrongly:+ -- GRADED-YET-RULED:$wrongly}"
dups=""
for f in "$SWIT"/*.pl; do [ -f "$f" ] || continue; b="$(basename "$f")"; case "$b" in test.pl) continue ;; esac; [ -n "$(find "$SWIT" -mindepth 2 -name "$b" | head -1)" ] && dups="$dups $b"; done
[ -z "$dups" ]; arm $? "no top-level duplicate of a subdirectory test file${dups:+ -- DUPLICATES:$dups}"
if [ -x "$SCRIP" ] && [ -f "$PLUNIT" ]; then
    "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
    T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
    printf 'main :- run_tests.\n:- initialization(main).\n' > "$T/wrap.pl"
    f="$SWIT/core/test_call.pl"
    timeout -k 5 60 "$SCRIP" --run "$PLUNIT" "$f" "$T/wrap.pl" </dev/null > "$T/act" 2>/dev/null
    line="$(python3 "$HERE/util_swi_match.py" "$f" "${f%.pl}.ref" "$T/act" | tail -1)"
    d=$(printf '%s' "$line" | sed -n 's/.*declared=\([0-9]*\).*/\1/p'); g=$(printf '%s' "$line" | sed -n 's/.* graded=\([0-9]*\).*/\1/p'); u=$(printf '%s' "$line" | sed -n 's/.*ungraded=\([0-9]*\).*/\1/p'); h=$(printf '%s' "$line" | sed -n 's/.* hit=\([0-9]*\).*/\1/p')
    [ -n "$d" ] && [ "$((g + u))" -eq "$d" ] && [ "$d" -ge 56 ] && [ "${h:-0}" -ge 34 ]; arm $? "matcher identity on core/test_call.pl: $line (floor declared>=56 hit>=34)"
else
    echo "  (build absent: the matcher identity arm is skipped -- the four hermetic arms stand)"
fi
echo "$GATE_NAME: arms=$total red=$red"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"

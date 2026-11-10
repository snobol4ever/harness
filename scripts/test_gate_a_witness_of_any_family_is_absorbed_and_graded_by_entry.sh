#!/usr/bin/env bash
# test_gate_a_witness_of_any_family_is_absorbed_and_graded_by_entry.sh -- THE ONE ADD-A-WITNESS TOOL TAKES ANY FAMILY AND A STEP HARNESS GRADES
# AN ENTRY (CIO-24 b and c, the coo 2026-11-10; row tests-layout-the-one-add-a-witness-tool-takes-any-family-and-a-step-harness-grades-an-entry).
# On a scratch copy of the rebus master: util_add_ladder_witness.py --family gatefam --from PAIR absorbs a loose pair as gatefam__STEM with its
# answer cut from the oracle and checked against the loose answer, and lib_design_witness.sh's design_witness_grade grades it by entry: a pair
# PASS; a pair with a stdin sidecar PASS; a stale loose answer REFUSES with the container unchanged; a program whose .heap declares a cap below
# what it allocates enters red (absorbed, graded FAIL); the batch form refuses a folder holding one stale pair before any write.
# rc 0 green · 1 red (the failing arm named) · 2 could not measure.
set -uo pipefail
GATE_NAME=test_gate_a_witness_of_any_family_is_absorbed_and_graded_by_entry
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
SCRIP="$ROOT/SCRIP/scrip"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no scrip at $SCRIP"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$ROOT/SCRIP/out/libscrip_rt.so" || exit 2
[ -f "$ROOT/corpus/tests/rebus/ALL.reb" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no rebus master to copy"; exit 2; }
D=$(mktemp -d "${TMPDIR:-/tmp}/witness_gate.XXXXXX") || { echo "⛔ REFUSE(2) [$GATE_NAME]: no tmpdir"; exit 2; }
trap 'rm -rf "$D"' EXIT
cp -r "$ROOT/corpus/tests/rebus" "$D/rebus" && mkdir -p "$D/pairs" "$D/batch" || exit 2
export DESIGN_WITNESS_DIR="$D/rebus"
. "$HERE/lib_design_witness.sh" || exit 2
RED=0; ARMS=0
arm() { ARMS=$((ARMS+1)); [ "$2" = REFUSE ] && echo REFUSE >> "$D/refused"; if [ "$2" = "$3" ]; then echo "  ok   $1"; else RED=$((RED+1)); echo "  RED  $1"; echo "       got:  [$2]"; echo "       want: [$3]"; fi; }
printf "function main()\nOUTPUT := 'absorbed'\nOUTPUT := 6 * 7\nend\n" > "$D/pairs/ok.reb";       printf 'absorbed\n42\n' > "$D/pairs/ok.ref"
printf "function main()\nOUTPUT := 'absorbed'\nOUTPUT := 6 * 7\nend\n" > "$D/pairs/stale.reb";    printf 'absorbed\n43\n' > "$D/pairs/stale.ref"
printf "function main()\nOUTPUT := INPUT\nOUTPUT := INPUT\nend\n" > "$D/pairs/echo2.reb";           printf 'one\ntwo\n' > "$D/pairs/echo2.in"; printf 'one\ntwo\n' > "$D/pairs/echo2.ref"
printf "function main()\nS := DUPL('x', 4000000)\nOUTPUT := SIZE(S)\nend\n" > "$D/pairs/bigheap.reb"; printf '4000000\n' > "$D/pairs/bigheap.ref"; echo 2048 > "$D/pairs/bigheap.heap"
cp "$D/pairs/ok.reb" "$D/batch/b_ok.reb"; cp "$D/pairs/ok.ref" "$D/batch/b_ok.ref"; cp "$D/pairs/stale.reb" "$D/batch/b_stale.reb"; cp "$D/pairs/stale.ref" "$D/batch/b_stale.ref"
add() { ( cd "$ROOT/SCRIP" && timeout -k 5 300 python3 "$HERE/util_add_ladder_witness.py" --lang rebus --family gatefam --rungs-dir "$D/rebus" --apply "$@" < /dev/null ) > "$D/add.log" 2>&1; echo $?; }
sum() { md5sum "$D/rebus/ALL.reb" "$D/rebus/ALL.ref" "$D/rebus/ALL.csv" | md5sum | cut -c1-12; }
grade() { design_witness_grade rebus "$1" m3 > "$D/grade.$1.log" 2>&1; local rc=$?; grep -q '^SUITE_BOARD ' "$D/grade.$1.log" && echo "$rc" || echo "NOBOARD:$rc"; }
graded() {   # an entry the master holds that prints no board cannot be measured (the gate refuses); one the tool never absorbed is that arm's red
    local g; g="$(grade "$1")"
    case "$g" in NOBOARD:*) design_witness_has rebus "$1" && { echo "REFUSE"; return; }; echo "not-absorbed";; *) echo "$g";; esac
}
n0="$(python3 "$HERE/corpus_suite_harness.py" list "$D/rebus/ALL.reb" "$D/rebus/ALL.ref" --lang rebus 2>/dev/null | wc -l)"
[ "$n0" -gt 0 ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: the scratch master lists no entry"; exit 2; }
arm "a pair is absorbed under a family (rc)" "$(add --from "$D/pairs/ok.reb")" 0
arm "its row reads family gatefam, entry gatefam__ok" "$(awk -F, '$2=="gatefam__ok"{print $4}' "$D/rebus/ALL.csv")" gatefam
arm "it grades PASS by entry" "$(graded gatefam__ok)" 0
s0="$(sum)"
arm "a stale loose answer refuses (rc)" "$(add --from "$D/pairs/stale.reb")" 2
arm "the refusal names both answers" "$(grep -c "loose '43', fresh '42'" "$D/add.log")" 1
arm "the container is unchanged after the refusal" "$(sum)" "$s0"
arm "a pair with a stdin sidecar is absorbed (rc)" "$(add --from "$D/pairs/echo2.reb")" 0
arm "it grades PASS by entry" "$(graded gatefam__echo2)" 0
arm "a program over its declared heap is absorbed (rc)" "$(add --from "$D/pairs/bigheap.reb")" 0
arm "its row carries the .heap sidecar" "$(awk -F, '$2=="gatefam__bigheap"{print $8}' "$D/rebus/ALL.csv")" 2048
arm "it enters red (FAIL by entry)" "$(graded gatefam__bigheap)" 1
s1="$(sum)"
arm "the batch form refuses a folder with one stale pair (rc)" "$( ( cd "$ROOT/SCRIP" && timeout -k 5 300 python3 "$HERE/util_add_ladder_witness.py" --lang rebus --family gatefam --rungs-dir "$D/rebus" --from-dir "$D/batch" --apply < /dev/null ) > "$D/batch.log" 2>&1; echo $?)" 2
arm "nothing is written by the refused batch" "$(sum)" "$s1"
arm "the master holds every old entry and the three new" "$(python3 "$HERE/corpus_suite_harness.py" list "$D/rebus/ALL.reb" "$D/rebus/ALL.ref" --lang rebus 2>/dev/null | wc -l)" "$((n0 + 3))"
arm "PARTITION.tsv is current over the grown table" "$( ( cd "$D/rebus" && python3 "$HERE/util_suite_partition.py" check ALL.csv ) > /dev/null 2>&1; echo $?)" 0
grep -q '^REFUSE$' "$D/refused" 2>/dev/null && { echo "⛔ REFUSE(2) [$GATE_NAME]: an absorbed entry printed no SUITE_BOARD -- cannot measure ($D)"; exit 2; }
[ "$RED" = 0 ] && { echo "GATE OK [$GATE_NAME]: $ARMS arms green -- --family and --from absorb a pair, its stdin and its heap; a stale answer and a stale batch refuse with nothing written; entries grade by entry"; exit 0; }
echo "GATE FAIL [$GATE_NAME]: $RED of $ARMS arms red"; exit 1

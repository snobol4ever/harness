#!/usr/bin/env bash
# test_gate_pas_fpc_suite_grades_against_a_corrected_ref_and_refuses_a_stale_or_missing_one.sh -- the FPC runner's ALL.corrected.tsv block (Lon 2026-10-05: where the
# oracle is wrong and we are right, the program is graded PASSING against the ISO-correct output, never the oracle's defect). Exercises the block alone over mktemp
# fixtures (the runner itself is lane-guarded and writes score rows): a good row is read and printed with its reason; a name not in the suite, a missing
# .ref.corrected, and a .ref.corrected equal to the oracle's .ref (stale: the oracle was fixed) each REFUSE with rc 2; and the shipped test_tisobuf3 row grades
# green in BOTH modes -- SCRIP's stdout equals its corrected ref and its exit code equals ALL.wantrc. FAIL_ONCE=1 corrupts the shipped corrected ref.
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
SCRIP="$ROOT/scrip"; RT="$ROOT/out"; RUNNER="$HERE/test_pascal_fpc_suite.sh"; SHIP="$ROOT/../corpus/packages/pascal/fpc_tests"
[ -f "$RUNNER" ] && [ -d "$SHIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: runner or shipped suite missing"; exit 2; }
BLOCK="$(sed -n '/^CORRECTED_TSV=/,/^fi$/p' "$RUNNER")"; [ -n "$BLOCK" ] || { echo "⛔ GATE REFUSE(2) [$G]: the runner has no ALL.corrected.tsv block"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
chk() { N=$((N+1)); if [ "$2" = "$3" ]; then echo "  ok   $1"; else echo "  ⛔ $1: got [$2] want [$3]"; RC=1; fi; }
blk() { ( SUITE="$1"; eval "$BLOCK" ) 2>&1; }
S="$T/s"; mkdir -p "$S"; printf 'program p; begin end.\n' > "$S/p.pas"; printf 'bug\n' > "$S/p.ref"; printf 'right\n' > "$S/p.ref.corrected"
printf 'p\tfpc issue 1\n' > "$S/ALL.corrected.tsv"
out=$(blk "$S"); rc=$?; chk "a good row is read and printed with its reason" "$(printf '%s' "$out" | grep -c 'corrected ref.*p (fpc issue 1)')" 1
printf 'ghost\tx\n' > "$S/ALL.corrected.tsv"; out=$(blk "$S"); blk "$S" >/dev/null; r=$(bash -c "SUITE='$S'; $BLOCK" >/dev/null 2>&1; echo $?); chk "a name not in the suite refuses" "$r" 2
printf 'p\tx\n' > "$S/ALL.corrected.tsv"; rm "$S/p.ref.corrected"; r=$(bash -c "SUITE='$S'; $BLOCK" >/dev/null 2>&1; echo $?); chk "a missing .ref.corrected refuses" "$r" 2
printf 'bug\n' > "$S/p.ref.corrected"; r=$(bash -c "SUITE='$S'; $BLOCK" >/dev/null 2>&1; echo $?); chk "a corrected ref equal to the oracle's ref refuses as stale" "$r" 2
# the shipped row, both modes
n=test_tisobuf3; [ -f "$SHIP/$n.ref.corrected" ] || { echo "⛔ GATE REFUSE(2) [$G]: no shipped $n.ref.corrected"; exit 2; }
want="$(cat "$SHIP/$n.ref.corrected")"; [ -n "${FAIL_ONCE:-}" ] && want="$want corrupted"
wantrc=$(awk -F'\t' -v n="$n" '$1==n{print $2; exit}' "$SHIP/ALL.wantrc"); wantrc=${wantrc:-0}
W="$T/w"; mkdir -p "$W"; cp "$SHIP/$n.pas" "$W/"
got3=$(cd "$W" && timeout -k 5 20 "$SCRIP" --run "$n.pas" </dev/null 2>/dev/null); rc3=$?
chk "$n m3 prints the corrected ref" "$got3" "$want"; chk "$n m3 exits as ALL.wantrc says" "$rc3" "$wantrc"
( cd "$W" && timeout -k 5 20 "$SCRIP" --compile -o "$n.s" "$n.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$n.s" -o "$n.m4" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: $n would not compile or link in mode 4"; exit 2; }
got4=$(cd "$W" && timeout -k 5 20 "./$n.m4" </dev/null 2>/dev/null); rc4=$?
chk "$n m4 prints the corrected ref" "$got4" "$want"; chk "$n m4 exits as ALL.wantrc says" "$rc4" "$wantrc"
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: the corrected-ref block reads, refuses stale/missing/unknown rows, and $n grades green in both modes, $N of $N arms"; else echo "GATE FAIL(1) [$G]: see above"; fi
exit $RC

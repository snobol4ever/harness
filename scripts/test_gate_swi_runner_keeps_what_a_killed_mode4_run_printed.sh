#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture over a scratch population, not a board (CEO-547)"
# test_gate_swi_runner_keeps_what_a_killed_mode4_run_printed.sh -- test_prolog_swi_suite.sh grades a plunit file that hangs part-way the
# same in both modes: the cases it printed before the kill PASS in mode 3 AND mode 4, the case that hangs reads HANG in both.
#
# WHY (hq_prolog 2026-10-04, measured; the coo's cure): a mode-4 binary block-buffers stdout to the pipe, so a file killed at the runner's
# timeout lost EVERY case it had printed and read HANG throughout, while mode 3 writes as it goes -- core/test_acyclic read 41 m3-PASS and
# 0 m4-PASS for ONE hang present in both modes, and the coo's telegram called the 43 lost cases "mode 4 alone". The runner now runs the
# mode-4 binary under stdbuf -o0 -e0, as the harness runs every mode-4 binary.
#   K  a scratch swi_tests package of ONE file: test(a) succeeds, test(b) loops for ever. Want: a PASS m3, a PASS m4, b HANG m3, b HANG m4.
# Costs about two minutes: the runner's own 60 s timeout fires once per mode on test(b).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
GATE_NAME=swi_runner_keeps_what_a_killed_mode4_run_printed
. "$HERE/lib_gate.sh"
SCRIP="${SCRIP:-$ROOT/scrip}"; gate_require_exec "$SCRIP" "scrip binary"
[ "$SCRIP" = "$ROOT/scrip" ] && { "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$ROOT/out/libscrip_rt.so" || exit 2; }
command -v stdbuf >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no stdbuf on this machine -- the cure has nothing to run under"; exit 2; }
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
PLU="$S4E/corpus/tests/prolog/plunit.pl"; [ -f "$PLU" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no plunit shim at $PLU"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_swibuf.XXXXXX")" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
D="$W/corpus/packages/prolog/swi_tests"; mkdir -p "$D" "$W/corpus/tests/prolog"; cp "$PLU" "$W/corpus/tests/prolog/"
printf ':- begin_tests(hangu).\ntest(a) :- true.\ntest(b) :- loop.\nloop :- loop.\n:- end_tests(hangu).\n' > "$D/hangu.pl"
printf 'PASS hangu:a\nPASS hangu:b\n' > "$D/hangu.ref"
printf 'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb,compile_args,run_args\n1,hangu,swi_tests__hangu,swi_tests,5,0,0,131072,4096,,\n' > "$D/ALL.csv"
o=$(S4E_HOME="$W" S4E_CORPUS="$W/corpus" S4E_PROGRESS_DB="$W/p.tsv" SCRIP="$SCRIP" timeout -k 5 600 bash "$HERE/test_prolog_swi_suite.sh" 2>&1); r=$?
got=$(awk -F'\t' 'NR>1 {k=$8; sub(/^hangu\.pl:hangu:/, "", k); sub(/#.*/, "", k); print k ":" $9 "=" $10}' "$W/p.tsv" 2>/dev/null | sort | tr '\n' ' ')
want="a:m3=PASS a:m4=PASS b:m3=HANG b:m4=HANG "
echo "population: 1 file, 2 cases x 2 modes (runner rc $r)"
if [ "$got" = "$want" ]; then echo "GATE PASS [$GATE_NAME]: K -- the printed case PASSes and the hanging case HANGs in BOTH modes ($got)"; exit 0; fi
[ -z "$got" ] && { echo "GATE UNPROVEN(2) [$GATE_NAME]: the runner wrote no rows (rc $r): $(grep -m1 -E 'REFUS|⛔' <<<"$o" | cut -c1-160)"; exit 2; }
echo "⛔ GATE FAIL [$GATE_NAME]: K -- got [$got], want [$want]: a mode that loses the printed case to the kill grades the flush, not the program"; exit 1

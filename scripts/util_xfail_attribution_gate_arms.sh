#!/usr/bin/env bash
# Companion negative-test harness for test_gate_snobol4_xfail_markers_are_attributed.sh.
# ⛔ NOT a gate and deliberately NOT named test_gate_*: it is not wired into `make test`, it PROVES the
# gate beside it can both pass and refuse. A gate whose failure paths were never exercised is the
# skip-as-success class waiting to happen -- run this whenever that gate is edited.
# Negative-test every refusal path of test_gate_snobol4_xfail_markers_are_attributed.sh v2.
# ROOT-RELATIVE AND SELF-CONTAINED (2026-11-10): it used to hard-code one seat's root and scratchpad, so on any
# other seat every arm exited 127 while the script still exited 0, and its ARM 6 read a reason file the master
# no longer carries. Every fixture is now built under a mktemp scratch dir, and the script exits 1 if any arm
# printed a different rc than it expects.
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SC="$(mktemp -d)"; trap 'rm -rf "$SC"' EXIT
G="$S4E/harness/scripts/test_gate_snobol4_xfail_markers_are_attributed.sh"
[ -f "$G" ] || { echo "no gate at $G"; exit 2; }
cd "$S4E/SCRIP" || exit 2
FAILS=0
run() { local want="$1" lbl="$2"; shift 2; "$@" >/dev/null 2>&1; local rc=$?; printf '%-46s rc=%s (expect %s)%s\n' "$lbl" "$rc" "$want" "$([ "$rc" = "$want" ] || { echo '  <-- MISMATCH'; })"; [ "$rc" = "$want" ] || FAILS=$((FAILS+1)); }
# a scratch copy of the gate that reads the synthetic population ($1 = reason file, $2 = ALL.csv stand-in)
mk() { sed -e "s|^RUNGS_XFAIL=.*|RUNGS_XFAIL=\"$1\"|" -e "s|^RUNGS_CSV=.*|RUNGS_CSV=\"$2\"|" "$G" > "$SC/g.sh"; }
printf '9\tsynthetic-control-row\thq_P\tFREE\n' > "$SC/synth_queue.tsv"
printf 'entry,xfail\nsynth_a,1\nsynth_b,1\nsynth_c,0\n' > "$SC/synth.csv"

echo "ARM 1 real tree: rc 0 while the master marks zero xfail entries, rc 1 once one has no usable route"
run 0 "  real" bash "$G"

echo "ARM 2 missing QUEUE (expect rc=2)"
run 2 "  missing" env S4E_QUEUE=/nonexistent/Q.tsv bash "$G"

echo "ARM 3 QUEUE parses to zero rows (expect rc=2)"
: > "$SC/empty_queue.tsv"
run 2 "  empty" env S4E_QUEUE="$SC/empty_queue.tsv" bash "$G"

echo "ARM 4 missing ALL.csv (expect rc=2 -- the population is gone)"
mk "$SC/none.xfail" "/nonexistent/ALL.csv"
run 2 "  no csv" env S4E_QUEUE="$SC/synth_queue.tsv" bash "$SC/g.sh"

echo "ARM 5 ALL.csv with no xfail column (expect rc=2 -- schema moved)"
printf 'entry,rank\nfoo,1\n' > "$SC/noschema.csv"
mk "$SC/none.xfail" "$SC/noschema.csv"
run 2 "  no column" env S4E_QUEUE="$SC/synth_queue.tsv" bash "$SC/g.sh"

echo "ARM 6 POSITIVE CONTROL: every xfail has a reason AND names a live row (expect rc=0)"
printf '*----- 1 synth_a XFAIL\nrouted to `synthetic-control-row`\n*----- 2 synth_b XFAIL\nrouted to `synthetic-control-row`\n' > "$SC/all_attributed.xfail"
mk "$SC/all_attributed.xfail" "$SC/synth.csv"
run 0 "  all attributed" env S4E_QUEUE="$SC/synth_queue.tsv" bash "$SC/g.sh"

echo "ARM 7 NEGATIVE CONTROL: an xfail entry with no reason at all (expect rc=1)"
printf '*----- 1 synth_a XFAIL\nrouted to `synthetic-control-row`\n' > "$SC/one_reason.xfail"
mk "$SC/one_reason.xfail" "$SC/synth.csv"
run 1 "  one unattributed" env S4E_QUEUE="$SC/synth_queue.tsv" bash "$SC/g.sh"

echo "ARM 8 NEGATIVE CONTROL: a reason that names a row that is not in the queue (expect rc=1)"
printf '*----- 1 synth_a XFAIL\nrouted to `no-such-row-anywhere`\n*----- 2 synth_b XFAIL\nrouted to `synthetic-control-row`\n' > "$SC/unminted.xfail"
mk "$SC/unminted.xfail" "$SC/synth.csv"
run 1 "  named, never minted" env S4E_QUEUE="$SC/synth_queue.tsv" bash "$SC/g.sh"
echo "=== xfail attribution gate arms: $FAILS mismatch(es) ==="
[ "$FAILS" = 0 ]

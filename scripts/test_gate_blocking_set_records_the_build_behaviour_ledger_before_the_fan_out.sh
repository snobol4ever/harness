#!/usr/bin/env bash
# test_gate_blocking_set_records_the_build_behaviour_ledger_before_the_fan_out.sh -- THE FAN-OUT PARENT RECORDS THE TREE'S BUILD-BEHAVIOUR LEDGER LINE ONCE, SERIALLY, BEFORE
# ANY SHARD STARTS, so no arm ever writes out/build_behaviour.sig and the race detector has nothing to convict (the coo 2026-10-14, ceo CEO-1754 follow-up).
# THE DEFECT: gate_require_built_from appends a line to out/build_behaviour.sig on a tree's FIRST observation. A set always runs on a tree the loop has just
# built, so the first arm of every shard observed it for the first time together and appended together: the 10-13 set on 2781bf6e4 refused nine arms as RACED,
# the 10-14 set on 0b870cf3e six, a different handful each time. A line per arm in blocking_set_serial_arms.txt would chase the handful; the writer is the cause.
#
# THE FIXTURE is a root of its own (a symlink farm of this ../harness/scripts/ with a real copy of the driver, a stub scrip that pauses so the check-then-append window is
# wide, and src/ + Makefile for the tree signature), driven through the real driver's --arms-from, --shared-surfaces and --shards, the way
# test_gate_blocking_set_parallel_agrees_with_serial.sh drives it. Its out/ is the declared watched surface.
#   (a) THE CONTROL, which makes the gate able to fail: the driver with the priming switched off (a copy cut from the real driver by a sed on its anchor line)
#       over three concurrent first observations must leave MORE THAN ONE ledger line and convict arms as RACED. If it does not, the fixture did not exercise
#       the defect and the gate REFUSES (rc 2): a control that does not reproduce proves nothing.
#   (b) the shipped driver over the same arms leaves EXACTLY ONE ledger line, no ARMRACE, every arm rc 0, the run rc 0.
#   (c) --list writes nothing: no ledger file after it.
# EXIT 0 all hold; 1 one does not; 2 REFUSED (a prerequisite is missing, or the control did not reproduce the race).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D0="$HERE/run_blocking_set.sh"
refuse(){ echo "⛔ REFUSED-TO-GRADE (rc=2): $*"; exit 2; }
[ -f "$D0" ] || refuse "no driver at $D0"
[ -f "$HERE/lib_gate.sh" ] || refuse "no lib_gate.sh beside the driver"
[ -d "$HERE/fixtures/build_behaviour" ] || refuse "no pinned build-behaviour witnesses at $HERE/fixtures/build_behaviour"
grep -q '^    PRIME_LEDGER=1  ' "$D0" || refuse "the driver carries no PRIME_LEDGER anchor -- the priming was removed or renamed, and a gate that cannot find what it guards must not pass"
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
W="$(mktemp -d)" || refuse "no temp dir"; trap 'rm -rf "$W"' EXIT
export S4E_BLOCKING_RUNSTATE="$W/runstate"
echo "=== gate: the blocking set records the build-behaviour ledger once, before the fan-out ==="

mkroot(){ # mkroot <name> [prime=0|1] -> $R, a fixture root whose driver is a real copy of the shipped one, the priming switched off when prime=0
  R="$W/$1/SCRIP"; mkdir -p "$R/../harness/scripts" "$R/src" "$R/out"
  cp -r "$HERE/." "$R/../harness/scripts/" || refuse "cannot stage the harness copy for $1"; rm -f "$R/../harness/scripts/run_blocking_set.sh"; cp "$D0" "$R/../harness/scripts/run_blocking_set.sh" || refuse "cannot copy the driver for $1"
  if [ "${2:-1}" = 0 ]; then
    sed -i 's/^    PRIME_LEDGER=1  /    PRIME_LEDGER=0  /' "$R/../harness/scripts/run_blocking_set.sh"
    grep -q '^    PRIME_LEDGER=1  ' "$R/../harness/scripts/run_blocking_set.sh" && refuse "the control's sed matched nothing -- a control that does not mutate proves nothing"
  fi
  printf 'int main(void){return 0;}\n' > "$R/src/a.c"; printf 'all:\n' > "$R/Makefile"; : > "$R/out/libscrip_rt.so"
  cat > "$R/scrip" <<'EOS'
#!/bin/sh
# stub compiler: --compile --out=OUT FILE -- a deterministic emission after a pause, so every concurrent first observation is inside the check-then-append window
sleep 0.3
out=""; while [ $# -gt 0 ]; do case "$1" in --out=*) out="${1#--out=}";; esac; shift; done
[ -n "$out" ] && echo "stub emission" > "$out"
exit 0
EOS
  chmod +x "$R/scrip"
}
cat > "$W/arm.sh" <<'EOA'
#!/usr/bin/env bash
# arm.sh <root> <rendezvous-dir> <id> <parties> -- meet the other first arms, then take the arms' own build-behaviour probe
R="$1"; RV="$2"; id="$3"; want="$4"; n=0
touch "$RV/$id"
while [ "$(ls "$RV" | grep -c .)" -lt "$want" ]; do n=$((n+1)); [ "$n" -gt 200 ] && { : > "$RV/NO-RENDEZVOUS"; break; }; sleep 0.05; done
. "$R/../harness/scripts/lib_gate.sh" || exit 2
GATE_NAME="fixture-arm-$id" gate_require_built_from "$R" "$R/scrip"
EOA
: > "$W/noserial.txt"
drive(){ # drive <root> <outfile> -> runs the root's own driver over six arms in three shards; sets RC
  local R="$1" o="$2" RV="$1.rv"; mkdir -p "$RV"; printf '%s\n' "$R/out" > "$R.surfaces"
  { for i in 1 2 3 4 5 6; do echo "bash $W/arm.sh $R $RV a$i 3"; done; } > "$R.arms"
  bash "$R/../harness/scripts/run_blocking_set.sh" --arms-from "$R.arms" --serial-arms "$W/noserial.txt" --shared-surfaces "$R.surfaces" --shards 3 > "$o" 2>&1; RC=$?
  [ -f "$RV/NO-RENDEZVOUS" ] && refuse "the first three arms never met inside 10s, so the defect was NOT EXERCISED (box load $(cut -d' ' -f1 /proc/loadavg))"
}
ledger_lines(){ wc -l < "$1/out/build_behaviour.sig" 2>/dev/null || echo 0; }

# ---- (a) THE CONTROL: priming off -> the race the gate exists for
mkroot ctl 0; drive "$R" "$W/ctl.out"; CTL="$R"
n_ctl=$(ledger_lines "$CTL"); race_ctl=$(grep -c '^ARMRACE	' "$W/ctl.out")
if [ "$n_ctl" -gt 1 ] && [ "$race_ctl" -gt 0 ]; then
  ck ok "(a) CONTROL: with the priming off, three concurrent first observations left $n_ctl ledger lines and the detector convicted $race_ctl arm(s) as RACED -- the defect reproduces"
else
  refuse "the control did not reproduce the race (ledger lines $n_ctl, ARMRACE $race_ctl, run rc $RC): the fixture did not exercise the defect, so (b) would prove nothing"
fi

# ---- (b) the shipped driver, same arms
mkroot cure 1; drive "$R" "$W/cure.out"; CURE="$R"; cure_rc=$RC
n_cure=$(ledger_lines "$CURE"); race_cure=$(grep -c '^ARMRACE	' "$W/cure.out"); red_cure=$(grep -c '^ARMRESULT	[12]	' "$W/cure.out")
if [ "$n_cure" = 1 ] && [ "$race_cure" = 0 ] && [ "$red_cure" = 0 ] && [ "$cure_rc" = 0 ]; then
  ck ok "(b) the shipped driver left exactly ONE ledger line, no RACED arm, every arm rc 0, the run rc 0"
else
  ck no "(b) ledger lines $n_cure (want 1), ARMRACE $race_cure (want 0), non-green arms $red_cure (want 0), run rc $cure_rc (want 0): $(grep -m1 '^blocking set:' "$W/cure.out")"
fi

# ---- (c) --list writes nothing
mkroot lst 1; bash "$R/../harness/scripts/run_blocking_set.sh" --arms-from "$W/cure.arms" --serial-arms "$W/noserial.txt" --list > "$W/lst.out" 2>&1; lst_rc=$?
if [ ! -e "$R/out/build_behaviour.sig" ]; then ck ok "(c) --list wrote no ledger (a listing is read-only)"; else ck no "(c) --list wrote $R/out/build_behaviour.sig"; fi

echo "population: 6 arms in 3 shards over 3 fixture roots (control, shipped, list)"
[ "$fails" = 0 ] && { echo "✅ GATE OK ($checks checks): the fan-out parent records the ledger once, and the control reproduces the race it prevents"; exit 0; }
echo "⛔ GATE RED: $fails of $checks check(s) failed"; exit 1

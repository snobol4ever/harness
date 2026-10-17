#!/usr/bin/env bash
# test_icn_n2_ft_formula.sh -- N-2 item 2 step 2a: the HOST RESERVATION FORMULA invariant (hq_P 2026-08-27).
#
# THE CLAIM UNDER TEST, and step 2 cannot be written without it:
#   a generator's alpha carve size ft is computable from GRAPH FIELDS ALONE, before that graph is emitted --
#       ft == ((48 + jcon_value_region + 15) & ~15) + (nparams + nlocals) * 16
#   so a HOST can reserve exactly its callee's frame bytes inside its own carve.  Step 1b already proved
#   jcon_value_region is valid pre-emission once drive_slots_all() has run; this proves the rest of the formula.
#
# ⛔ WHY THIS IS A GATE AND NOT A ONE-OFF MEASUREMENT: flat_frame_bytes is assigned on several emitter paths
# (emit.cpp:3358, :3464, and the _stfj arm which forces 48).  Any of them drifting from this formula silently
# re-sizes every host carve -- too small is stack corruption, and it would surface as a generator bug three
# layers away.  The formula must therefore be re-proved on every build, not trusted from this session's log.
#
# THREE STATES:  rc=0 the invariant holds  |  rc=1 it is violated  |  rc=2 could not measure (never skip-as-success)
set -u
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd); root=$(cd "$here/../../SCRIP" && pwd); cd "$root" || exit 2
scrip="$root/scrip"; corpus="$root/../corpus"
[ -x "$scrip" ] || { echo "⛔ REFUSE: no ./scrip at $scrip -- cannot measure"; exit 2; }
[ -d "$corpus" ] || { echo "⛔ REFUSE: no corpus at $corpus -- cannot measure"; exit 2; }
tmp=$(mktemp -d) || exit 2; trap 'rm -rf "$tmp"' EXIT
mapfile -t progs < <(find "$corpus/tests/icon" "$corpus/benchmarks/icon" -name '*.icn' 2>/dev/null | sort | head -400)
[ "${#progs[@]}" -gt 0 ] || { echo "⛔ REFUSE: zero Icon programs found -- an empty denominator is not a pass"; exit 2; }
tot=0; ok=0; bad=0; gtot=0; gok=0
for arm in OFF ARMED; do
  : > "$tmp/$arm.log"
  for prog in "${progs[@]}"; do
    if [ "$arm" = ARMED ]; then SCRIP_N2_FT_PROBE=1 SCRIP_ICN_GENFRAME2=1 timeout -k 5 30s "$scrip" --compile -o "$tmp/x.s" "$prog" </dev/null 2>>"$tmp/$arm.log" >/dev/null
    else                        SCRIP_N2_FT_PROBE=1                       timeout -k 5 30s "$scrip" --compile -o "$tmp/x.s" "$prog" </dev/null 2>>"$tmp/$arm.log" >/dev/null; fi
  done
  grep -aq '\[N2-FT\] EMIT' "$tmp/$arm.log" || { echo "⛔ REFUSE: arm $arm produced no [N2-FT] probe output -- the probe is missing, not the defect absent"; exit 2; }
  read -r t o b gt go < <(awk -v arm="$arm" '
    /\[N2-FT\] EMIT/ { delete v; for(i=1;i<=NF;i++){ n=split($i,a,"="); if(n==2) v[a[1]]=a[2] }
      tot++; if(v["ft"]==v["predft"]) ok++; else { bad++; if(bad<=5) printf "  MISMATCH %s ft=%s predft=%s region=%s ffb=%s np=%s nl=%s gen=%s\n", arm, v["ft"],v["predft"],v["region"],v["ffb"],v["np"],v["nl"],v["gen"] > "/dev/stderr" }
      if(v["gen"]=="1"){ gt++; if(v["ft"]==v["predft"]) gok++ } }
    END { printf "%d %d %d %d %d\n", tot+0, ok+0, bad+0, gt+0, gok+0 }' "$tmp/$arm.log")
  echo "  arm=$arm  graphs=$t  agree=$o  mismatch=$b  | generator graphs=$gt agree=$go"
  tot=$((tot+t)); ok=$((ok+o)); bad=$((bad+b)); gtot=$((gtot+gt)); gok=$((gok+go))
done
echo "── N-2 HOST RESERVATION FORMULA ─────────────────────────────────────"
echo "programs=${#progs[@]}  graph observations=$tot  AGREE=$ok  MISMATCH=$bad  (generator graphs=$gtot agree=$gok)"
[ "$tot" -gt 0 ] || { echo "⛔ REFUSE: zero observations -- proves nothing"; exit 2; }
[ "$gtot" -gt 0 ] || { echo "⛔ REFUSE: zero GENERATOR graphs observed -- the formula is untested where it matters"; exit 2; }
[ "$bad" -eq 0 ] || { echo "⛔ FAIL: the ft formula is violated on $bad graph(s) -- a host carve sized from it would be WRONG; step 2 BLOCKED"; exit 1; }
echo "✅ HOLDS: ft == ((48+region+15)&~15) + (nparams+nlocals)*16 on all $tot observations, both arms"
exit 0

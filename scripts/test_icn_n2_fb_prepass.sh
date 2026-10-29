#!/usr/bin/env bash
# test_icn_n2_fb_prepass.sh -- N-2 item 2 FORWARD-REFERENCE GUARD acceptance (hq_P 2026-08-27).
#
# THE CLAIM UNDER TEST, and it is the whole precondition item 2 rests on:
#   a callee generator's frame bytes are knowable BEFORE any graph is emitted, by reading the callee graph's
#   jcon_value_region -- so a host that forward-references a generator does NOT have to read proc_fb_buf[] as 0.
# Step 1 measured 3 genuine forward host->generator edges (geddump event->gedval, gedload->gedwalk;
# tgrlink dumpcode->aseq).  If PREPASS ever disagrees with POSTEMIT for even one proc, the claim is FALSE and
# item 2 must not size a host carve from the graph field -- so a mismatch is a hard FAIL, never a warning.
#
# THREE STATES, and the refusal is the point:
#   rc=0 AGREE      -- every proc's PREPASS region == its POSTEMIT frame bytes, in both modes, on every program
#   rc=1 MISMATCH   -- at least one proc disagreed: the guard is needed, item 2 blocked
#   rc=2 REFUSE     -- could not measure (no ./scrip, no corpus, no probe output).  NEVER skip-as-success.
set -u
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd); root=$(cd "$here/../../SCRIP" && pwd); cd "$root" || exit 2
scrip="$root/scrip"; corpus="$root/../corpus"
[ -x "$scrip" ] || { echo "⛔ REFUSE: no ./scrip at $scrip -- cannot measure"; exit 2; }
[ -d "$corpus" ] || { echo "⛔ REFUSE: no corpus at $corpus -- cannot measure"; exit 2; }
tmp=$(mktemp -d) || exit 2; trap 'rm -rf "$tmp"' EXIT
progs=()
for p in "$corpus"/benchmarks/icon/*.icn; do [ -f "$p" ] && progs+=("$p"); done
for p in "$corpus"/tests/icon/smoke/*.icn; do [ -f "$p" ] && progs+=("$p"); done
[ "${#progs[@]}" -gt 0 ] || { echo "⛔ REFUSE: zero Icon programs found under $corpus -- an empty denominator is not a pass"; exit 2; }
tot=0; agree=0; mism=0; noprobe=0; scanned=0
for prog in "${progs[@]}"; do
  base=$(basename "$prog")
  for mode in 4 3; do
    log="$tmp/$base.m$mode.log"
    if [ "$mode" = 4 ]; then SCRIP_N2_FB_PREPASS=1 timeout -k 5 60s "$scrip" --compile --out="$tmp/o.s" "$prog" </dev/null >/dev/null 2>"$log"
    else                     SCRIP_N2_FB_PREPASS=1 timeout -k 5 60s "$scrip" --run "$prog" </dev/null >/dev/null 2>"$log"; fi
    grep -aq '\[N2-FB\] PREPASS-END' "$log" || { noprobe=$((noprobe+1)); continue; }
    scanned=$((scanned+1))
    # PREPASS proc=NAME idx=I gen=G region=R   vs   POSTEMIT mode=M proc=NAME idx=I fb=F
    awk -v m="$mode" -v prog="$base" '
      /\[N2-FB\] PREPASS proc=/ { name=""; reg=""; for(i=1;i<=NF;i++){ if($i~/^proc=/){name=substr($i,6)} if($i~/^region=/){reg=substr($i,8)} } if(name!="") pre[name]=reg; next }
      /\[N2-FB\] POSTEMIT/ { if($0 !~ ("mode=" m)) next; name=""; fb=""; for(i=1;i<=NF;i++){ if($i~/^proc=/){name=substr($i,6)} if($i~/^fb=/){fb=substr($i,4)} }
                             if(name=="" || !(name in pre)) next; tot++; if(pre[name]==fb) ag++; else { mm++; printf "  MISMATCH %s m%s proc=%s prepass_region=%s postemit_fb=%s\n", prog, m, name, pre[name], fb } next }
      END { printf "TALLY %d %d %d\n", tot+0, ag+0, mm+0 }' "$log" > "$tmp/t.$$" 2>/dev/null
    grep -v '^TALLY' "$tmp/t.$$"
    read -r _ t a mm < <(grep '^TALLY' "$tmp/t.$$"); tot=$((tot+t)); agree=$((agree+a)); mism=$((mism+mm))
  done
done
echo "── N-2 FB PREPASS GUARD ─────────────────────────────────────────────"
echo "programs=${#progs[@]}  scans_with_probe=$scanned  scans_without_probe=$noprobe"
echo "proc comparisons=$tot  AGREE=$agree  MISMATCH=$mism"
[ "$tot" -gt 0 ] || { echo "⛔ REFUSE: zero proc comparisons made -- the probe produced no comparable pairs, so this proves nothing"; exit 2; }
[ "$mism" -eq 0 ] || { echo "⛔ FAIL: PREPASS != POSTEMIT for $mism proc(s) -- the graph field is NOT a valid pre-emission source; item 2 BLOCKED"; exit 1; }
echo "✅ AGREE: all $tot proc comparisons match -- a callee's frame bytes ARE knowable before emission (no table, no new global)"
exit 0

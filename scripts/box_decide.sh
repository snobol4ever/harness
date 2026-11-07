# box_decide.sh -- THE ONE LAW of box_controller.sh (DESIGN-PLAN box-scheduler steps 3 and 4, CTO-496; Lon 2026-11-04: "It does not appear that you have a
# design which is self-monitoring and self-adjusting."). decide() is PURE: it reads only the sensor variables below and prints one ACTUATOR line per decision;
# it changes nothing. box_controller.sh applies the lines each tick; --decide prints them for the live box; --plant feeds two planted extremes and proves
# every actuator moves. SENSORS: cpu60 busy gcpu10 gmem10 to_new q (box CPU PSI avg60, busy cores, the grader's own PSI, new timeouts, grader queue);
# w WMIN WMAX (grader width); sq sqc SQ_FLOOR (sessions slice quota percent, its BUDGET ceiling, floor); jt jtc JT_FLOOR (jobserver tokens, ceiling, floor);
# slotless "seat:cores ..." (over 2 cores holding no slot); capped "seat:age_s:cores_now ..." (seats the law capped); orphans "pid:seat:age_s:pcpu ...";
# mem "seat:cur_mb:high_mb:anon_mb ..."; madmit (maintenance admitted now, 1 or 0); PSI_TARGET (30, the bar);
# mem_rise (the grader's memory.events oom or max rose since the last tick, 1 or 0), up_hold (ticks left with no width step up, kept by the tick), cores (the box's CPUs): unset they read 0, 0 and 16.
# THE GRADER IS JUDGED BY ITS OWN SLICE (the cio 2026-11-04 17:5x, on the coo's measurement: box PSI 58 with grader PSI 1.5 and the law shrank the grader to 1;
# 22 requests waited 4 h): box heat shrinks the grader only when the grader's own PSI is 10 or more, and a calm grader (PSI under 10) with a queue grows even on a
# hot box; a hot box with a calm grader raises the sessions and batch quotas (COO-475), and only a starving grader lowers them. Per-slice PSI, not box PSI, judges each actuator (skill fleet-ops-industry 1).
decide() {
  local hot=0 idle=0 x s c a p cur hi an nw nsq nbq njt nm why
  awk -v c="$cpu60" -v b="$busy" -v k="${cores:-16}" 'BEGIN {exit !(c > 50 || (c > 30 && b >= 0.75 * k))}' && hot=1   # HOT (the cio 2026-11-07 08:3x): PSI avg60 over 50 alone, or over 30 with busy at or over three quarters of the cores (the shadow read maint admit=1 at PSI 71 with busy 11.5 under the old bar of 14)
  awk -v c="$cpu60" -v b="$busy" 'BEGIN {exit !(c < 15 || b < 13)}' && idle=1
  local dsq; dsq=$(awk -v c="$cpu60" -v b="$busy" -v g="$gcpu10" -v t="${PSI_TARGET:-30}" 'BEGIN {d = 0; if (c > t + 5 && g < 10) d = (c - t) * 10; else if (c > t + 5 && g >= 10) d = -(c - t) * 10; else if (b < 13) d = (13 - b) * 100; else if (c < t - 5) d = (t - c) * 10; if (d > 300) d = 300; if (d < -300) d = -300; printf "%d", int(d / 50) * 50}')   # PROPORTIONAL (Lon 2026-11-04 15:2x: "do as you see fit"): the step follows the error from the PSI target, a dead band of 5, at most 3 cores a tick; JUDGED BY THE GRADER'S OWN SLICE (COO-475, Lon 2026-11-05: "monitor and tune it on the fly"): a hot box (PSI over the target by 5) with a calm grader (PSI under 10) RAISES the sessions whatever busy reads, so the fleet's own work is not throttled to protect a grader that is not starving; a hot box with a starving grader (PSI 10 or more) LOWERS them; an idle box (busy under 13) and a cold box (PSI under the target by 5) raise them as before; otherwise hold
  nw=$w; why=hold
  if awk -v c="$cpu60" 'BEGIN {exit !(c > 50)}'; then nw=$((w - 2)); why="down-2:box_cpu_psi60=$cpu60"   # THE BOX IS ONE TENANT (the cio 2026-11-07 08:06 on the coo's numbers: box PSI 64 while the grader's own PSI read 11 and the width climbed): box PSI over 50 steps the width down 2 whatever the grader slice reads
  elif [ "${mem_rise:-0}" = 1 ]; then nw=$((w - 2)); why="down-2:grader_mem_events_rise=1"   # the grader slice hit memory.max or the memcg OOM killer (the cio 2026-11-07 08:2x): a rise steps down 2 and holds the up step for five ticks (up_hold, kept by the tick)
  elif awk -v c="$gcpu10" -v m="$gmem10" 'BEGIN {exit !(c > 50 || m > 20)}' || [ "${to_new:-0}" -gt 0 ]; then nw=$((w - 2)); why="down:grader_cpu_psi=$gcpu10,grader_mem_psi=$gmem10,new_timeouts=$to_new"
  elif [ $hot = 1 ] && [ "$sq" -le "$SQ_FLOOR" ] && awk -v c="$gcpu10" 'BEGIN {exit !(c >= 10)}'; then nw=$((w - 1)); why="down:box_hot_cpu_psi60=$cpu60,sessions_at_floor=$sq,grader_cpu_psi=$gcpu10"
  elif [ "${up_hold:-0}" -eq 0 ] && awk -v c="$gcpu10" -v q="$q" -v h="$hot" -v p="$cpu60" 'BEGIN {exit !((h == 0 || c < 10) && c < 20 && q > 0 && p <= 30)}'; then nw=$((w + 1)); why="up:grader_cpu_psi=$gcpu10,queued=$q,box_hot=$hot"; fi   # no step up while box PSI is over 30 or the memory-events hold runs
  [ $nw -lt $WMIN ] && nw=$WMIN; [ $nw -gt $WMAX ] && nw=$WMAX
  echo "ACTUATOR grader width=$nw from=$w floor=$WMIN ceiling=$WMAX why=$why"
  nsq=$((sq + dsq)); why=hold; [ $dsq -lt 0 ] && why="down${dsq}:grader_cpu_psi=$gcpu10,cpu_psi60=$cpu60,busy=$busy"; [ $dsq -gt 0 ] && why="up+${dsq}:grader_cpu_psi=$gcpu10,cpu_psi60=$cpu60,busy=$busy"
  [ $nsq -lt $SQ_FLOOR ] && nsq=$SQ_FLOOR; [ $nsq -gt $sqc ] && nsq=$sqc
  echo "ACTUATOR sessions quota=$nsq from=$sq floor=$SQ_FLOOR ceiling=$sqc why=$why"
  nbq=$((nsq / 5)); [ $nbq -lt 100 ] && nbq=100; [ $nbq -gt 200 ] && nbq=200
  echo "ACTUATOR batch quota=$nbq from=$(( sq / 5 < 100 ? 100 : (sq / 5 > 200 ? 200 : sq / 5) )) floor=100 ceiling=200 why=follows-sessions"
  local jdsq; jdsq=$(awk -v c="$cpu60" -v b="$busy" -v t="${PSI_TARGET:-30}" 'BEGIN {d = 0; if (c > t + 5 && b >= 14) d = -(c - t) * 10; else if (c < t - 5) d = (b < 13) ? (13 - b) * 100 : (t - c) * 10; if (d > 300) d = 300; if (d < -300) d = -300; printf "%d", int(d / 50) * 50}')   # THE COMPILE TOKENS KEEP THE OLD BOX-HEAT RULE (COO ruling 2026-11-05 18:08 CST, box-law): they fall on a hot busy box (PSI over target+5 with busy 14 or more), rise only on a cold box (PSI under target-5), and otherwise hold; a hot box never raises them, whatever the grader's PSI; decoupled from the sessions step dsq
  njt=$(( jt + jdsq / 100 )); why=hold; [ $jdsq -le -100 ] && why="down:cpu_psi60=$cpu60,busy=$busy"; [ $jdsq -ge 100 ] && why="up:cpu_psi60=$cpu60,busy=$busy"
  [ $njt -lt $JT_FLOOR ] && njt=$JT_FLOOR; [ $njt -gt $jtc ] && njt=$jtc
  echo "ACTUATOR jobserver tokens=$njt floor=$JT_FLOOR ceiling=$jtc from=$jt why=$why"
  for x in $slotless; do s=${x%%:*}; c=${x#*:}; case " $capped " in *" $s:"*) continue;; esac; echo "ACTUATOR seatcap seat=$s quota=200 from=400 why=slotless:cores=$c"; done
  for x in $capped; do IFS=: read -r s a c <<< "$x"; awk -v a="$a" -v c="$c" 'BEGIN {exit !(a >= 1800 && c < 1.5)}' && echo "ACTUATOR seatcap seat=$s quota=400 from=200 why=calm:age=${a}s,cores=$c"; done
  for x in $orphans; do IFS=: read -r p s a c <<< "$x"; awk -v a="$a" -v c="$c" 'BEGIN {exit !(a >= 900 && c >= 50)}' && echo "ACTUATOR orphan pid=$p seat=$s action=tell why=age=${a}s,pcpu=$c"; done
  nm=1; why="admit:cpu_psi60=$cpu60,busy=$busy"; [ $hot = 1 ] && { nm=0; why="defer:cpu_psi60=$cpu60,busy=$busy"; }
  echo "ACTUATOR maint admit=$nm from=$madmit why=$why"
  for x in $mem; do IFS=: read -r s cur hi an <<< "$x"; [ "$cur" -gt $((hi / 10 * 9)) ] && [ "$an" -lt 1536 ] && echo "ACTUATOR reclaim seat=$s mb=2048 why=cur=${cur}MB,high=${hi}MB,anon=${an}MB"; done
  return 0
}
plant() {  # two planted extremes; an actuator kind MOVED when either extreme decided a value other than its from= (or emitted an action line)
  local hotout coolout kinds moved k
  hotout=$(cpu60=62 busy=16.0 gcpu10=61 gmem10=0 to_new=1 q=500 w=4 WMIN=1 WMAX=8 sq=1000 sqc=1000 SQ_FLOOR=600 jt=8 jtc=12 JT_FLOOR=2 slotless="planted_a:3.1" capped="" orphans="999999:planted_a:1200:80" mem="planted_a:3900:4096:300" madmit=1 decide)
  coolout=$(cpu60=4 busy=6.0 gcpu10=1 gmem10=0 to_new=0 q=500 w=2 WMIN=1 WMAX=8 sq=800 sqc=1000 SQ_FLOOR=600 jt=4 jtc=12 JT_FLOOR=2 slotless="" capped="planted_b:2400:0.4" orphans="" mem="" madmit=0 decide)
  printf '%s\n%s\n' "$hotout" "$coolout" | sed 's/^/  /'
  kinds="grader sessions batch jobserver seatcap orphan maint reclaim"; moved=0
  for k in $kinds; do
    printf '%s\n%s\n' "$hotout" "$coolout" | awk -v k="$k" '$1=="ACTUATOR" && $2==k {to=""; fr=""; act=0; for (i=3;i<=NF;i++) {split($i,kv,"="); if (kv[1]=="from") fr=kv[2]; else if (kv[1]=="width"||kv[1]=="quota"||kv[1]=="tokens"||kv[1]=="admit") to=kv[2]; else if (kv[1]=="action"||kv[1]=="mb") act=1}; if (act || (fr!="" && to!=fr)) m=1} END {exit !m}' && moved=$((moved + 1)) || echo "  NOT MOVED: $k"
  done
  local n; n=$(echo $kinds | wc -w)
  if [ $moved = $n ]; then echo "PLANT actuators=$n moved=$moved every actuator moved"; return 0; fi
  echo "PLANT actuators=$n moved=$moved -- an actuator did not move"; return 1
}

#!/bin/bash
# box_tick.sh -- THE TICK OF THE FLEET QUEUE, IN SHADOW (fleet-queue step 10; the cio 2026-11-05 on Lon's word; skill fleet-bus section 8, skill fleet-ops-industry sections 1 and 6).
# s4e-tick.timer fires s4e-tick.service every 60 s; the service runs `box_tick.sh --tick`: a FRESH process each time, under flock on $TICK_DIR/tick.lock,
# so two ticks never overlap and an edit is live at the next tick (no stale loop).
# SHADOW (the cio's word: the coo swaps the old controller off, never the cio and never a worker): the tick reads the box's sensors as box_controller.sh's
# --decide does, decides the actuators with THE ONE LAW (box_decide.sh, copied unchanged), and records what it WOULD do: $TICK_DIR/decide.last, $TICK_DIR/shadow.log,
# and the share of its ACTUATOR decisions that agree with the old controller's $OLD/decide.last. It applies NOTHING. Its green-close sweep is step 8's phase on a
# SCRATCH postoffice (s4e_msg.sh sweep --plant-green, about 4 s, its scratch removed); the live queue is never written by the tick while it is in shadow.
#   box_tick.sh --tick          one tick (ExecStart of s4e-tick.service); rc 3 when another tick holds the lock; writes $TICK_DIR/last.tsv
#   box_tick.sh --probe-fresh   starts s4e-tick.service through systemd (a fresh process spawned by the user manager), then prints the TICK line (rc 0 green)
#   box_tick.sh --install       renders harness/systemd/s4e-tick.{service,timer} into ~/.config/systemd/user (@ROOT@ -> this root), daemon-reload, enable --now the timer
#   box_tick.sh --render-grade-worker  renders harness/systemd/s4e-grade-worker@.service into $S4E_UNIT_DIR (default ~/.config/systemd/user), reads it back, prints one RENDER line; no systemctl call
#   box_tick.sh --probe-cost  the tick's cost arm on a scratch dir: a quiet tick (view=unchanged, sweep=read, cpu_s under 3) and the tenth tick (sweep=ran); one TICK_COST line; writes only scratch
#   box_tick.sh --probe-wake-rate  the wake rate arm: five planted tier-4 seats, three --wake passes; one WAKE_RATE line (2, 2, 1 at S4E_WAKE_RATE=2); plant jobs deleted
#   box_tick.sh --probe-act  tick-act's arm (dry, scratch): one planted ACTUATOR line of each of the eight kinds through box_act.sh (the copy of the controller's apply and BOX.state); one ACT line, want arms=8
#   box_tick.sh --probe-scale  step 4e's arm (dry, a scratch tick dir, width 3): the absent switch leaves no grade worker running; the on switch starts s4e-grade-worker@1..3 and stops none; one SCALE line
#   box_tick.sh --probe-width-psi  the grader width arm on planted sensors (box PSI steps, the memory.events hold, the hot bar): one WIDTH_PSI line; rc 0 when every step is as ruled; writes no state
ROOT=${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}
cd "$ROOT" || exit 2
TICK_DIR=${S4E_TICK_DIR:-/home/resources/progress/tick}
OLD=${S4E_BOX_OLD:-/home/claude_coo/.scratch/verifier}   # READ ONLY: the old controller's sensor files and its decide.last
PO=/home/resources/postoffice
P=/home/resources/progress
U=/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service
TERM_SL=$U/app.slice/app-org.gnome.Terminal.slice
export XDG_RUNTIME_DIR=/run/user/$(id -u)
. "$ROOT/harness/scripts/box_decide.sh"   # THE ONE LAW (box-scheduler steps 3 and 4): decide() and plant()
SQ_FLOOR=${SQ_FLOOR:-600}; JT_FLOOR=${JT_FLOOR:-2}; PSI_TARGET=${PSI_TARGET:-30}

seat_of_scope() {   # the seat whose claude session owns a cgroup scope (as box_controller.sh)
  local p sc
  for p in $(pgrep -f '^claude --name '); do sc=$(cut -d: -f3 /proc/$p/cgroup | sed 's|.*/||'); [ "$sc" = "$1" ] && { tr '\0' ' ' < /proc/$p/cmdline | awk '{print tolower($3)}' | tr '-' '_'; return 0; }; done; return 1; }

events_rise() {   # events_rise <last oom> <last max> <oom> <max>: 1 when the grader's memory.events oom or max counter rose since the last tick, else 0
  if [ "$3" -gt "$1" ] || [ "$4" -gt "$2" ]; then echo 1; else echo 0; fi; }
up_hold_next() {  # up_hold_next <mem_rise> <up_hold>: the up_hold the tick keeps next: a rise holds the width's up step for five ticks, each later tick counts one down
  if [ "$1" = 1 ]; then echo 5; elif [ "$2" -gt 0 ]; then echo $(( $2 - 1 )); else echo 0; fi; }

sense() {   # the sensors of box_controller.sh's --decide, read the same way; sets the globals decide() reads
  local a b c d e f g h t1 i1 sc hi cur an t0 u us0 us f s x mgr eo em lo lm
  read -r _ a b c d e f g h _ < /proc/stat; t1=$((a+b+c+d+e+f+g+h)); i1=$((d+e)); sleep 2; read -r _ a b c d e f g h _ < /proc/stat
  busy=$(awk -v t=$((a+b+c+d+e+f+g+h-t1)) -v i=$((d+e-i1)) -v c=$(nproc) 'BEGIN {printf "%.1f", (t > 0 ? c * (1 - i / t) : 0)}')
  cpu60=$(awk '$1=="some" {for (i=2;i<=NF;i++) if ($i ~ /^avg60=/) {sub("avg60=","",$i); print $i}}' /proc/pressure/cpu); cpu60=${cpu60:-0}
  gcpu10=$(awk '$1=="some" {for (i=2;i<=NF;i++) if ($i ~ /^avg10=/) {sub("avg10=","",$i); print $i}}' $U/s4e.slice/s4e-grader.slice/cpu.pressure 2>/dev/null); gcpu10=${gcpu10:-0}
  gmem10=$(awk '$1=="some" {for (i=2;i<=NF;i++) if ($i ~ /^avg10=/) {sub("avg10=","",$i); print $i}}' $U/s4e.slice/s4e-grader.slice/memory.pressure 2>/dev/null); gmem10=${gmem10:-0}
  cores=$(nproc)
  read -r eo em < <(awk '$1=="oom" {o = $2} $1=="max" {m = $2} END {print o + 0, m + 0}' $U/s4e.slice/s4e-grader.slice/memory.events 2>/dev/null)
  read -r lo lm < "$TICK_DIR/grader_mem_events.last" 2>/dev/null; lo=${lo:-$eo}; lm=${lm:-$em}
  mem_rise=$(events_rise "$lo" "$lm" "$eo" "$em"); echo "$eo $em" > "$TICK_DIR/grader_mem_events.last"   # the last reading is the next tick's baseline
  up_hold=$(cat "$TICK_DIR/grader_up_hold" 2>/dev/null); up_hold=${up_hold:-0}
  q=$(grep -c '^E' $OLD/fresh.q 2>/dev/null); q=${q:-0}
  w=$(cat $OLD/box.width 2>/dev/null); w=${w:-4}
  WMIN=1; hh=$(date +%H); if [ "$hh" -ge 22 ] || [ "$hh" -lt 6 ] || grep -qE '^FLEET: IDLE( \(|$)' $PO/MODE; then WMAX=${BOX_WMAX_NIGHT:-8}; else WMAX=${BOX_WMAX_DAY:-4}; fi
  sqc=$(awk -F'\t' '$1=="sessions"{gsub("%","",$4); print $4}' $PO/BUDGET.tsv 2>/dev/null); sqc=${sqc:-1000}
  sq=$(awk '{if ($1=="max") print 1600; else printf "%d", $1/$2*100}' $TERM_SL/cpu.max 2>/dev/null); sq=${sq:-$sqc}
  jtc=$(awk -F'\t' '$1=="jobserver"{if (match($10,/tokens_ceiling=[0-9]+/)) print substr($10,RSTART+15,RLENGTH-15)}' $PO/BUDGET.tsv 2>/dev/null); jtc=${jtc:-12}
  jt=$(timeout 10 bash "$ROOT/harness/scripts/util_jobserver.sh" status 2>/dev/null | grep -oE 'tokens=[0-9]+' | head -1 | cut -d= -f2); jt=${jt:-$jtc}
  slotless=$(cat $OLD/slotless.last 2>/dev/null | tr '\n' ' ')
  capped=""
  for f in $OLD/governor/*.cap; do [ -e "$f" ] || continue; s=$(basename "$f" .cap); read -r t0 u _ us0 < "$f"; us=$(awk '/usage_usec/{print $2}' $TERM_SL/$u/cpu.stat 2>/dev/null)
    capped="$capped $s:$(( $(date +%s) - t0 )):$(awk -v a="$us0" -v b="${us:-$us0}" -v t=$(( $(date +%s) - t0 )) 'BEGIN {printf "%.2f", (t > 0 ? (b - a) / 1e6 / t : 0)}')"; done
  mgr=$(pgrep -u "$(id -u)" -x systemd | head -1); orphans=""
  while read -r pid ppid et pc cg args; do [ "$ppid" = "$mgr" ] || continue; case "$cg" in *app-org.gnome.Terminal.slice/vte-spawn-*) ;; *) continue;; esac
    case "$args" in claude*|*box_controller*|*loop8.sh*|*tier1.sh*|*seatwatch.sh*|"ssh: "*"[mux]"|"xclip -selection"*) continue;; esac
    orphans="$orphans $pid:$(seat_of_scope "${cg##*/}" || echo unknown):$et:${pc%.*}"; done < <(ps -eo pid=,ppid=,etimes=,pcpu=,cgroup:300=,args= 2>/dev/null)
  mem=""
  for sc in $TERM_SL/vte-spawn-*.scope; do [ -f $sc/memory.current ] || continue; hi=$(cat $sc/memory.high); [ "$hi" = max ] && continue
    cur=$(( $(cat $sc/memory.current) / 1048576 )); an=$(( $(awk '$1=="anon"{print $2}' $sc/memory.stat) / 1048576 )); mem="$mem $(seat_of_scope ${sc##*/} || echo ${sc##*/}):$cur:$(( hi / 1048576 )):$an"; done
  madmit=$(cat $OLD/maint.admit 2>/dev/null); madmit=${madmit:-1}
  to_now=$(awk -F'\t' -v s="$(date -u -d '-10 min' +%Y-%m-%dT%H:%M:%S)" '$1>=s && $12 ~ /timeout/' $P/results.tsv 2>/dev/null | wc -l)
  to_last=$(cat "$TICK_DIR/to.last" 2>/dev/null); to_last=${to_last:-$to_now}
  to_new=$(( to_now > to_last ? to_now - to_last : 0 )); echo "$to_now" > "$TICK_DIR/to.last"
}

period_s() { systemctl --user cat s4e-tick.timer 2>/dev/null | sed -n 's/^OnUnitActiveSec=\([0-9]*\)$/\1/p' | head -1; }

seat_held() {   # a seat holds a RESERVED claim not yet DONE: it has its job, so the wake pass sends it nothing
  local c; for c in "$PO"/claims/*.claim; do [ -f "$c" ] || continue; [ "$(head -1 "$c")" = "$1" ] || continue; grep -q '^RESERVED job=' "$c" && ! grep -q '^DONE$' "$c" && return 0; done; return 1; }
wake() {   # fleet-queue step 11: a seat whose watch list holds a ready job and that holds no reserved job gets one WAKE line (once per seat per 20 min) in $TICK_DIR/wake.pending;
  # the Stop hook holds a seat that already has a turn, so the line is only the pointer a fresh session needs (the cio's Monitor sends it). A tier tube wakes at most
  # as many seats of its tier as it holds ready jobs. Seats and tiers come from .github/TIERS.tsv; no seat pattern lives here.
  # THE RATE (CTO ruling, row tick-wake-pass-has-no-rate-twenty-wake-lines-in-eight-minutes-at-a-mass-wake): at most S4E_WAKE_RATE (default 2) WAKE lines per tick,
  # fable before opus before sonnet before haiku, and within a tier the seats whose own tube holds a job before the seats the tier tube wakes.
  local tiers="$ROOT/.github/TIERS.tsv" seat tier t ready n seats pass woken=0 lines=0 rate=${S4E_WAKE_RATE:-2} q="$ROOT/harness/scripts/util_queue.py" stamp
  stamp=$(date '+%F %T'); mkdir -p "$TICK_DIR"
  rd() { python3 "$q" stats-tube "$1" 2>/dev/null | sed -n 's/^TUBE [^ ]* ready=\([0-9]*\).*/\1/p'; }
  recent() { [ -n "$(find "$TICK_DIR" -maxdepth 1 -name "wake.told.$1" -mmin -20 2>/dev/null)" ]; }
  for tier in 1 2 3 4; do
    case $tier in 1) t=fable;; 2) t=opus;; 3) t=sonnet;; 4) t=haiku;; esac
    n=$(( $(rd "tier-$t") + $(rd "ask-$t") ))
    seats=$(awk -F'\t' -v k="$tier" '!/^#/ && $7==k {print $1}' "$tiers")
    for pass in seat tier; do
      for seat in $seats; do
        [ -z "${S4E_WAKE_ONLY:-}" ] || [ "$seat" = "$S4E_WAKE_ONLY" ] || continue   # the probe looks at one seat
        [ -z "${S4E_WAKE_SEATS:-}" ] || case " $S4E_WAKE_SEATS " in *" $seat "*) ;; *) continue;; esac   # the rate probe looks at its five seats
        ready=$(rd "seat-$seat"); ready=${ready:-0}
        if [ "$pass" = seat ]; then [ "$ready" -gt 0 ] || continue; else [ "$ready" -gt 0 ] && continue; [ "$n" -gt 0 ] || continue; fi
        seat_held "$seat" && continue; recent "$seat" && continue
        [ "$lines" -lt "$rate" ] || break 3   # the rate is spent: no further WAKE line this tick
        printf '%s WAKE %s %s :: SEND: run your sitting by CLAUDE.md, then bash harness/scripts/s4e_msg.sh next (it reserves your job from the queue)\n' "$stamp" "$(echo "$seat" | tr a-z_ A-Z-)" "$( [ "$ready" -gt 0 ] && echo "seat-$seat" || echo "tier-$t")" >> "$TICK_DIR/wake.pending"
        touch "$TICK_DIR/wake.told.$seat"; lines=$((lines+1)); [ "$ready" -gt 0 ] || n=$((n-1))
      done
    done
  done
  echo "WAKE lines=$lines"; return 0; }
probe_wake() {   # step 11's probe: a scratch tick dir, a plant job in a scratch seat's tube: exactly one WAKE line, none on the second pass (told within 20 min)
  local w q="$ROOT/harness/scripts/util_queue.py" jid out1 out2 l1
  w="$(mktemp -d "${TMPDIR:-/tmp}/s4e_wake_probe.XXXXXX")" || return 2
  local ps; ps="$(awk -F'\t' '!/^#/ && $7==4 {print $1}' "$ROOT/.github/TIERS.tsv" | tail -1)"
  jid=$(python3 "$q" put "seat-$ps" wake-plant --pri 100 --ttr 30) || { rm -rf "$w"; return 2; }
  out1=$(S4E_WAKE_ONLY="$ps" S4E_TICK_DIR="$w" TICK_DIR="$w" bash "$0" --wake 2>/dev/null | tail -1); l1=$(grep -c ' WAKE ' "$w/wake.pending" 2>/dev/null)
  out2=$(S4E_WAKE_ONLY="$ps" S4E_TICK_DIR="$w" TICK_DIR="$w" bash "$0" --wake 2>/dev/null | tail -1)
  python3 "$q" delete "$jid" >/dev/null 2>&1; rm -rf "$w"
  printf 'WAKE idle_with_ready=%s lines=%s by=hook second_pass=%s\n' "$( [ "${l1:-0}" -ge 1 ] && echo 1 || echo 0)" "${l1:-0}" "${out2#WAKE lines=}"
  [ "${l1:-0}" -ge 1 ] && [ "$out2" = "WAKE lines=0" ]; }
probe_wake_rate() {   # the rate arm (CTO ruling, row tick-wake-pass-has-no-rate-...): five tier-4 seats with no live claim, one plant job each in its own tube; three --wake passes over one scratch tick dir with the told files kept between them: the rate writes 2, 2, 1
  local w q="$ROOT/harness/scripts/util_queue.py" s jid jids="" seats="" k=0 p1 p2 p3
  w="$(mktemp -d "${TMPDIR:-/tmp}/s4e_wake_rate.XXXXXX")" || return 2
  for s in $(awk -F'\t' '!/^#/ && $7==4 {print $1}' "$ROOT/.github/TIERS.tsv" | tac); do
    [ "$k" -lt 5 ] || break
    seat_held "$s" && continue   # a seat with a live claim is held by the law, not by the rate: the probe does not count it
    jid=$(python3 "$q" put "seat-$s" wake-plant --pri 100 --ttr 30) || { for jid in $jids; do python3 "$q" delete "$jid" >/dev/null 2>&1; done; rm -rf "$w"; return 2; }
    jids="$jids $jid"; seats="$seats $s"; k=$((k+1))
  done
  p1=$(S4E_WAKE_RATE=2 S4E_WAKE_SEATS="${seats# }" S4E_TICK_DIR="$w" TICK_DIR="$w" bash "$ROOT/harness/scripts/box_tick.sh" --wake 2>/dev/null | tail -1); p1=${p1#WAKE lines=}
  p2=$(S4E_WAKE_RATE=2 S4E_WAKE_SEATS="${seats# }" S4E_TICK_DIR="$w" TICK_DIR="$w" bash "$ROOT/harness/scripts/box_tick.sh" --wake 2>/dev/null | tail -1); p2=${p2#WAKE lines=}
  p3=$(S4E_WAKE_RATE=2 S4E_WAKE_SEATS="${seats# }" S4E_TICK_DIR="$w" TICK_DIR="$w" bash "$ROOT/harness/scripts/box_tick.sh" --wake 2>/dev/null | tail -1); p3=${p3#WAKE lines=}
  for jid in $jids; do python3 "$q" delete "$jid" >/dev/null 2>&1; done
  rm -rf "$w"
  printf 'WAKE_RATE ready=%s rate=2 first_pass=%s second_pass=%s third_pass=%s\n' "$k" "$p1" "$p2" "$p3"
  [ "$k" = 5 ] && [ "$p1" = 2 ] && [ "$p2" = 2 ] && [ "$p3" = 1 ]; }
leases() {   # fleet-queue step 5: a RESERVED claim whose job reads ready (the holder died or the TTR ran out) is expired by the bus verb; one line per expiry in $TICK_DIR/leases.log
  local c t out
  for c in "$PO"/claims/*.claim; do [ -f "$c" ] || continue; grep -q '^RESERVED job=' "$c" || continue; grep -q '^DONE$' "$c" && continue
    t="$(basename "$c" .claim)"
    out=$(S4E_NO_BANNER=1 timeout 60 bash "$ROOT/harness/scripts/s4e_msg.sh" expire "$t" 2>&1 < /dev/null) || continue
    printf '%s %s\n' "$(date '+%F %T')" "$(printf '%s' "$out" | tail -1 | cut -c1-200)" >> "$TICK_DIR/leases.log"
  done; return 0; }
view_stamp() {   # the view's inputs (the coo's ruling, row tick-costs-13-to-20-s-cpu): the nanosecond mtimes of tasks/ and claims/, and every tube's counts (util_queue.py tubes: a put, a reserve or a done moves it); QUEUE.tsv is regenerated only when this moved
  printf '%s|%s' "$(stat -c '%.9Y' "$PO/tasks" "$PO/claims" 2>/dev/null | tr '\n' ' ')" "$(python3 "$ROOT/harness/scripts/util_queue.py" tubes 2>/dev/null | md5sum | cut -c1-32)"; }
dry_sense() {   # S4E_TICK_DRY=1: sense() is skipped and its globals are planted at the cool arm plant() already uses, so a probe reads a quiet tick with no 2 s sample
  busy=6.0; cpu60=4; gcpu10=1; gmem10=0; mem_rise=0; up_hold=0; cores=16; q=500; w=2; WMIN=1; WMAX=8; sqc=1000; sq=800; jtc=12; jt=4; slotless=""; capped=""; orphans=""; mem=""; madmit=0; to_new=0; }
tick() {
  local started law=0 flk=1 swp=0 rc_d rc_p rc_s agree=0 n=0 old_age=-1 stamp mgr fresh=0 plant_out swp_out tkn=0 vst="" view=unchanged sweep=read age_s=-1 cpu_s=0.00
  : "${S4E_SEAT:?REFUSE(2): the tick runs under a seat identity (S4E_SEAT unset); the unit sets it}"
  mkdir -p "$TICK_DIR" || return 2
  exec 9>>"$TICK_DIR/tick.lock"
  flock -n 9 || { echo "REFUSE(3): another tick holds $TICK_DIR/tick.lock"; return 3; }
  started=$(date +%s); stamp=$(date '+%F %T')
  tkn=$(( $(cat "$TICK_DIR/tick.count" 2>/dev/null || echo 0) + 1 )); echo "$tkn" > "$TICK_DIR/tick.count"   # the tick counter: the plant sweep runs on every tenth tick
  if [ "${S4E_TICK_DRY:-0}" = 1 ]; then dry_sense; else sense; fi
  decide > "$TICK_DIR/decide.new"; rc_d=$?
  up_hold_next "$mem_rise" "$up_hold" > "$TICK_DIR/grader_up_hold"   # the width's up-hold, one count per tick (a rise arms five)
  plant_out=$(plant 2>&1); rc_p=$?
  [ "$rc_d" = 0 ] && [ "$rc_p" = 0 ] && law=1
  mv "$TICK_DIR/decide.new" "$TICK_DIR/decide.last"
  keys() { awk '$1=="ACTUATOR" {s=$2; for (i=3;i<=NF;i++) if ($i !~ /^(from|floor|ceiling|why)=/) s=s" "$i; print s}' "$1" | sort; }
  keys "$TICK_DIR/decide.last" > "$TICK_DIR/keys.new"; keys "$OLD/decide.last" > "$TICK_DIR/keys.old" 2>/dev/null
  n=$(grep -c . "$TICK_DIR/keys.new"); agree=$(comm -12 "$TICK_DIR/keys.new" "$TICK_DIR/keys.old" | grep -c .)
  [ -f "$OLD/decide.last" ] && old_age=$(( $(date +%s) - $(stat -c %Y "$OLD/decide.last") ))
  { printf '%s TICK law=%s agree=%s/%s old_age_s=%s plant=%s\n' "$stamp" "$law" "$agree" "$n" "$old_age" "$(printf '%s' "$plant_out" | tail -1 | cut -c1-120)"; sed "s/^/$stamp /" "$TICK_DIR/decide.last"; } >> "$TICK_DIR/shadow.log"
  [ "$(wc -l < "$TICK_DIR/shadow.log")" -gt 20000 ] && { tail -n 10000 "$TICK_DIR/shadow.log" > "$TICK_DIR/shadow.tmp" && mv "$TICK_DIR/shadow.tmp" "$TICK_DIR/shadow.log"; }
  vst=$(view_stamp)   # fleet-queue step 12: QUEUE.tsv regenerated when its inputs moved since the last tick, else the TICK line says view=unchanged
  if [ "$vst" = "$(cat "$TICK_DIR/view.stamp" 2>/dev/null)" ]; then view=unchanged
  elif python3 "$ROOT/harness/scripts/util_queue_view.py" --regenerate > "$TICK_DIR/view.last" 2>&1; then printf '%s' "$vst" > "$TICK_DIR/view.stamp"; view=regenerated
  else view=failed; fi
  if [ "${S4E_TICK_DRY:-0}" != 1 ]; then wake > /dev/null; leases; scale_grade_workers > "$TICK_DIR/scale.last" 2>&1; fi   # fleet-queue step 11 and step 5; step 4e's scale; the dry probe plants no seat, expires no claim, starts no unit
  if [ $(( tkn % ${S4E_PLANT_EVERY:-10} )) -eq 0 ]; then   # the plant sweep is a self-test: every tenth tick only, the others carry the last reading
    swp_out=$(timeout 300 bash "$ROOT/harness/scripts/s4e_msg.sh" sweep --plant-green 2>&1 < /dev/null); rc_s=$?
    printf '%s\n' "$swp_out" | tail -20 > "$TICK_DIR/sweep.last"; sweep=ran
    printf '%s\n' "$swp_out" | grep -q '^SWEEP closed plant ' && swp=1
  else
    rc_s=0; sweep=read
    grep -q '^SWEEP closed plant ' "$TICK_DIR/sweep.last" 2>/dev/null && swp=1
  fi
  [ -f "$TICK_DIR/sweep.last" ] && age_s=$(( $(date +%s) - $(stat -c %Y "$TICK_DIR/sweep.last") ))
  printf '%s %s %s %s %s %s %s\n' "$$" "$PPID" "$started" "$flk" "$law" "$swp" "$rc_s" > "$TICK_DIR/last.tsv.tmp" && mv "$TICK_DIR/last.tsv.tmp" "$TICK_DIR/last.tsv"
  mgr=$(pgrep -u "$(id -u)" -x systemd | head -1); [ -n "$mgr" ] && [ "$PPID" = "$mgr" ] && fresh=1
  times > "$TICK_DIR/cpu.times"   # bash's times must run in this shell, not in a pipeline or $(...): a subshell reads its own zeros
  cpu_s=$(awk '{for (i = 1; i <= NF; i++) {v = $i; sub(/s$/, "", v); split(v, a, "m"); t += a[1] * 60 + a[2]}} END {printf "%.2f", t}' "$TICK_DIR/cpu.times")   # the CPU this tick spent: the shell and its waited-for children
  printf 'TICK unit=s4e-tick.timer period_s=%s fresh_pid=%s flock=%s controller_law=%s sweep_green=%s mode=shadow applied=0 agree=%s/%s secs=%s view=%s sweep=%s sweep_age_s=%s cpu_s=%s\n' \
    "$(period_s)" "$fresh" "$flk" "$law" "$swp" "$agree" "$n" "$(( $(date +%s) - started ))" "$view" "$sweep" "$age_s" "$cpu_s"
  return 0
}

tick_tok() { printf '%s\n' "$2" | tr ' ' '\n' | sed -n "s/^$1=//p" | head -1; }
probe_cost() {   # the tick's cost arm (the coo's ruling 2026-11-07, row tick-costs-13-to-20-s-cpu): a scratch tick dir and the dry path. A quiet tick (counter 5 becomes 6) with the view stamp planted from the live state: view=unchanged, sweep=read, cpu_s printed and under 3. The tenth tick (counter 9 becomes 10) runs the plant sweep: sweep=ran. Writes only scratch
  local w l1 l2 v1 s1 c1 s2 same=0 printed=0 under=0 ran=0 plant_every=${S4E_PLANT_EVERY:-10}
  w="$(mktemp -d "${TMPDIR:-/tmp}/s4e_tick_cost.XXXXXX")" || return 2
  echo 5 > "$w/tick.count"; view_stamp > "$w/view.stamp"
  l1=$(S4E_TICK_DRY=1 S4E_SEAT="${S4E_SEAT:-worker_18}" S4E_TICK_DIR="$w" TICK_DIR="$w" bash "$ROOT/harness/scripts/box_tick.sh" --tick 2>/dev/null | grep '^TICK unit=' | tail -1)
  echo 9 > "$w/tick.count"
  l2=$(S4E_TICK_DRY=1 S4E_SEAT="${S4E_SEAT:-worker_18}" S4E_TICK_DIR="$w" TICK_DIR="$w" bash "$ROOT/harness/scripts/box_tick.sh" --tick 2>/dev/null | grep '^TICK unit=' | tail -1)
  rm -rf "$w"
  v1=$(tick_tok view "$l1"); s1=$(tick_tok sweep "$l1"); c1=$(tick_tok cpu_s "$l1"); s2=$(tick_tok sweep "$l2")
  [ "$v1" = unchanged ] && same=1
  printf '%s' "$c1" | grep -qE '^[0-9]+\.[0-9]+$' && printed=1
  [ "$printed" = 1 ] && awk -v c="$c1" 'BEGIN {exit !(c < 3)}' && under=1
  [ "$s2" = ran ] && ran=1
  printf 'TICK_COST plant_every=%s view_skipped_when_unchanged=%s cpu_s_printed=%s quiet_tick_under_3s=%s quiet_sweep=%s plant_tick_sweep=%s cpu_s=%s view=%s\n' "$plant_every" "$same" "$printed" "$under" "${s1:-none}" "${s2:-none}" "${c1:-none}" "${v1:-none}"
  [ "$same" = 1 ] && [ "$printed" = 1 ] && [ "$under" = 1 ] && [ "$s1" = read ] && [ "$ran" = 1 ] && [ "$plant_every" = 10 ]; }
probe_fresh() {
  local mgr prev t0 srv_rc pid ppid started flk law swp rc_s i fresh=0
  mgr=$(pgrep -u "$(id -u)" -x systemd | head -1)
  prev=$(awk '{print $1}' "$TICK_DIR/last.tsv" 2>/dev/null)
  for i in $(seq 1 120); do systemctl --user is-active -q s4e-tick.service || break; sleep 1; done
  t0=$(date +%s)
  systemctl --user start s4e-tick.service; srv_rc=$?
  read -r pid ppid started flk law swp rc_s < "$TICK_DIR/last.tsv" 2>/dev/null
  [ "$srv_rc" = 0 ] && [ -n "$pid" ] && [ -n "$started" ] && [ "$pid" != "$$" ] && [ "$pid" != "$prev" ] && [ "$ppid" = "$mgr" ] && [ "$started" -ge "$t0" ] && fresh=1
  [ "$fresh" = 1 ] || { flk=0; law=0; swp=0; }
  printf 'TICK unit=s4e-tick.timer period_s=%s fresh_pid=%s flock=%s controller_law=%s sweep_green=%s\n' "$(period_s)" "$fresh" "${flk:-0}" "${law:-0}" "${swp:-0}"
  [ "$fresh" = 1 ] && [ "${flk:-0}" = 1 ] && [ "${law:-0}" = 1 ] && [ "${swp:-0}" = 1 ]
}

install_units() {
  local d=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user u
  mkdir -p "$d" "$TICK_DIR" || return 2
  : "${S4E_SEAT:?REFUSE(2): install the tick from a seat (S4E_SEAT unset); the unit runs under the installing seat identity}"
  for u in s4e-tick.service s4e-tick.timer; do sed -e "s|@ROOT@|$ROOT|g" -e "s|@SEAT@|$S4E_SEAT|g" "$ROOT/harness/systemd/$u" > "$d/$u" || return 2; done
  systemctl --user daemon-reload && systemctl --user enable --now s4e-tick.timer && echo "INSTALLED $d/s4e-tick.service and s4e-tick.timer, root=$ROOT"
}

render_grade_worker() {   # test-cycle step 4a (CTO-522): the grader's worker template, rendered and read back; no daemon-reload, no enable, no start (Lon's line)
  local d=${S4E_UNIT_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user} u=s4e-grade-worker@.service src slice restart exec
  src="$ROOT/harness/systemd/$u"; [ -f "$src" ] || { echo "REFUSE(2): $src is missing" >&2; return 2; }
  mkdir -p "$d" || return 2
  sed -e "s|@ROOT@|$ROOT|g" "$src" > "$d/$u" || return 2
  grep -q '@ROOT@' "$d/$u" && { echo "REFUSE(2): $d/$u still holds @ROOT@ after the render" >&2; return 2; }
  slice=$(sed -n 's/^Slice=//p' "$d/$u" | head -1)
  restart=$(sed -n 's/^Restart=//p' "$d/$u" | head -1)
  exec=$(sed -n 's|^ExecStart=[^ ]* ||p' "$d/$u" | head -1 | awk '{print $1}' | sed 's|.*/||')
  echo "RENDER unit=$u slice=$slice restart=$restart exec=$exec"
  [ -n "$slice" ] && [ -n "$restart" ] && [ -n "$exec" ]; }

act_line() {   # act_line <kind> <cpu60> <busy> <mem_rise> <up_hold> <grader cpu psi> <w>: the kind's ACTUATOR line decide() prints on cool sensors with these overrides (a pure read: no state, no files)
  local k=$1; cpu60=$2 busy=$3 mem_rise=$4 up_hold=$5 gcpu10=$6 w=$7 gmem10=0 to_new=0 q=500 WMIN=1 WMAX=8 sq=800 sqc=1000 SQ_FLOOR=600 jt=4 jtc=12 JT_FLOOR=2 slotless= capped= orphans= mem= madmit=1 cores=16 decide | awk -v k="$k" '$1=="ACTUATOR" && $2==k'; }
step_of() {   # step_of <ACTUATOR line>: down, up or hold, by its width= against its from=
  awk '{for (i = 3; i <= NF; i++) {split($i, kv, "="); if (kv[1] == "width") t = kv[2] + 0; if (kv[1] == "from") f = kv[2] + 0}} END {print ((t < f) ? "down" : ((t > f) ? "up" : "hold"))}' <<< "$1"; }
is_step() { [ "$(step_of "$1")" = "$2" ] && echo 1 || echo 0; }
admit_of() { awk '{for (i = 3; i <= NF; i++) {split($i, kv, "="); if (kv[1] == "admit") print kv[2] + 0}}' <<< "$1"; }
probe_width_psi() {   # the grader width arm's probe (the coo's 08:06 numbers; the cio's amendments 08:2x memory.events and 08:3x the hot bar): one planted override per measure on cool sensors; one WIDTH_PSI line of measured steps and one WIDTH_PSI_HOLD line; rc 0 when every measure is as ruled; writes no state
  local s62 u35 u10 rise drise hold blocked i after_up hot a35
  s62=$(is_step "$(act_line grader 62 6.0 0 0 1 4)" down)
  u35=$(is_step "$(act_line grader 35 6.0 0 0 1 2)" up)
  u10=$(is_step "$(act_line grader 10 6.0 0 0 1 2)" up)
  rise=$(events_rise 170 105708 174 105708)
  drise=$(is_step "$(act_line grader 10 6.0 "$rise" 0 1 4)" down)
  hold=$(up_hold_next "$rise" 0); blocked=0
  for i in 1 2 3 4 5; do [ "$(is_step "$(act_line grader 10 6.0 0 "$hold" 1 2)" up)" = 0 ] && blocked=$((blocked + 1)); hold=$(up_hold_next 0 "$hold"); done
  after_up=$(is_step "$(act_line grader 10 6.0 0 "$hold" 1 2)" up)
  hot=$([ "$(admit_of "$(act_line maint 71 11.5 0 0 1 4)")" = 0 ] && echo 1 || echo 0)
  a35=$([ "$(admit_of "$(act_line maint 35 11.5 0 0 1 4)")" = 1 ] && echo 1 || echo 0)
  printf 'WIDTH_PSI box_psi60=62 steps_down=%s box_psi60=35 steps_up=%s box_psi60=10 steps_up=%s mem_events_rise=%s steps_down=%s hot_at_psi71_busy11=%s\n' "$s62" "$u35" "$u10" "$rise" "$drise" "$hot"
  printf 'WIDTH_PSI_HOLD up_blocked_ticks=%s up_after_hold=%s psi35_busy11_admit=%s\n' "$blocked" "$after_up" "$a35"
  [ "$s62" = 1 ] && [ "$u35" = 0 ] && [ "$u10" = 1 ] && [ "$rise" = 1 ] && [ "$drise" = 1 ] && [ "$hot" = 1 ] && [ "$blocked" = 5 ] && [ "$after_up" = 1 ] && [ "$a35" = 1 ]; }

scale_grade_workers() {   # step 4e (CTO-522; the cio 2026-11-07): the grade workers follow THE SWITCH $TICK_DIR/GRADE_WORKERS (the coo writes `on` at step 7) and W, the controller's width (S4E_BOX_S overrides the file, default $OLD/box.width, 4 when absent). On: start s4e-grade-worker@1..W and stop the instances above W; any other switch stops every instance. S4E_SCALE_DRY=1 prints the systemctl lines and runs none. Prints one SCALE_PASS line.
  local want=0 W running before n r starts=0 stops=0 after dry=${S4E_SCALE_DRY:-0} s
  s="$(head -1 "$TICK_DIR/GRADE_WORKERS" 2>/dev/null)"; [ "$s" = on ] && want=1
  W="$(head -1 "${S4E_BOX_S:-$OLD/box.width}" 2>/dev/null)"; case "$W" in ''|*[!0-9]*) W=4;; esac
  [ "$want" = 1 ] || W=0
  running_list() { systemctl --user list-units 's4e-grade-worker@*' --no-legend --plain --state=running 2>/dev/null | awk '{print $1}' | sed -n 's/^s4e-grade-worker@\([0-9][0-9]*\)\.service$/\1/p'; }
  running="$(running_list)"; before=$(printf '%s' "$running" | grep -c .)
  for n in $(seq 1 "$W"); do
    printf '%s\n' "$running" | grep -qx "$n" && continue
    starts=$((starts + 1)); if [ "$dry" = 1 ]; then echo "systemctl --user start s4e-grade-worker@$n"; else systemctl --user start "s4e-grade-worker@$n" > /dev/null 2>&1 || echo "SCALE_FAIL start $n"; fi
  done
  for r in $running; do
    { [ "$want" = 0 ] || [ "$r" -gt "$W" ]; } || continue
    stops=$((stops + 1)); if [ "$dry" = 1 ]; then echo "systemctl --user stop s4e-grade-worker@$r"; else systemctl --user stop "s4e-grade-worker@$r" > /dev/null 2>&1 || echo "SCALE_FAIL stop $r"; fi
  done
  if [ "$dry" = 1 ]; then after=$(( before + starts - stops )); else after=$(running_list | grep -c .); fi
  echo "SCALE_PASS want=$want width=$W running_before=$before starts=$starts stops=$stops running_after=$after dry=$dry"
}
probe_scale() {   # step 4e's probe (CTO-522): a scratch tick dir and a planted width of 3, dry: the absent switch leaves no instance running and starts none; the `on` switch starts 1..3 and stops none
  local w off on off_i on_w on_s on_t TICK_DIR
  w="$(mktemp -d "${TMPDIR:-/tmp}/s4e_scale_probe.XXXXXX")" || return 2
  echo 3 > "$w/box.width"; TICK_DIR="$w"
  off="$(S4E_SCALE_DRY=1 S4E_BOX_S="$w/box.width" scale_grade_workers | tail -1)"
  echo on > "$w/GRADE_WORKERS"
  on="$(S4E_SCALE_DRY=1 S4E_BOX_S="$w/box.width" scale_grade_workers | tail -1)"
  rm -rf "$w"
  off_i=$(printf '%s' "$off" | sed -n 's/.* running_after=\([0-9]*\).*/\1/p'); on_w=$(printf '%s' "$on" | sed -n 's/.* running_after=\([0-9]*\).*/\1/p')
  on_s=$(printf '%s' "$on" | sed -n 's/.* starts=\([0-9]*\).*/\1/p'); on_t=$(printf '%s' "$on" | sed -n 's/.* stops=\([0-9]*\).*/\1/p')
  printf 'SCALE off_instances=%s on_width=%s starts=%s stops=%s dry=1\n' "${off_i:-x}" "${on_w:-x}" "${on_s:-x}" "${on_t:-x}"
  [ "${off_i:-x}" = 0 ] && [ "${on_w:-x}" = 3 ] && [ "${on_s:-x}" = 3 ] && [ "${on_t:-x}" = 0 ]; }
probe_act() {   # tick-act's probe (the cio's ruling 2026-11-07): a scratch S, BOX.state and progress dir, a fake scope under a scratch terminal slice, one planted ACTUATOR line of each kind; box_act.sh under S4E_ACT_DRY=1. ACT counts the kinds with evidence (a DRY line, an apply echo, or the file the kind writes); want 8
  local w out wid bst a=0
  w="$(mktemp -d "${TMPDIR:-/tmp}/s4e_act_probe.XXXXXX")" || return 2
  mkdir -p "$w/s/governor" "$w/s/orphan.told" "$w/p" "$w/term/fake.scope"
  printf '%s\n' 'ACTUATOR grader width=3 from=2 floor=1 ceiling=4 why=probe' 'ACTUATOR sessions quota=800 from=1000 floor=600 ceiling=1000 why=probe' \
    'ACTUATOR batch quota=137 from=200 floor=100 ceiling=200 why=probe' 'ACTUATOR jobserver tokens=10 floor=2 ceiling=12 from=12 why=probe' \
    'ACTUATOR seatcap seat=worker_20 quota=200 from=400 why=slotless:cores=3' 'ACTUATOR orphan pid=424242 seat=worker_20 action=tell why=age=1000s,pcpu=60' \
    'ACTUATOR maint admit=0 from=1 why=probe' 'ACTUATOR reclaim seat=worker_20 mb=2048 why=probe' > "$w/decide.last"
  out="$(S4E_ACT_DRY=1 S4E_BOX_S="$w/s" S4E_BOX_STATE="$w/BOX.state" S4E_BOX_P="$w/p" bash -c '. "$1"; unit_of() { echo fake.scope; }; TERM_SL="$2"; main' _ "$ROOT/harness/scripts/box_act.sh" "$w/term" < "$w/decide.last" 2>&1)"
  wid=0; [ "$(cat "$w/s/box.width" 2>/dev/null)" = 3 ] && wid=1
  bst=0; grep -qx 'grader_width=3' "$w/BOX.state" 2>/dev/null && bst=1
  [ "$wid" = 1 ] && a=$((a + 1))
  printf '%s' "$out" | grep -q 'DRY systemctl --user set-property --runtime app-org.gnome.Terminal.slice CPUQuota=800%' && a=$((a + 1))
  printf '%s' "$out" | grep -q 'DRY systemctl --user set-property --runtime s4e-batch.slice CPUQuota=137%' && a=$((a + 1))
  printf '%s' "$out" | grep -q 'JOBSERVER TOKENS 12 -> 10' && a=$((a + 1))
  [ -f "$w/s/governor/worker_20.cap" ] && a=$((a + 1))
  [ -f "$w/s/orphan.told/424242" ] && a=$((a + 1))
  [ "$(cat "$w/s/maint.admit" 2>/dev/null)" = 0 ] && a=$((a + 1))
  [ -f "$w/term/fake.scope/memory.reclaim" ] && a=$((a + 1))
  rm -rf "$w"
  printf 'ACT dry=1 width_written=%s box_state_written=%s arms=%s\n' "$wid" "$bst" "$a"
  [ "$wid" = 1 ] && [ "$bst" = 1 ] && [ "$a" = 8 ]; }
case "${1:-}" in
  --tick) tick; exit $?;;
  --probe-act) probe_act; exit $?;;
  --probe-scale) probe_scale; exit $?;;
  --leases) : "${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"; mkdir -p "$TICK_DIR"; leases; tail -3 "$TICK_DIR/leases.log" 2>/dev/null; exit 0;;
  --wake) wake; exit $?;;
  --view) python3 "$ROOT/harness/scripts/util_queue_view.py" --regenerate; exit $?;;
  --probe-wake) probe_wake; exit $?;;
  --probe-wake-rate) probe_wake_rate; exit $?;;
  --probe-cost) probe_cost; exit $?;;
  --probe-fresh) probe_fresh; exit $?;;
  --install) install_units; exit $?;;
  --render-grade-worker) render_grade_worker; exit $?;;
  --probe-width-psi) probe_width_psi; exit $?;;
  *) echo "usage: box_tick.sh --tick | --probe-fresh | --install | --render-grade-worker" >&2; exit 2;;
esac

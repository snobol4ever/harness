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

sense() {   # the sensors of box_controller.sh's --decide, read the same way; sets the globals decide() reads
  local a b c d e f g h t1 i1 sc hi cur an t0 u us0 us f s x mgr
  read -r _ a b c d e f g h _ < /proc/stat; t1=$((a+b+c+d+e+f+g+h)); i1=$((d+e)); sleep 2; read -r _ a b c d e f g h _ < /proc/stat
  busy=$(awk -v t=$((a+b+c+d+e+f+g+h-t1)) -v i=$((d+e-i1)) -v c=$(nproc) 'BEGIN {printf "%.1f", (t > 0 ? c * (1 - i / t) : 0)}')
  cpu60=$(awk '$1=="some" {for (i=2;i<=NF;i++) if ($i ~ /^avg60=/) {sub("avg60=","",$i); print $i}}' /proc/pressure/cpu); cpu60=${cpu60:-0}
  gcpu10=$(awk '$1=="some" {for (i=2;i<=NF;i++) if ($i ~ /^avg10=/) {sub("avg10=","",$i); print $i}}' $U/s4e.slice/s4e-grader.slice/cpu.pressure 2>/dev/null); gcpu10=${gcpu10:-0}
  gmem10=$(awk '$1=="some" {for (i=2;i<=NF;i++) if ($i ~ /^avg10=/) {sub("avg10=","",$i); print $i}}' $U/s4e.slice/s4e-grader.slice/memory.pressure 2>/dev/null); gmem10=${gmem10:-0}
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

wake() {   # fleet-queue step 11: a seat whose watch list holds a ready job and that holds no reserved job gets one WAKE line (once per seat per 20 min) in $TICK_DIR/wake.pending;
  # the Stop hook holds a seat that already has a turn, so the line is only the pointer a fresh session needs (the cio's Monitor sends it). A tier tube wakes at most
  # as many seats of its tier as it holds ready jobs. Seats and tiers come from .github/TIERS.tsv; no seat pattern lives here.
  local tiers="$ROOT/.github/TIERS.tsv" seat tier t ready n woken=0 lines=0 q="$ROOT/harness/scripts/util_queue.py" stamp
  stamp=$(date '+%F %T'); mkdir -p "$TICK_DIR"
  rd() { python3 "$q" stats-tube "$1" 2>/dev/null | sed -n 's/^TUBE [^ ]* ready=\([0-9]*\).*/\1/p'; }
  held() { local c; for c in "$PO"/claims/*.claim; do [ -f "$c" ] || continue; [ "$(head -1 "$c")" = "$1" ] || continue; grep -q '^RESERVED job=' "$c" && ! grep -q '^DONE$' "$c" && return 0; done; return 1; }
  recent() { [ -n "$(find "$TICK_DIR" -maxdepth 1 -name "wake.told.$1" -mmin -20 2>/dev/null)" ]; }
  for tier in 1 2 3 4; do
    case $tier in 1) t=fable;; 2) t=opus;; 3) t=sonnet;; 4) t=haiku;; esac
    n=$(( $(rd "tier-$t") + $(rd "ask-$t") ))
    for seat in $(awk -F'\t' -v k="$tier" '!/^#/ && $7==k {print $1}' "$tiers"); do
      [ -z "${S4E_WAKE_ONLY:-}" ] || [ "$seat" = "$S4E_WAKE_ONLY" ] || continue   # the probe looks at one seat
      ready=$(rd "seat-$seat"); ready=${ready:-0}
      if [ "$ready" -gt 0 ] || [ "$n" -gt 0 ]; then
        held "$seat" && continue; recent "$seat" && continue
        printf '%s WAKE %s %s :: SEND: run your sitting by CLAUDE.md, then bash harness/scripts/s4e_msg.sh next (it reserves your job from the queue)\n' "$stamp" "$(echo "$seat" | tr a-z_ A-Z-)" "$( [ "$ready" -gt 0 ] && echo "seat-$seat" || echo "tier-$t")" >> "$TICK_DIR/wake.pending"
        touch "$TICK_DIR/wake.told.$seat"; lines=$((lines+1)); [ "$ready" -gt 0 ] || n=$((n-1))
      fi
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
leases() {   # fleet-queue step 5: a RESERVED claim whose job reads ready (the holder died or the TTR ran out) is expired by the bus verb; one line per expiry in $TICK_DIR/leases.log
  local c t out
  for c in "$PO"/claims/*.claim; do [ -f "$c" ] || continue; grep -q '^RESERVED job=' "$c" || continue; grep -q '^DONE$' "$c" && continue
    t="$(basename "$c" .claim)"
    out=$(S4E_NO_BANNER=1 timeout 60 bash "$ROOT/harness/scripts/s4e_msg.sh" expire "$t" 2>&1 < /dev/null) || continue
    printf '%s %s\n' "$(date '+%F %T')" "$(printf '%s' "$out" | tail -1 | cut -c1-200)" >> "$TICK_DIR/leases.log"
  done; return 0; }
tick() {
  local started law=0 flk=1 swp=0 rc_d rc_p rc_s agree=0 n=0 old_age=-1 stamp mgr fresh=0 plant_out swp_out
  : "${S4E_SEAT:?REFUSE(2): the tick runs under a seat identity (S4E_SEAT unset); the unit sets it}"
  mkdir -p "$TICK_DIR" || return 2
  exec 9>>"$TICK_DIR/tick.lock"
  flock -n 9 || { echo "REFUSE(3): another tick holds $TICK_DIR/tick.lock"; return 3; }
  started=$(date +%s); stamp=$(date '+%F %T')
  sense
  decide > "$TICK_DIR/decide.new"; rc_d=$?
  plant_out=$(plant 2>&1); rc_p=$?
  [ "$rc_d" = 0 ] && [ "$rc_p" = 0 ] && law=1
  mv "$TICK_DIR/decide.new" "$TICK_DIR/decide.last"
  keys() { awk '$1=="ACTUATOR" {s=$2; for (i=3;i<=NF;i++) if ($i !~ /^(from|floor|ceiling|why)=/) s=s" "$i; print s}' "$1" | sort; }
  keys "$TICK_DIR/decide.last" > "$TICK_DIR/keys.new"; keys "$OLD/decide.last" > "$TICK_DIR/keys.old" 2>/dev/null
  n=$(grep -c . "$TICK_DIR/keys.new"); agree=$(comm -12 "$TICK_DIR/keys.new" "$TICK_DIR/keys.old" | grep -c .)
  [ -f "$OLD/decide.last" ] && old_age=$(( $(date +%s) - $(stat -c %Y "$OLD/decide.last") ))
  { printf '%s TICK law=%s agree=%s/%s old_age_s=%s plant=%s\n' "$stamp" "$law" "$agree" "$n" "$old_age" "$(printf '%s' "$plant_out" | tail -1 | cut -c1-120)"; sed "s/^/$stamp /" "$TICK_DIR/decide.last"; } >> "$TICK_DIR/shadow.log"
  [ "$(wc -l < "$TICK_DIR/shadow.log")" -gt 20000 ] && { tail -n 10000 "$TICK_DIR/shadow.log" > "$TICK_DIR/shadow.tmp" && mv "$TICK_DIR/shadow.tmp" "$TICK_DIR/shadow.log"; }
  wake > /dev/null   # fleet-queue step 11: WAKE lines for idle seats with a ready job
  leases   # fleet-queue step 5: every claim whose reserved job is back in its tube is expired through the bus (the LEDGER line, the claim archived, QUEUED:<tube>)
  swp_out=$(timeout 300 bash "$ROOT/harness/scripts/s4e_msg.sh" sweep --plant-green 2>&1 < /dev/null); rc_s=$?
  printf '%s\n' "$swp_out" | tail -20 > "$TICK_DIR/sweep.last"
  printf '%s\n' "$swp_out" | grep -q '^SWEEP closed plant ' && swp=1
  printf '%s %s %s %s %s %s %s\n' "$$" "$PPID" "$started" "$flk" "$law" "$swp" "$rc_s" > "$TICK_DIR/last.tsv.tmp" && mv "$TICK_DIR/last.tsv.tmp" "$TICK_DIR/last.tsv"
  mgr=$(pgrep -u "$(id -u)" -x systemd | head -1); [ -n "$mgr" ] && [ "$PPID" = "$mgr" ] && fresh=1
  printf 'TICK unit=s4e-tick.timer period_s=%s fresh_pid=%s flock=%s controller_law=%s sweep_green=%s mode=shadow applied=0 agree=%s/%s secs=%s\n' \
    "$(period_s)" "$fresh" "$flk" "$law" "$swp" "$agree" "$n" "$(( $(date +%s) - started ))"
  return 0
}

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

case "${1:-}" in
  --tick) tick; exit $?;;
  --leases) : "${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"; mkdir -p "$TICK_DIR"; leases; tail -3 "$TICK_DIR/leases.log" 2>/dev/null; exit 0;;
  --wake) wake; exit $?;;
  --probe-wake) probe_wake; exit $?;;
  --probe-fresh) probe_fresh; exit $?;;
  --install) install_units; exit $?;;
  *) echo "usage: box_tick.sh --tick | --probe-fresh | --install" >&2; exit 2;;
esac
